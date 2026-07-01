import express from 'express';
import Task from '../models/Task.js';
import Club from '../models/Club.js';
import { verifyToken, verifyClubOfficer } from '../middleware/auth.js';
import { sendTaskAssignmentEmail } from '../services/emailService.js';

const router = express.Router();

// Get all tasks for a club
router.get('/', verifyToken, async (req, res) => {
    try {
        const { clubId } = req.query;
        if (!clubId) {
            return res.status(400).json({ message: 'Club ID is required' });
        }

        // Basic authorization check could be added here to ensure user belongs to club,
        // but often we rely on the specific club dashboard access control on frontend + token validity.
        // For stricter security, we should verify the user is a member of this club.

        const tasks = await Task.find({ clubId }).sort({ deadline: 1, createdAt: -1 });
        res.json(tasks);
    } catch (error) {
        console.error('Error fetching tasks:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Create a new task
router.post('/', verifyClubOfficer, async (req, res) => {
    try {
        const {
            title,
            description,
            clubId,
            assignedTo,
            assignedToEmails,
            deadline,
            relatedEventId,
            relatedEventTitle
        } = req.body;

        const newTask = new Task({
            title,
            description,
            clubId,
            assignedTo: assignedTo || [],
            assignedToEmails: assignedToEmails || [],
            deadline,
            relatedEventId: relatedEventId || null,
            relatedEventTitle: relatedEventTitle || '',
            createdBy: req.user.name || req.user.email || 'Club Officer',
            createdById: req.user.id,
        });

        const savedTask = await newTask.save();

        // Fire-and-forget email notifications
        (async () => {
            try {
                if (assignedToEmails && assignedToEmails.length > 0) {
                    const club = await Club.findById(clubId);
                    const clubName = club?.name || 'Your Club';
                    const assignedBy = req.user.name || 'a Club Officer';

                    for (const email of assignedToEmails) {
                        await sendTaskAssignmentEmail({
                            recipientEmail: email,
                            recipientName: 'Team Member', // We don't have all names easily here, but email is primary
                            taskTitle: title,
                            description,
                            deadline,
                            clubName,
                            assignedBy
                        });
                    }
                }
            } catch (err) {
                console.error('Error in task creation email trigger:', err);
            }
        })();

        res.status(201).json(savedTask);
    } catch (error) {
        console.error('Error creating task:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Update a task
router.put('/:id', verifyClubOfficer, async (req, res) => {
    try {
        const {
            title,
            description,
            assignedTo,
            assignedToEmails,
            status,
            deadline,
            relatedEventId,
            relatedEventTitle
        } = req.body;

        const oldTask = await Task.findById(req.params.id);

        const updatedTask = await Task.findByIdAndUpdate(
            req.params.id,
            {
                title,
                description,
                assignedTo,
                assignedToEmails,
                status,
                deadline,
                relatedEventId,
                relatedEventTitle,
                updatedAt: Date.now()
            },
            { new: true }
        );

        if (!updatedTask) {
            return res.status(404).json({ message: 'Task not found' });
        }

        // Fire-and-forget email notifications for NEW assignees
        (async () => {
            try {
                const newEmails = assignedToEmails?.filter(email => !oldTask.assignedToEmails?.includes(email)) || [];
                if (newEmails.length > 0) {
                    const club = await Club.findById(updatedTask.clubId);
                    const clubName = club?.name || 'Your Club';
                    const assignedBy = req.user.name || 'a Club Officer';

                    for (const email of newEmails) {
                        await sendTaskAssignmentEmail({
                            recipientEmail: email,
                            recipientName: 'Team Member',
                            taskTitle: updatedTask.title,
                            description: updatedTask.description,
                            deadline: updatedTask.deadline,
                            clubName,
                            assignedBy
                        });
                    }
                }
            } catch (err) {
                console.error('Error in task update email trigger:', err);
            }
        })();

        res.json(updatedTask);
    } catch (error) {
        console.error('Error updating task:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Delete a task
router.delete('/:id', verifyToken, async (req, res) => {
    try {
        // First, fetch the task to get the clubId
        const task = await Task.findById(req.params.id);
        if (!task) {
            return res.status(404).json({ message: 'Task not found' });
        }

        // Manually verify the user is an officer of this club
        // (We can't use verifyClubOfficer middleware directly because clubId is not in route params)
        const ClubMember = (await import('../models/ClubMember.js')).default;

        const isOfficer = await ClubMember.findOne({
            clubId: task.clubId,
            $and: [
                // User identity check (userId OR email)
                {
                    $or: [
                        { userId: req.user.id },
                        { email: { $regex: new RegExp(`^${req.user.email}$`, 'i') } }
                    ]
                },
                // Officer status check (standard role names OR boardType)
                {
                    $or: [
                        { role: { $in: ['Secretary', 'President', 'Treasurer', 'Advisor', 'secretary', 'president', 'treasurer', 'advisor'] } },
                        { boardType: { $in: ['main', 'executive'] } }
                    ]
                }
            ]
        });

        // Also allow admin to delete
        if (!isOfficer && req.user.role !== 'admin') {
            return res.status(403).json({ message: 'Access denied. You are not an officer of this club.' });
        }

        const deletedTask = await Task.findByIdAndDelete(req.params.id);
        res.json({ message: 'Task deleted successfully' });
    } catch (error) {
        console.error('Error deleting task:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

export default router;
