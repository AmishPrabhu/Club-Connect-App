import express from 'express';
import User from '../models/User.js';
import Club from '../models/Club.js';
import ClubMember from '../models/ClubMember.js';
import { verifyToken } from '../middleware/auth.js';
import { sendTeacherInvitationEmail } from '../services/emailService.js';
import { broadcastToUser } from '../services/sseService.js';

const router = express.Router();

// Get all teachers (Admin only) - MOVED HERE TO AVOID ROUTE COLLISION
router.get('/teachers', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'admin') {
            return res.status(403).json({ message: 'Only admins can view teachers' });
        }

        const teachers = await User.find({
            $or: [
                { role: 'teacher' },
                { roles: 'teacher' }
            ]
        }).select('-password');

        res.json(teachers);
    } catch (error) {
        console.error('[CRITICAL] Error fetching teachers:', error);
        console.error(error.stack);
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});




// Get my club memberships
router.get('/memberships', verifyToken, async (req, res) => {
    try {
        const memberships = await ClubMember.find({
            isCurrent: true,
            $or: [
                { userId: req.user.id },
                { email: { $regex: new RegExp(`^${req.user.email}$`, 'i') } }
            ]
        });

        const fullMemberships = await Promise.all(memberships.map(async (m) => {
            const club = await Club.findById(m.clubId);
            if (!club) return null;

            return {
                clubId: club._id,
                clubName: club.name,
                clubImage: club.image,
                clubIcon: '🏛️',
                role: m.role,
                boardType: m.boardType, // Include boardType for dashboard access control
                joinedAt: m.joinedAt,

                // Add styling props that frontend might expect
                clubColor: 'from-blue-500 to-cyan-500', // Default or fetch from club if exists
            };
        }));

        res.json(fullMemberships.filter(m => m));
    } catch (error) {
        console.error('Error fetching memberships:', error);
        res.status(500).json({ message: 'Server error' });
    }
});


