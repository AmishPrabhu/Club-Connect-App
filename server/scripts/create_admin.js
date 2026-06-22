
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import bcrypt from 'bcryptjs';
import User from './models/User.js';

dotenv.config(); // Will pick up .env in same dir if run from server dir

const createAdmin = async () => {
    try {
        if (!process.env.MONGODB_URI) {
            console.error("error: MONGODB_URI missing");
            process.exit(1);
        }
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to MongoDB');

        const email = 'admin@wce.ac.in';
        const password = 'admin';
        const hashedPassword = await bcrypt.hash(password, 10);

        // Update if exists, or upsert (create)
        const result = await User.findOneAndUpdate(
            { email },
            {
                email,
                password: hashedPassword,
                name: 'Super Admin',
                role: 'admin',
                bio: 'The big boss',
                clubId: null,
                clubName: null
            },
            { upsert: true, new: true, setDefaultsOnInsert: true }
        );

        console.log('Admin User Created/Updated:', result.email);
        console.log('Password set to:', password);

        await mongoose.disconnect();
    } catch (error) {
        console.error('Error:', error);
    }
};

createAdmin();
