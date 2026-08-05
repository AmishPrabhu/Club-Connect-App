
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from '../models/User.js';

dotenv.config();

const checkAdmin = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        const users = await User.find({ role: 'admin' });
        if (users.length > 0) {
            console.log(`Found ${users.length} Admin(s):`);
            users.forEach(user => {
                console.log('- Email:', user.email);
                console.log('  Role:', user.role);
                console.log('  Password Hash:', user.password ? user.password.substring(0, 10) + '...' : 'N/A');
            });
        } else {
            console.log('No Admins FOUND');
        }
        await mongoose.disconnect();
    } catch (error) {
        console.error(error);
    }
};

checkAdmin();
