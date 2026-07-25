/**
 * SSE (Server-Sent Events) Broadcaster Service
 * 
 * Manages all connected SSE clients and provides targeted broadcast methods.
 * Clients are stored in a Map keyed by userId for targeted sends.
 */

import ClubMember from '../models/ClubMember.js';

// Map of userId -> Set of response objects (a user can have multiple devices open)
const clients = new Map();

/**
 * Register a new SSE client connection.
 * @param {string} userId
 * @param {object} res - Express response object
 */
export function addClient(userId, res) {
    if (!clients.has(userId)) {
        clients.set(userId, new Set());
    }
    clients.get(userId).add(res);
    console.log(`[SSE] Client connected: ${userId} (total connections: ${countAll()})`);
}

/**
 * Remove an SSE client (called on disconnect/close).
 * @param {string} userId
 * @param {object} res
 */
export function removeClient(userId, res) {
    const userClients = clients.get(userId);
    if (userClients) {
        userClients.delete(res);
        if (userClients.size === 0) {
            clients.delete(userId);
        }
    }
    console.log(`[SSE] Client disconnected: ${userId} (total connections: ${countAll()})`);
}

/**
 * Count total active SSE connections.
 */
function countAll() {
    let total = 0;
    for (const set of clients.values()) total += set.size;
    return total;
}

/**
 * Send an SSE event to a single response object.
 * @param {object} res - Express response
 * @param {string} event - event name
 * @param {object} data - JSON-serializable data
 */
function sendToRes(res, event, data) {
    try {
        res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
    } catch (err) {
        // Client likely disconnected; ignore
    }
}

/**
 * Broadcast an event to ALL connected clients.
 * @param {string} event
 * @param {object} data
 */
export function broadcast(event, data) {
    for (const [, resSet] of clients.entries()) {
        for (const res of resSet) {
            sendToRes(res, event, data);
        }
    }
}

/**
 * Send an event to a specific user (all their devices).
 * @param {string} userId
 * @param {string} event
 * @param {object} data
 */
export function broadcastToUser(userId, event, data) {
    const userClients = clients.get(userId?.toString());
    if (userClients) {
        for (const res of userClients) {
            sendToRes(res, event, data);
        }
    }
}

/**
 * Send an event to all members of a specific club.
 * Looks up current ClubMember records in DB and fans out to online members.
 * @param {string} clubId
 * @param {string} event
 * @param {object} data
 */
export async function broadcastToClub(clubId, event, data) {
    try {
        const memberships = await ClubMember.find({ clubId }).select('userId email').lean();

        for (const member of memberships) {
            if (member.userId) {
                broadcastToUser(member.userId.toString(), event, data);
            }
        }
    } catch (err) {
        console.error('[SSE] broadcastToClub error:', err);
    }
}

/**
 * Send a heartbeat to all clients to keep connections alive.
 * Call this on an interval (e.g., every 30 seconds).
 */
export function sendHeartbeat() {
    for (const [, resSet] of clients.entries()) {
        for (const res of resSet) {
            try {
                res.write(': heartbeat\n\n');
            } catch (err) {
                // Ignore
            }
        }
    }
}
