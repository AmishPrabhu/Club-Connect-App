import 'dotenv/config';
import express from 'express';
import mongoose from 'mongoose';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import hpp from 'hpp';

import './config/firebase.js';

import authRoutes from './routes/auth.js';
import clubRoutes from './routes/clubs.js';
import postRoutes from './routes/posts.js';
import notificationRoutes from './routes/notifications.js';
import userRoutes from './routes/users.js';
import bulkImportRoutes from './routes/bulk-import.js';
import tasksRoutes from './routes/tasks.js';

const app = express();
const PORT = (process.env.PORT && process.env.PORT != 5000) ? process.env.PORT : 5001;

// Middleware
app.use(cors({
    origin: [process.env.FRONTEND_URL, 'http://localhost:5173', 'http://localhost:3000'].filter(Boolean),
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'RateLimit-Remaining', 'RateLimit-Reset', 'Retry-After'],
    exposedHeaders: ['RateLimit-Remaining', 'RateLimit-Reset', 'Retry-After']
}));
app.use(helmet());
app.use(hpp());

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    limit: 500, // Limit each IP to 500 requests per `window` - tightened for security
    standardHeaders: 'draft-7', // draft-6: `RateLimit-*` headers; draft-7: combined `RateLimit` header
    legacyHeaders: false, // Disable the `X-RateLimit-*` headers
    message: 'Too many requests from this IP, please try again after 15 minutes',
    skipSuccessfulRequests: false, // Count all requests for the global limiter
});
app.use('/api', limiter);
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/clubs', bulkImportRoutes);
app.use('/api/clubs', clubRoutes);
app.use('/api/posts', postRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/users', userRoutes);
app.use('/api/tasks', tasksRoutes);

// Basic route
app.get('/', (req, res) => {
    res.send('Club Connect API is running');
});

// Database connection
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/club-connect')
    .then(() => {
        console.log('Connected to MongoDB');
        app.listen(PORT, '0.0.0.0', () => {
            console.log(`Server is running on http://0.0.0.0:${PORT}`);
        });
    })
    .catch((err) => {
        console.error('Failed to connect to MongoDB', err);
    });
