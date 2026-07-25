import express from 'express';
import Notification from '../models/Notification.js';
import ClubMember from '../models/ClubMember.js';
import Club from '../models/Club.js';
import { verifyToken, verifyTokenOptional } from '../middleware/auth.js';
import { sendPushToUsers, sendPushToClubMembers, sendPushGlobal } from '../services/pushService.js';

const router = express.Router();

// Get notifications for user or global
router.get('/', verifyTokenOptional, async (req, res) => {
    try {
        let query = { userId: null }; // Default: global only for unauthenticated
        if (req.user) {
            // Show: global, personal, AND all club notifications
            query = {
                $or: [
                    { userId: null, clubId: null },  // Global (no club-specific)
                    { userId: req.user.id },          // Personal
                    { clubId: { $ne: null } },        // ALL club notifications
                ]
            };
        }

        const notifications = await Notification.find(query).sort({ createdAt: -1 });
        
        // Dynamically calculate `read` status specific to the authenticated user
        const currentUserId = req.user?.id ? req.user.id.toString() : null;
        const result = notifications.map(doc => {
            const notifObj = doc.toObject();
            if (currentUserId) {
                const isReadByMe = Array.isArray(doc.readBy) && doc.readBy.map(String).includes(currentUserId);
                const isPersonalRead = doc.userId && doc.userId.toString() === currentUserId && doc.read === true;
                notifObj.read = isReadByMe || isPersonalRead;
            } else {
                notifObj.read = doc.read || false;
            }
            return notifObj;
        });

        res.json(result);
    } catch (error) {
        console.error("Error fetching notifications:", error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Create notification
router.post('/', verifyToken, async (req, res) => {
    try {
        const newNotification = new Notification(req.body);
        const savedNotification = await newNotification.save();
        
        // Trigger push notification asynchronously (fire-and-forget)
        const { title, message: body, userId, clubId, type, relatedId } = savedNotification;
        const dataPayload = {
            type: type || 'info',
            notificationId: savedNotification._id.toString(),
        };
        if (clubId) dataPayload.clubId = clubId.toString();
        if (relatedId) dataPayload.relatedId = relatedId.toString();

        if (userId) {
            sendPushToUsers([userId], title, body, dataPayload).catch(err => 
                console.error("FCM async user error:", err)
            );
        } else if (clubId) {
            sendPushToClubMembers(clubId, title, body, dataPayload).catch(err => 
                console.error("FCM async club error:", err)
            );
        } else {
            sendPushGlobal(title, body, dataPayload).catch(err => 
                console.error("FCM async global error:", err)
            );
        }

        res.status(201).json(savedNotification);
    } catch (error) {
        console.error("Create notification error:", error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Mark as read
router.put('/:id/read', verifyToken, async (req, res) => {
    try {
        const userIdStr = req.user.id.toString();
        const notif = await Notification.findById(req.params.id);
        if (!notif) return res.status(404).json({ message: 'Notification not found' });

        const updatePayload = {
            $addToSet: { readBy: userIdStr }
        };

        if (notif.userId && notif.userId.toString() === userIdStr) {
            updatePayload.$set = { read: true };
        }

        await Notification.findByIdAndUpdate(req.params.id, updatePayload);
        res.json({ success: true });
    } catch (error) {
        console.error("Error marking notification as read:", error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Delete notification
// Permissions:
// 1. Super Admin (role === 'admin'): Can delete ANY notification.
// 2. Teachers and Advisors (role === 'advisor' || 'teacher'): CANNOT delete any notification.
// 3. Main Board officers of THAT specific club (President, Secretary, Treasurer): Can delete notifications for THEIR club ONLY.
router.delete('/:id', verifyToken, async (req, res) => {
    try {
        const notif = await Notification.findById(req.params.id);
        if (!notif) return res.status(404).json({ message: 'Notification not found' });

        // 1. Super Admin can delete any notification
        if (req.user.role === 'admin') {
            await Notification.findByIdAndDelete(req.params.id);
            return res.json({ success: true });
        }

        // 2. Teachers and Advisors CANNOT delete any notification
        const userRole = req.user.role?.toLowerCase();
        if (userRole === 'advisor' || userRole === 'teacher') {
            return res.status(403).json({ message: 'Teachers and Advisors are not permitted to delete notifications.' });
        }

        // 3. Main Board Officers of the notification's specific club ONLY
        if (notif.clubId) {
            const emailLower = req.user.email?.toLowerCase();
            const club = await Club.findById(notif.clubId);

            let isMainBoardOfficer = false;

            // Direct check on Club email fields
            if (club) {
                if (
                    (club.presidentEmail && club.presidentEmail.toLowerCase() === emailLower) ||
                    (club.secretaryEmail && club.secretaryEmail.toLowerCase() === emailLower) ||
                    (club.treasurerEmail && club.treasurerEmail.toLowerCase() === emailLower)
                ) {
                    isMainBoardOfficer = true;
                }
            }

            // Check ClubMember collection for Main Board roles of THIS specific club
            if (!isMainBoardOfficer) {
                const mainBoardMember = await ClubMember.findOne({
                    clubId: notif.clubId,
                    $and: [
                        {
                            $or: [
                                { userId: req.user.id },
                                { email: { $regex: new RegExp(`^${req.user.email}$`, 'i') } }
                            ]
                        },
                        {
                            $or: [
                                { role: { $in: ['President', 'Secretary', 'Treasurer', 'president', 'secretary', 'treasurer'] } },
                                { boardType: 'main' }
                            ]
                        },
                        // Explicitly exclude Advisors/Teachers
                        { role: { $nin: ['Advisor', 'advisor', 'Teacher', 'teacher'] } }
                    ]
                });

                if (mainBoardMember) {
                    isMainBoardOfficer = true;
                }
            }

            if (isMainBoardOfficer) {
                await Notification.findByIdAndDelete(req.params.id);
                return res.json({ success: true });
            }
        }

        return res.status(403).json({ message: 'Access denied. Only Super Admin or Main Board Officers of this club can delete this notification.' });
    } catch (error) {
        console.error('Error deleting notification:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

export default router;
