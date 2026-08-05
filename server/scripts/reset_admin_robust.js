
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';
import User from '../models/User.js';

dotenv.config();

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/club-connect';

const resetAdmin = async () => {
    try {
        const email = process.argv[2];
        const password = process.argv[3] || 'admin';

        if (!email) {
            console.error("Usage: node reset_admin_robust.js <email> [password]");
            process.exit(1);
        }

        console.log('Connecting to:', MONGODB_URI);
        await mongoose.connect(MONGODB_URI);
        console.log('Connected to MongoDB');

        const hashedPassword = await bcrypt.hash(password, 10);

        const updates = {
            email,
            password: hashedPassword,
            name: 'Super Admin',
            role: 'admin',
            clubId: null,
            clubName: null
        };

        const user = await User.findOneAndUpdate({ email }, updates, {
            new: true,
            upsert: true,
            setDefaultsOnInsert: true
        });

        console.log('SUCCESS: Admin user updated.');
        console.log('Email:', user.email);
        console.log('Password set to:', password);

        await mongoose.disconnect();
        process.exit(0);
    } catch (error) {
        console.error('FATAL ERROR:', error);
        process.exit(1);
    }
};

resetAdmin();
