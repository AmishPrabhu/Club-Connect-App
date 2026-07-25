/**
 * MongoDB Change Streams
 *
 * Watches Post, Notification, Club, and EventRSVP collections for changes
 * and broadcasts real-time SSE events to connected clients.
 *
 * Must be called AFTER mongoose.connect() resolves.
 */

import mongoose from 'mongoose';
import { broadcast, broadcastToClub, broadcastToUser } from '../services/sseService.js';
import User from '../models/User.js';

/**
 * Serialize a MongoDB document (Mongoose raw change stream doc) into a plain object.
 */
function serialize(doc) {
    if (!doc) return null;
    const obj = doc;
    if (obj._id) obj.id = obj._id.toString();
    return obj;
}

/**
 * Start all change stream watchers.
 * Safe to call once. Includes auto-resume on error.
 */
export function startChangeStreams() {
    watchPosts();
    watchNotifications();
    watchClubs();
    watchRsvps();
    console.log('[ChangeStreams] All MongoDB change stream watchers started.');
}

// ─── POSTS ─────────────────────────────────────────────────────────────────

function watchPosts() {
    const Post = mongoose.model('Post');
    const pipeline = [
        { $match: { operationType: { $in: ['insert', 'update', 'replace', 'delete'] } } }
    ];

    function open() {
        const stream = Post.watch(pipeline, { fullDocument: 'updateLookup' });

        stream.on('change', async (change) => {
            try {
                const opType = change.operationType;

                if (opType === 'insert') {
                    const doc = serialize(change.fullDocument);
                    // Broadcast to all (announcements/events are public)
                    broadcast('post_created', doc);

                } else if (opType === 'update' || opType === 'replace') {
                    const doc = serialize(change.fullDocument);
                    broadcast('post_updated', doc);

                } else if (opType === 'delete') {
                    broadcast('post_deleted', { id: change.documentKey._id.toString() });
                }
            } catch (err) {
                console.error('[ChangeStreams] Post change error:', err);
            }
        });

        stream.on('error', (err) => {
            console.error('[ChangeStreams] Post stream error, reconnecting in 5s:', err.message);
            stream.close();
            setTimeout(open, 5000);
        });

        stream.on('close', () => {
            console.warn('[ChangeStreams] Post stream closed, reconnecting in 5s...');
            setTimeout(open, 5000);
        });
    }

    open();
}

// ─── NOTIFICATIONS ──────────────────────────────────────────────────────────

function watchNotifications() {
    const Notification = mongoose.model('Notification');
    const pipeline = [
        { $match: { operationType: { $in: ['insert', 'update'] } } }
    ];

    function open() {
        const stream = Notification.watch(pipeline, { fullDocument: 'updateLookup' });

        stream.on('change', async (change) => {
            try {
                const doc = serialize(change.fullDocument);
                if (!doc) return;

                const opType = change.operationType;

                if (opType === 'insert') {
                    // Send to specific user if personal, or broadcast if global
                    if (doc.userId) {
                        broadcastToUser(doc.userId.toString(), 'notification_created', doc);
                    } else if (doc.clubId) {
                        // Club-specific notification: send to all club members
                        broadcastToClub(doc.clubId.toString(), 'notification_created', doc).catch(() => {});
                    } else {
                        // Global notification
                        broadcast('notification_created', doc);
                    }

                } else if (opType === 'update') {
                    // Typically read status update — send to the user who owns it
                    if (doc.userId) {
                        broadcastToUser(doc.userId.toString(), 'notification_updated', doc);
                    }
                }
            } catch (err) {
                console.error('[ChangeStreams] Notification change error:', err);
            }
        });

        stream.on('error', (err) => {
            console.error('[ChangeStreams] Notification stream error, reconnecting in 5s:', err.message);
            stream.close();
            setTimeout(open, 5000);
        });

        stream.on('close', () => {
            console.warn('[ChangeStreams] Notification stream closed, reconnecting in 5s...');
            setTimeout(open, 5000);
        });
    }

    open();
}

// ─── CLUBS ──────────────────────────────────────────────────────────────────

function watchClubs() {
    const Club = mongoose.model('Club');
    const pipeline = [
        { $match: { operationType: { $in: ['update', 'replace'] } } }
    ];

    function open() {
        const stream = Club.watch(pipeline, { fullDocument: 'updateLookup' });

        stream.on('change', async (change) => {
            try {
                const doc = serialize(change.fullDocument);
                if (!doc) return;

                // Broadcast club update to all club members
                if (doc._id) {
                    broadcastToClub(doc._id.toString(), 'club_updated', doc).catch(() => {});
                }
                // Also broadcast globally so the clubs list stays up to date
                broadcast('club_updated', doc);
            } catch (err) {
                console.error('[ChangeStreams] Club change error:', err);
            }
        });

        stream.on('error', (err) => {
            console.error('[ChangeStreams] Club stream error, reconnecting in 5s:', err.message);
            stream.close();
            setTimeout(open, 5000);
        });

        stream.on('close', () => {
            console.warn('[ChangeStreams] Club stream closed, reconnecting in 5s...');
            setTimeout(open, 5000);
        });
    }

    open();
}

// ─── EVENT RSVPs (certificates) ─────────────────────────────────────────────

function watchRsvps() {
    const EventRSVP = mongoose.model('EventRSVP');
    const pipeline = [
        { $match: { operationType: 'update' } }
    ];

    function open() {
        const stream = EventRSVP.watch(pipeline, { fullDocument: 'updateLookup' });

        stream.on('change', async (change) => {
            try {
                const doc = change.fullDocument;
                if (!doc) return;

                // Only emit if a certificateUrl was added/changed
                const updatedFields = change.updateDescription?.updatedFields || {};
                if (!updatedFields.certificateUrl) return;

                // Find the user who owns this RSVP by email
                if (doc.email) {
                    const user = await User.findOne({
                        email: { $regex: new RegExp(`^${doc.email}$`, 'i') }
                    }).select('_id').lean();

                    if (user) {
                        broadcastToUser(user._id.toString(), 'certificate_ready', {
                            rsvpId: doc._id.toString(),
                            eventId: doc.eventId?.toString(),
                            certificateUrl: doc.certificateUrl,
                            name: doc.name,
                        });
                    }
                }
            } catch (err) {
                console.error('[ChangeStreams] RSVP change error:', err);
            }
        });

        stream.on('error', (err) => {
            console.error('[ChangeStreams] RSVP stream error, reconnecting in 5s:', err.message);
            stream.close();
            setTimeout(open, 5000);
        });

        stream.on('close', () => {
            console.warn('[ChangeStreams] RSVP stream closed, reconnecting in 5s...');
            setTimeout(open, 5000);
        });
    }

    open();
}
