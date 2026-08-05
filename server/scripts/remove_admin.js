import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from '../models/User.js';

dotenv.config();

const removeAdmin = async () => {
    try {
        const email = process.argv[2];

        if (!email) {
            console.error("Usage: node remove_admin.js <email>");
            process.exit(1);
        }

        if (!process.env.MONGODB_URI) {
            console.error("error: MONGODB_URI missing");
            process.exit(1);
        }

        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to MongoDB');

        const result = await User.findOneAndUpdate(
            { email },
            { role: 'user' }, // Demote to a standard user
            { new: true }
        );

        if (result) {
            console.log(`Successfully removed admin rights for: ${result.email}`);
            console.log(`New role: ${result.role}`);
        } else {
            console.log(`User not found with email: ${email}`);
        }

        await mongoose.disconnect();
    } catch (error) {
        console.error('Error:', error);
    }
};

removeAdmin();
