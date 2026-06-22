
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from './models/User.js';

dotenv.config();

const checkAdmin = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        const user = await User.findOne({ email: 'admin@wce.ac.in' });
        if (user) {
            console.log('Admin Found:', user.email);
            console.log('Role:', user.role);
            console.log('Password Hash:', user.password.substring(0, 10) + '...');
        } else {
            console.log('Admin NOT FOUND');
        }
        await mongoose.disconnect();
    } catch (error) {
        console.error(error);
    }
};

checkAdmin();
