import express from 'express';
import Notification from '../models/Notification.js';
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
        res.json(notifications);
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
        await Notification.findByIdAndUpdate(req.params.id, { read: true });
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Delete notification
router.delete('/:id', verifyToken, async (req, res) => {
    try {
        await Notification.findByIdAndDelete(req.params.id);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
})

export default router;
