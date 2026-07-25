/**
 * SSE (Server-Sent Events) Route
 *
 * GET /api/sse
 * 
 * Authenticated clients connect here to receive real-time push events.
 * The connection stays open until the client disconnects or the server restarts.
 * 
 * Auth: JWT token via Authorization header OR ?token= query param
 * (query param needed because EventSource API doesn't support custom headers)
 */

import express from 'express';
import jwt from 'jsonwebtoken';
import { addClient, removeClient } from '../services/sseService.js';

const router = express.Router();

router.get('/', (req, res) => {
    // ── Auth: try Authorization header first, then query param ──
    let token = null;

    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
        token = authHeader.slice(7);
    } else if (req.query.token) {
        token = req.query.token;
    }

    if (!token) {
        return res.status(401).json({ message: 'Authentication required for SSE.' });
    }

    let userId;
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        userId = decoded.id || decoded._id || decoded.userId;
        if (!userId) throw new Error('No user id in token');
    } catch (err) {
        return res.status(401).json({ message: 'Invalid or expired token.' });
    }

    userId = userId.toString();

    // ── Set SSE headers ──
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no'); // Disable Nginx buffering if present
    res.flushHeaders(); // Send headers immediately

    // ── Register client ──
    addClient(userId, res);

    // ── Send initial "connected" event so client knows the stream is live ──
    res.write(`event: connected\ndata: ${JSON.stringify({ userId, ts: Date.now() })}\n\n`);

    // ── Cleanup on disconnect ──
    req.on('close', () => {
        removeClient(userId, res);
    });

    req.on('error', () => {
        removeClient(userId, res);
    });
});

export default router;