// Get total student stats
router.get('/stats/count', async (req, res) => {
    try {
        const count = await User.countDocuments({ role: 'student' }); // Or just all users if 'student' role isn't strict yet
        // Fallback to all users if student role specific logic isn't populated
        const total = await User.countDocuments();
        res.json({ count: total });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});



// Get user profile
router.get('/:id', verifyToken, async (req, res) => {
    try {
        const user = await User.findById(req.params.id).select('-password -resetPasswordToken -resetPasswordExpires');
        if (!user) return res.status(404).json({ message: 'User not found' });
        res.json(user);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Update user profile
router.put('/:id', verifyToken, async (req, res) => {

    try {
        // Authorization Check: User can only update their own profile
        if (req.user.id !== req.params.id) {
            return res.status(403).json({ message: 'Not authorized to update this profile' });
        }

        const { name, bio, email, profileImage, clubId, clubName } = req.body;
        // Prevent role, clubId, clubName updates here for security
        // These should only be updated via specific actions (joining a club, being promoted)
        const updates = {};
        if (name !== undefined) updates.name = name;
        if (bio !== undefined) updates.bio = bio;
        if (email !== undefined) updates.email = email;
        if (profileImage !== undefined) updates.profileImage = profileImage;

        const updatedUser = await User.findByIdAndUpdate(req.params.id, updates, { new: true }).select('-password -resetPasswordToken -resetPasswordExpires');
        res.json(updatedUser);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Like a club
router.post('/:id/like/:clubId', verifyToken, async (req, res) => {
    try {
        if (req.user.id !== req.params.id) {
            return res.status(403).json({ message: 'Unauthorized' });
        }

        const user = await User.findById(req.params.id);
        if (!user.likedClubs.includes(req.params.clubId)) {
            user.likedClubs.push(req.params.clubId);
            await user.save();
        }
        res.json(user.likedClubs);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Remove teacher role from a user (Admin only)
router.post('/remove-teacher', verifyToken, async (req, res) => {
    try {
        // Verify user is admin
        if (req.user.role !== 'admin') {
            return res.status(403).json({ message: 'Only admins can remove teacher roles' });
        }

        const { userId } = req.body;
        if (!userId) {
            return res.status(400).json({ message: 'User ID is required' });
        }

        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        // Remove 'teacher' from roles array
        if (user.roles) {
            user.roles = user.roles.filter(role => role !== 'teacher');
        }

        // If primary role is teacher, revert to user
        if (user.role === 'teacher') {
            user.role = 'user';
        }

        // Clear managed clubs
        user.managedClubs = [];

        await user.save();

        broadcastToUser(user._id.toString(), 'user_updated', {
            action: 'remove-teacher',
            role: user.role,
            roles: user.roles
        });

        res.json({ message: 'Teacher role removed successfully' });
    } catch (error) {
        console.error('Error removing teacher role:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Unlike a club
router.delete('/:id/like/:clubId', verifyToken, async (req, res) => {
    try {
        if (req.user.id !== req.params.id) {
            return res.status(403).json({ message: 'Unauthorized' });
        }

        const user = await User.findById(req.params.id);
        user.likedClubs = user.likedClubs.filter(id => id !== req.params.clubId);
        await user.save();

        res.json(user.likedClubs);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// ==================== ADMIN: ASSIGN TEACHER ROLE ====================



// Assign teacher role to a user (Admin only)
router.post('/assign-teacher', verifyToken, async (req, res) => {

    try {
        // Verify user is admin
        if (req.user.role !== 'admin') {
            return res.status(403).json({ message: 'Only admins can assign teacher roles' });
        }

        const { email, name } = req.body;
        if (!email || !name) {
            return res.status(400).json({ message: 'Email and name are required' });
        }

        // Check if user exists
        const existingUser = await User.findOne({ email: { $regex: new RegExp(`^${email}$`, 'i') } });

        if (existingUser) {
            // User exists - update their role to teacher
            if (existingUser.role === 'admin') {
                return res.status(400).json({ message: 'Cannot assign teacher role to admin users' });
            }

            // Initialize roles array if it doesn't exist
            if (!existingUser.roles) {
                existingUser.roles = [];
            }

            // Add teacher to roles array if not already present
            if (!existingUser.roles.includes('teacher')) {
                existingUser.roles.push('teacher');
            }

            // Set primary role to teacher if currently 'user'
            if (existingUser.role === 'user') {
                existingUser.role = 'teacher';
            }

            await existingUser.save();

            broadcastToUser(existingUser._id.toString(), 'user_updated', {
                action: 'assign-teacher',
                role: existingUser.role,
                roles: existingUser.roles
            });

            return res.json({
                success: true,
                isNewUser: false,
                message: 'User role updated to teacher'
            });
        } else {
            // User doesn't exist - create a pending invitation (no password)
            const newUser = new User({
                email,
                name,
                role: 'teacher',
                roles: ['teacher'],
                managedClubs: [],
                // No password - user will set it during signup
            });

            await newUser.save();

            // Send invitation email
            const signUpUrl = `${process.env.FRONTEND_URL}?page=signUp&email=${encodeURIComponent(email)}`;
            await sendTeacherInvitationEmail({
                name,
                email,
                signUpUrl
            });

            return res.json({
                success: true,
                isNewUser: true,
                message: 'Teacher invitation created. User will receive an email to set their password during signup.'
            });
        }
    } catch (error) {
        console.error('Error assigning teacher role:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Remove teacher role from a user (Admin only)
router.post('/remove-teacher', verifyToken, async (req, res) => {
    try {
        // Verify user is admin
        if (req.user.role !== 'admin') {
            return res.status(403).json({ message: 'Only admins can remove teacher roles' });
        }

        const { userId } = req.body;
        if (!userId) {
            return res.status(400).json({ message: 'User ID is required' });
        }

        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        // Remove 'teacher' from roles array
        if (user.roles) {
            user.roles = user.roles.filter(role => role !== 'teacher');
        }

        // If primary role is teacher, revert to user
        if (user.role === 'teacher') {
            user.role = 'user';
        }

        // Clear managed clubs
        user.managedClubs = [];

        await user.save();

        res.json({ message: 'Teacher role removed successfully' });
    } catch (error) {
        console.error('Error removing teacher role:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// ==================== TEACHER ROUTES ====================

// Get teacher's managed clubs
router.get('/teacher/clubs', verifyToken, async (req, res) => {
    try {
        // Verify user is a teacher
        const isTeacher = req.user.role === 'teacher' || (req.user.roles && req.user.roles.includes('teacher'));
        if (!isTeacher && req.user.role !== 'admin') {
            return res.status(403).json({ message: 'Only teachers can access this endpoint' });
        }

        const user = await User.findById(req.user.id);
        if (!user) return res.status(404).json({ message: 'User not found' });

        // Fetch full club details for managed clubs
        const clubs = await Club.find({ _id: { $in: user.managedClubs || [] } });
        res.json(clubs);
    } catch (error) {
        console.error('Error fetching teacher clubs:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Add a club to teacher's managed list
router.post('/teacher/clubs', verifyToken, async (req, res) => {
    try {
        // Verify user is a teacher
        const isTeacher = req.user.role === 'teacher' || (req.user.roles && req.user.roles.includes('teacher'));
        if (!isTeacher && req.user.role !== 'admin') {
            return res.status(403).json({ message: 'Only teachers can access this endpoint' });
        }

        const { clubId } = req.body;
        if (!clubId) {
            return res.status(400).json({ message: 'Club ID is required' });
        }

        // Verify club exists
        const club = await Club.findById(clubId);
        if (!club) {
            return res.status(404).json({ message: 'Club not found' });
        }

        const user = await User.findById(req.user.id);
        if (!user) return res.status(404).json({ message: 'User not found' });

        // Add club if not already in list
        if (!user.managedClubs) user.managedClubs = [];
        if (!user.managedClubs.includes(clubId)) {
            user.managedClubs.push(clubId);
            await user.save();
        }

        res.json({ message: 'Club added to managed list', managedClubs: user.managedClubs });
    } catch (error) {
        console.error('Error adding club to teacher:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Remove a club from teacher's managed list
router.delete('/teacher/clubs/:clubId', verifyToken, async (req, res) => {
    try {
        // Verify user is a teacher
        const isTeacher = req.user.role === 'teacher' || (req.user.roles && req.user.roles.includes('teacher'));
        if (!isTeacher && req.user.role !== 'admin') {
            return res.status(403).json({ message: 'Only teachers can access this endpoint' });
        }

        const user = await User.findById(req.user.id);
        if (!user) return res.status(404).json({ message: 'User not found' });

        // Remove club from managed list
        if (user.managedClubs) {
            user.managedClubs = user.managedClubs.filter(id => id !== req.params.clubId);
            await user.save();
        }

        res.json({ message: 'Club removed from managed list', managedClubs: user.managedClubs });
    } catch (error) {
        console.error('Error removing club from teacher:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Get all reports for teacher's managed clubs AND advisor's assigned clubs
router.get('/teacher/reports', verifyToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const userRole = req.user.role;
        const userRoles = req.user.roles || [];

        // Verify user is a teacher OR advisor OR admin
        const isTeacher = userRole === 'teacher' || userRoles.includes('teacher');
        const isAdvisor = userRole === 'advisor' || userRoles.includes('advisor');
        const isAdmin = userRole === 'admin';

        if (!isTeacher && !isAdvisor && !isAdmin) {
            return res.status(403).json({ message: 'Only teachers, advisors, or admins can access this endpoint' });
        }

        const user = await User.findById(userId);
        if (!user) return res.status(404).json({ message: 'User not found' });

        const Post = (await import('../models/Post.js')).default;
        const ClubMember = (await import('../models/ClubMember.js')).default;

        let query = { type: 'event', reportUrl: { $ne: null } };

        // If not admin, restrict to managed clubs
        if (!isAdmin) {
            let accessibleClubIds = [];

            // 1. Add clubs managed by Teacher (from User.managedClubs)
            if (isTeacher && user.managedClubs && user.managedClubs.length > 0) {
                accessibleClubIds.push(...user.managedClubs);
            }

            // 2. Add clubs where user is an Advisor (from ClubMember)
            if (isAdvisor) {
                const advisorMemberships = await ClubMember.find({
                    $or: [
                        { userId: userId },
                        { email: user.email }
                    ],
                    role: { $regex: /^advisor$/i } // Case-insensitive check for 'Advisor'
                });

                const advisorClubIds = advisorMemberships.map(m => m.clubId);
                accessibleClubIds.push(...advisorClubIds);
            }

            // Remove duplicates
            accessibleClubIds = [...new Set(accessibleClubIds)];

            if (accessibleClubIds.length === 0) {
                return res.json([]); // No accessible clubs with reports
            }

            query.clubId = { $in: accessibleClubIds };
        }

        const events = await Post.find(query).sort({ reportSubmittedAt: -1 });

        // Format response with relevant details
        const reports = events.map(event => ({
            id: event._id,
            eventId: event._id,
            eventTitle: event.title,
            eventDate: event.date,
            clubId: event.clubId,
            clubName: event.clubName,
            reportUrl: event.reportUrl,
            reportFilename: event.reportFilename,
            reportSubmittedBy: event.reportSubmittedBy,
            reportSubmittedByName: event.reportSubmittedByName,
            reportSubmittedAt: event.reportSubmittedAt,
        }));

        res.json(reports);
    } catch (error) {
        console.error('Error fetching reports:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Delete user / teacher (Admin only)
router.delete('/:id', verifyToken, async (req, res) => {
    try {
        const isAdmin = req.user.role === 'admin' || (Array.isArray(req.user.roles) && req.user.roles.includes('admin'));
        if (!isAdmin) {
            return res.status(403).json({ message: 'Only admins can delete users/teachers' });
        }

        const userToDelete = await User.findById(req.params.id);
        if (!userToDelete) {
            return res.status(404).json({ message: 'User not found' });
        }

        // Delete user
        await User.findByIdAndDelete(req.params.id);

        // Clean up any club memberships or assigned club relationships
        await ClubMember.deleteMany({
            $or: [
                { userId: req.params.id },
                { email: userToDelete.email }
            ]
        });

        res.json({ message: 'Teacher/User deleted successfully' });
    } catch (error) {
        console.error('[CRITICAL] Error deleting user/teacher:', error);
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

export default router;
