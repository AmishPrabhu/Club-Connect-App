// Inspect Club Officer Emails
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import Club from '../models/Club.js';

dotenv.config();

async function checkEmails() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        const clubs = await Club.find({}, 'name secretaryEmail presidentEmail treasurerEmail advisorEmail');
        console.log(JSON.stringify(clubs, null, 2));
        mongoose.disconnect();
    } catch (error) {
        console.error(error);
    }
}
checkEmails();
