import express from 'express';
import Post from '../models/Post.js';
import Task from '../models/Task.js';
import ClubMember from '../models/ClubMember.js';
import Club from '../models/Club.js';
import Notification from '../models/Notification.js';
import { verifyToken, verifyClubOfficer } from '../middleware/auth.js';
import { sendEventUpdateEmail } from '../services/emailService.js';
import { sendPushToClubMembers } from '../services/pushService.js';

const router = express.Router();


import EventRSVP from '../models/EventRSVP.js';

// Get user RSVPs by email (for viewing registered events and certificates)
// Moved to top to avoid shadowing by /:id/rsvps
router.get('/user/rsvps', verifyToken, async (req, res) => {
    try {
        const userEmail = req.user.email;

        // Fetch all RSVPs matching user email (including self-registered 'rsvp' source)
        const rsvps = await EventRSVP.find({
            email: { $regex: new RegExp(`^${userEmail}$`, 'i') }
        }).sort({ rsvpedAt: -1 });

        res.json(rsvps);
    } catch (error) {
        console.error('Error fetching user RSVPs:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// GET all posts
router.get('/', async (req, res) => {
    try {
        const posts = await Post.find().sort({ date: 1 }); // Sort by date ascending
        res.json(posts);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// GET specific post
router.get('/:id', async (req, res) => {
    try {
        const post = await Post.findById(req.params.id);
        if (!post) return res.status(404).json({ message: 'Post not found' });

        // Also fetch RSVP count
        const rsvpCount = await EventRSVP.countDocuments({ eventId: req.params.id });
        const postObj = post.toObject();
        postObj.rsvps = rsvpCount;

        res.json(postObj);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// ==================== RSVP ROUTES ====================

// GET RSVPs for an event
router.get('/:id/rsvps', verifyToken, async (req, res) => {
    try {
        const rsvps = await EventRSVP.find({ eventId: req.params.id }).sort({ rsvpedAt: -1 });
        res.json(rsvps);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// Create RSVP
router.post('/:id/rsvp', async (req, res) => {
    try {
        const { name, email, userId } = req.body;
        const eventId = req.params.id;

        // Check for duplicate
        const existing = await EventRSVP.findOne({ eventId, email });
        if (existing) {
            return res.status(400).json({ message: 'You have already RSVPed to this event.' });
        }

        // Get event's totalSessions to initialize sessionAttendance
        const event = await Post.findById(eventId);
        const totalSessions = event?.totalSessions || 1;
        const sessionAttendance = new Map();
        for (let i = 1; i <= totalSessions; i++) {
            sessionAttendance.set(String(i), 'pending');
        }

        const newRSVP = new EventRSVP({
            eventId,
            name,
            email,
            userId: userId || null, // Optional
            source: 'rsvp', // Self-RSVP
            sessionAttendance,
        });

        await newRSVP.save();

        const rsvpCount = await EventRSVP.countDocuments({ eventId });
        await Post.findByIdAndUpdate(eventId, { rsvps: rsvpCount });

        res.status(201).json(newRSVP);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// Update Participant Attendance (Secretary/Admin only) - session-based
router.patch('/:id/rsvps/:rsvpId', verifyToken, async (req, res) => {
    try {
        const { status, session } = req.body;
        if (!['present', 'absent'].includes(status)) {
            return res.status(400).json({ message: 'Invalid status' });
        }

        const sessionKey = String(session || 1);

        const rsvp = await EventRSVP.findByIdAndUpdate(
            req.params.rsvpId,
            { [`sessionAttendance.${sessionKey}`]: status },
            { new: true }
        );
        res.json(rsvp);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// Delete Participant (Secretary/Admin only)
router.delete('/:id/rsvps/:rsvpId', verifyToken, async (req, res) => {
    try {
        await EventRSVP.findByIdAndDelete(req.params.rsvpId);

        // Update count
        const rsvpCount = await EventRSVP.countDocuments({ eventId: req.params.id });
        await Post.findByIdAndUpdate(req.params.id, { rsvps: rsvpCount });

        res.json({ message: 'Participant removed' });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// Add Manual Participant (Secretary/Admin only)
router.post('/:id/rsvps/add', verifyToken, async (req, res) => {
    try {
        const { name, email, source } = req.body;
        const eventId = req.params.id;

        // Check for duplicate
        const existing = await EventRSVP.findOne({ eventId, email });
        if (existing) {
            return res.status(400).json({ message: 'Participant with this email already exists.' });
        }

        // Get event's totalSessions to initialize sessionAttendance
        const event = await Post.findById(eventId);
        const totalSessions = event?.totalSessions || 1;
        const sessionAttendance = new Map();
        for (let i = 1; i <= totalSessions; i++) {
            sessionAttendance.set(String(i), 'pending');
        }

        const newRSVP = new EventRSVP({
            eventId,
            name,
            email,
            sessionAttendance,
            source: source || 'manual',
        });

        await newRSVP.save();

        const rsvpCount = await EventRSVP.countDocuments({ eventId });
        await Post.findByIdAndUpdate(eventId, { rsvps: rsvpCount });

        res.status(201).json(newRSVP);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});


// Create post (Protected - Club Officer Only)
router.post('/', verifyClubOfficer, async (req, res) => {
    try {
        // Whitelist allowed fields to prevent arbitrary data injection
        const allowedFields = [
            'title', 'content', 'image', 'coverImage', 'type', 'status',
            'clubId', 'clubName', 'clubImage', // These are validated by verifyClubOfficer implicitly but nice to be explicit
            'date', 'time', 'location', 'locationType', 'locationUrl',
            'registrationStart', 'registrationStartTime', 'registrationEnd', 'registrationEndTime',
            'attachments', 'totalSessions'
        ];

        const postData = {};
        allowedFields.forEach(field => {
            if (req.body[field] !== undefined) postData[field] = req.body[field];
        });

        // Force author to be current user
        postData.authorId = req.user.id;
        postData.authorName = req.user.name || 'Club Officer';

        // Force critical stats to defaults
        postData.likes = 0;
        postData.rsvps = 0;
        postData.budgetVerified = false;
        postData.budgetVerifiedBy = null;
        postData.budgetVerifiedAt = null;

        const newPost = new Post(postData);
        const savedPost = await newPost.save();

        // Create a database notification and trigger FCM push notification to club members
        try {
            const newNotification = new Notification({
                title: savedPost.title,
                message: savedPost.type === 'event'
                    ? `New event scheduled: "${savedPost.title}" at ${savedPost.location || 'campus'}`
                    : `New announcement: "${savedPost.title}"`,
                type: savedPost.type || 'info',
                clubId: savedPost.clubId,
                relatedId: savedPost._id.toString(),
            });
            const savedNotification = await newNotification.save();

            sendPushToClubMembers(
                savedPost.clubId,
                savedNotification.title,
                savedNotification.message,
                {
                    type: savedNotification.type,
                    notificationId: savedNotification._id.toString(),
                    clubId: savedPost.clubId.toString(),
                    relatedId: savedPost._id.toString(),
                }
            ).catch(err => console.error("FCM post creation error:", err));
        } catch (notifError) {
            console.error("Failed to create notification for new post:", notifError);
        }

        res.status(201).json(savedPost);
    } catch (error) {
        console.error("Error creating post", error);
        // Better error handling for Mongoose validation errors
        if (error.name === 'ValidationError') {
            const messages = Object.values(error.errors).map(val => val.message);
            return res.status(400).json({ message: messages.join(', ') });
        }
        res.status(500).json({ message: error.message || 'Server error' });
    }
});

// GET tasks assigned to current user
router.get('/user/tasks', verifyToken, async (req, res) => {
    try {
        const userEmail = req.user.email;

        // Fetch standalone tasks from Task collection
        const standaloneTasksMatches = await Task.find({
            assignedToEmails: userEmail
        }).lean();

        // Fetch club names for standalone tasks
        const userTasks = await Promise.all(standaloneTasksMatches.map(async (task) => {
            const club = await Club.findById(task.clubId);
            return {
                ...task,
                id: task._id,
                clubName: club?.name || 'Club Task',
                eventTitle: task.relatedEventTitle || 'General Task',
                eventId: task.relatedEventId || null,
                type: 'standalone-task'
            };
        }));

        // Sort by deadline (ascending) or creation (descending)
        userTasks.sort((a, b) => {
            const dateA = a.deadline ? new Date(a.deadline) : new Date(0);
            const dateB = b.deadline ? new Date(b.deadline) : new Date(0);

            if (a.deadline && b.deadline) {
                return dateA - dateB;
            }
            if (a.deadline) return -1;
            if (b.deadline) return 1;

            return new Date(b.createdAt) - new Date(a.createdAt);
        });

        res.json(userTasks);
    } catch (error) {
        console.error('Error fetching user tasks:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Update post
// Update post
router.put('/:id', verifyToken, async (req, res) => {
    try {
        const post = await Post.findById(req.params.id);
        if (!post) return res.status(404).json({ message: 'Post not found' });

        // Authorization Check
        const isCreator = post.authorId === req.user.id;
        const isAdmin = req.user.role === 'admin';
        let isClubOfficer = false;

        if (!isCreator && !isAdmin) {
            // 1. Check ClubMember collection (modern way)
            // Check both standard role names AND boardType for custom role labels
            const member = await ClubMember.findOne({
                clubId: post.clubId,
                $and: [
                    {
                        $or: [
                            { userId: req.user.id },
                            { email: { $regex: new RegExp(`^${req.user.email}$`, 'i') } }
                        ]
                    },
                    {
                        $or: [
                            { role: { $in: ['Secretary', 'President', 'Treasurer', 'Advisor'] } },
                            { boardType: { $in: ['main', 'executive'] } }
                        ]
                    }
                ]
            });
            if (member) isClubOfficer = true;

            // 2. Check Club document fields (legacy/direct way)
            if (!isClubOfficer) {
                const club = await Club.findById(post.clubId);
                if (club) {
                    const userId = req.user.id;
                    const userEmail = req.user.email;

                    if (
                        club.secretaryId === userId || club.secretaryEmail === userEmail ||
                        club.presidentId === userId || club.presidentEmail === userEmail ||
                        club.treasurerId === userId || club.treasurerEmail === userEmail ||
                        club.advisorId === userId || club.advisorEmail === userEmail
                    ) {
                        isClubOfficer = true;
                    }
                }
            }
        }

        if (!isCreator && !isAdmin && !isClubOfficer) {
            return res.status(403).json({ message: 'Not authorized to update this post' });
        }


        // Whitelist allowed updates
        const allowedUpdates = [
            'title', 'content', 'image', 'coverImage', 'type', 'status',
            // 'clubId', 'clubName' - prevented from changing club ownership
            'date', 'time', 'location', 'locationType', 'locationUrl',
            'registrationStart', 'registrationStartTime', 'registrationEnd', 'registrationEndTime',
            'registrationLink', 'responseSpreadsheetUrl', 'eventWhatsappLink',
            'attachments',
            'eventPhotos', 'totalSessions',
            // Budget image allowed to be updated here or via specific route, 
            // but if updated here, we must reset verification (handled below or safely excluded)
            // Let's exclude budgetImage here to force use of the dedicated route which handles logic overrides
        ];

        const updates = {};
        allowedUpdates.forEach(field => {
            if (req.body[field] !== undefined) updates[field] = req.body[field];
        });

        // Ensure updatedAt is set
        updates.updatedAt = new Date();

        const updatedPost = await Post.findByIdAndUpdate(req.params.id, updates, { new: true });
        res.json(updatedPost);
    } catch (error) {
        console.error("Error updating post:", error);
        res.status(500).json({ message: 'Server error' });
    }
})


// Delete post (Protected)
// Delete post (Protected)
router.delete('/:id', verifyToken, async (req, res) => {
    try {
        const post = await Post.findById(req.params.id);
        if (!post) return res.status(404).json({ message: 'Post not found' });

        // Authorization Check
        const isCreator = post.authorId === req.user.id;
        const isAdmin = req.user.role === 'admin';
        let isClubOfficer = false;

        if (!isCreator && !isAdmin) {
            // 1. Check ClubMember collection
            // Check both standard role names AND boardType for custom role labels
            const member = await ClubMember.findOne({
                clubId: post.clubId,
                $and: [
                    {
                        $or: [
                            { userId: req.user.id },
                            { email: { $regex: new RegExp(`^${req.user.email}$`, 'i') } }
                        ]
                    },
                    {
                        $or: [
                            { role: { $in: ['Secretary', 'President', 'Treasurer', 'Advisor'] } },
                            { boardType: { $in: ['main', 'executive'] } }
                        ]
                    }
                ]
            });
            if (member) isClubOfficer = true;

            // 2. Check Club document fields
            if (!isClubOfficer) {
                const club = await Club.findById(post.clubId);
                if (club) {
                    const userId = req.user.id;
                    const userEmail = req.user.email;

                    if (
                        club.secretaryId === userId || club.secretaryEmail === userEmail ||
                        club.presidentId === userId || club.presidentEmail === userEmail ||
                        club.treasurerId === userId || club.treasurerEmail === userEmail ||
                        club.advisorId === userId || club.advisorEmail === userEmail
                    ) {
                        isClubOfficer = true;
                    }
                }
            }
        }

        if (!isCreator && !isAdmin && !isClubOfficer) {
            return res.status(403).json({ message: 'Not authorized to delete this post' });
        }

        await Post.findByIdAndDelete(req.params.id);
        // Delete associated notifications
        await Notification.deleteMany({ relatedId: req.params.id });

        // Trigger silent push notification to club members to sync deletions
        sendPushToClubMembers(
            post.clubId,
            "",
            "",
            {
                action: "delete_post",
                relatedId: req.params.id
            }
        ).catch(err => console.error("FCM delete broadcast error:", err));

        res.json({ message: 'Post deleted' });
    } catch (error) {
        console.error("Error deleting post:", error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Upload/Update budget image (Treasurer only)
router.put('/:id/budget', verifyToken, async (req, res) => {
    try {
        const post = await Post.findById(req.params.id);
        if (!post) {
            return res.status(404).json({ message: 'Post not found' });
        }

        // Check if user is treasurer OF THIS CLUB
        if (req.user.role === 'admin') {
            // Admin allowed
        } else {
            // Check if user is treasurer OR on main board (which includes treasurer role)
            const isTreasurer = await ClubMember.findOne({
                clubId: post.clubId,
                $and: [
                    {
                        $or: [
                            { userId: req.user.id },
                            { email: { $regex: new RegExp(`^${req.user.email}$`, 'i') } }
                        ]
                    },
                    {
                        $or: [
                            { role: { $regex: /treasurer/i } },
                            { boardType: 'main' }  // Main board members can manage budgets
                        ]
                    }
                ]
            });

            if (!isTreasurer) {
                return res.status(403).json({ message: 'Only the treasurer or main board members of this club can upload budgets' });
            }
        }

        const { budgetImage } = req.body;
        if (!budgetImage) {
            return res.status(400).json({ message: 'Budget image URL is required' });
        }

        const updatedPost = await Post.findByIdAndUpdate(
            req.params.id,
            {
                budgetImage,
                budgetVerified: false, // Reset verification when budget is updated
                budgetVerifiedBy: null,
                budgetVerifiedAt: null,
                updatedAt: new Date()
            },
            { new: true }
        );

        if (!updatedPost) {
            return res.status(404).json({ message: 'Post not found' });
        }

        res.json(updatedPost);
    } catch (error) {
        console.error('Error uploading budget:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Verify budget (Advisor only)
router.put('/:id/budget/verify', verifyToken, async (req, res) => {
    try {
        const post = await Post.findById(req.params.id);
        if (!post) {
            return res.status(404).json({ message: 'Post not found' });
        }

        // Check if user is advisor OF THIS CLUB
        if (req.user.role === 'admin') {
            // Admin allowed
        } else {
            // Check if user is advisor OR on main board
            const isAdvisor = await ClubMember.findOne({
                clubId: post.clubId,
                $and: [
                    {
                        $or: [
                            { userId: req.user.id },
                            { email: { $regex: new RegExp(`^${req.user.email}$`, 'i') } }
                        ]
                    },
                    {
                        $or: [
                            { role: { $regex: /advisor/i } },
                            { boardType: 'main' }  // Main board members can verify budgets
                        ]
                    }
                ]
            });

            if (!isAdvisor) {
                return res.status(403).json({ message: 'Only the advisor or main board members of this club can verify budgets' });
            }
        }

        if (!post.budgetImage) {
            return res.status(400).json({ message: 'No budget uploaded for this event' });
        }

        const updatedPost = await Post.findByIdAndUpdate(
            req.params.id,
            {
                budgetVerified: true,
                budgetVerifiedBy: req.user.id,
                budgetVerifiedAt: new Date(),
                updatedAt: new Date()
            },
            { new: true }
        );

        res.json(updatedPost);
    } catch (error) {
        console.error('Error verifying budget:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// ==================== CERTIFICATE ROUTES ====================

// Save certificate template configuration (President/Secretary only)
router.put('/:id/certificate-template', verifyToken, async (req, res) => {
    try {
        const post = await Post.findById(req.params.id);
        if (!post) return res.status(404).json({ message: 'Post not found' });

        // Authorization: Admin or Officer of THIS club
        if (req.user.role !== 'admin') {
            // Check both standard role names AND boardType for custom role labels
            const isOfficer = await ClubMember.findOne({
                clubId: post.clubId,
                $and: [
                    {
                        $or: [
                            { userId: req.user.id },
                            { email: { $regex: new RegExp(`^${req.user.email}$`, 'i') } }
                        ]
                    },
                    {
                        $or: [
                            { role: { $in: ['Secretary', 'President'] } },
                            { boardType: { $in: ['main', 'executive'] } }  // Board members can manage certificates
                        ]
                    }
                ]
            });

            if (!isOfficer) {
                return res.status(403).json({ message: 'Only presidents, secretaries, and board members of this club can manage certificates' });
            }
        }

        const { templateUrl, namePosition } = req.body;
        if (!templateUrl) {
            return res.status(400).json({ message: 'Template URL is required' });
        }

        const updatedPost = await Post.findByIdAndUpdate(
            req.params.id,
            {
                certificateTemplate: {
                    templateUrl,
                    namePosition: namePosition || {
                        x: 50,
                        y: 50,
                        fontSize: 48,
                        fontFamily: 'Arial',
                        color: '#000000'
                    }
                },
                updatedAt: new Date()
            },
            { new: true }
        );

        if (!updatedPost) {
            return res.status(404).json({ message: 'Post not found' });
        }

        res.json(updatedPost);
    } catch (error) {
        console.error('Error saving certificate template:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Update participant certificate URL (President/Secretary only)
router.patch('/:id/rsvps/:rsvpId/certificate', verifyToken, async (req, res) => {
    try {
        const rsvp = await EventRSVP.findById(req.params.rsvpId);
        if (!rsvp) return res.status(404).json({ message: 'RSVP not found' });

        // We need the event to check club permission
        const post = await Post.findById(req.params.id);
        if (!post) return res.status(404).json({ message: 'Event not found' });

        // Authorization: Admin or Officer of THIS club
        if (req.user.role !== 'admin') {
            // Check both standard role names AND boardType for custom role labels
            const isOfficer = await ClubMember.findOne({
                clubId: post.clubId,
                $and: [
                    {
                        $or: [
                            { userId: req.user.id },
                            { email: { $regex: new RegExp(`^${req.user.email}$`, 'i') } }
                        ]
                    },
                    {
                        $or: [
                            { role: { $in: ['Secretary', 'President'] } },
                            { boardType: { $in: ['main', 'executive'] } }  // Board members can update certificates
                        ]
                    }
                ]
            });

            if (!isOfficer) {
                return res.status(403).json({ message: 'Only presidents, secretaries, and board members of this club can update certificates' });
            }
        }

        const { certificateUrl } = req.body;
        if (!certificateUrl) {
            return res.status(400).json({ message: 'Certificate URL is required' });
        }

        const updatedRsvp = await EventRSVP.findByIdAndUpdate(
            req.params.rsvpId,
            { certificateUrl },
            { new: true }
        );

        res.json(updatedRsvp);

        if (!rsvp) {
            return res.status(404).json({ message: 'RSVP not found' });
        }

        res.json(rsvp);
    } catch (error) {
        console.error('Error updating certificate:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// ==================== REPORT SUBMISSION ROUTE ====================

// Submit event report (President/Secretary only)
router.put('/:id/report', verifyToken, async (req, res) => {
    try {
        const post = await Post.findById(req.params.id);
        if (!post) return res.status(404).json({ message: 'Event not found' });

        // Only allow event type posts to have reports
        if (post.type !== 'event') {
            return res.status(400).json({ message: 'Reports can only be submitted for events' });
        }

        // Authorization: Admin or President/Secretary of THIS club
        if (req.user.role !== 'admin') {
            // Check if user is President or Secretary (not treasurer, not advisor)
            const isAuthorized = await ClubMember.findOne({
                clubId: post.clubId,
                $and: [
                    {
                        $or: [
                            { userId: req.user.id },
                            { email: { $regex: new RegExp(`^${req.user.email}$`, 'i') } }
                        ]
                    },
                    {
                        $or: [
                            { role: { $in: ['Secretary', 'President', 'secretary', 'president'] } },
                            { boardType: { $in: ['main', 'executive'] } }  // Board members can submit reports
                        ]
                    }
                ]
            });

            if (!isAuthorized) {
                return res.status(403).json({ message: 'Only presidents and secretaries can submit event reports' });
            }
        }

        const { reportUrl, reportFilename } = req.body;

        // Allow reportUrl to be null (for deletion) but require it if not deleting
        if (reportUrl === undefined) {
            return res.status(400).json({ message: 'Report URL is required' });
        }

        const updatedPost = await Post.findByIdAndUpdate(
            req.params.id,
            {
                reportUrl,
                reportFilename: reportUrl ? reportFilename : null, // Store filename if URL exists, else clear it
                // Only update submission details if adding a report, otherwise clear them
                reportSubmittedBy: reportUrl ? req.user.id : null,
                reportSubmittedByName: reportUrl ? (req.user.name || 'Club Officer') : null,
                reportSubmittedAt: reportUrl ? new Date() : null,
                updatedAt: new Date()
            },
            { new: true }
        );

        res.json(updatedPost);
    } catch (error) {
        console.error('Error submitting report:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Delete event report (President/Secretary only)
router.delete('/:id/report', verifyToken, async (req, res) => {
    try {
        const post = await Post.findById(req.params.id);
        if (!post) return res.status(404).json({ message: 'Event not found' });

        if (post.type !== 'event') {
            return res.status(400).json({ message: 'Reports can only be deleted for events' });
        }

        // Authorization: Admin or President/Secretary of THIS club
        if (req.user.role !== 'admin') {
            const isAuthorized = await ClubMember.findOne({
                clubId: post.clubId,
                $and: [
                    {
                        $or: [
                            { userId: req.user.id },
                            { email: { $regex: new RegExp(`^${req.user.email}$`, 'i') } }
                        ]
                    },
                    {
                        $or: [
                            { role: { $in: ['Secretary', 'President', 'secretary', 'president'] } },
                            { boardType: { $in: ['main', 'executive'] } }
                        ]
                    }
                ]
            });

            if (!isAuthorized) {
                return res.status(403).json({ message: 'Only presidents and secretaries can delete event reports' });
            }
        }

        const updatedPost = await Post.findByIdAndUpdate(
            req.params.id,
            {
                reportUrl: null,
                reportFilename: null,
                reportSubmittedBy: null,
                reportSubmittedByName: null,
                reportSubmittedAt: null,
                updatedAt: new Date()
            },
            { new: true }
        );

        res.json(updatedPost);
    } catch (error) {
        console.error('Error deleting report:', error);
        res.status(500).json({ message: 'Server error' });
    }
});


/**
 * Send event update emails to all attendees
 */
router.post('/send-event-update', verifyClubOfficer, async (req, res) => {
    try {
        const { eventId, updateMessage, attendees, eventTitle, clubName } = req.body;

        if (!eventId || !updateMessage || !attendees || !Array.isArray(attendees)) {
            return res.status(400).json({ message: 'Missing required fields' });
        }

        // Send emails in parallel
        const promises = attendees.map(attendee =>
            sendEventUpdateEmail({
                recipientEmail: attendee.email,
                recipientName: attendee.name,
                eventTitle,
                updateMessage,
                clubName
            })
        );

        await Promise.allSettled(promises);

        res.json({ message: `Successfully processed ${attendees.length} email notifications` });
    } catch (error) {
        console.error('Error in send-event-update route:', error);
        res.status(500).json({ message: 'Server error' });
    }
});



export default router;
