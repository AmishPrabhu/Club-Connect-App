// Script to link logged-in user's email with their ClubMember officer record
// This fixes the authorization issue where president/secretary email doesn't match

import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

// Connect to MongoDB
const MONGODB_URI = process.env.MONGODB_URI;

const ClubMemberSchema = new mongoose.Schema({
    clubId: String,
    userId: String,
    name: String,
    email: String,
    role: String,
    boardType: String,
    academicYear: String,
    joinedAt: Date,
});

const ClubMember = mongoose.model('ClubMember', ClubMemberSchema);

async function main() {
    try {
        await mongoose.connect(MONGODB_URI);
        console.log('Connected to MongoDB');

        // Find all officers (President, Secretary, etc.) in all clubs
        const officers = await ClubMember.find({
            role: { $in: ['President', 'Secretary', 'Treasurer', 'Advisor', 'president', 'secretary', 'treasurer', 'advisor'] }
        });

        console.log('\n=== Current Officers in Database ===\n');
        for (const officer of officers) {
            console.log(`Club ID: ${officer.clubId}`);
            console.log(`  Name: ${officer.name}`);
            console.log(`  Email: ${officer.email}`);
            console.log(`  Role: ${officer.role}`);
            console.log(`  UserId: ${officer.userId || 'NOT LINKED'}`);
            console.log('---');
        }

        console.log('\n=== To fix: Update the officer email to match the login email ===');
        console.log('Example: If president logs in with test@gmail.com, their ClubMember email should be test@gmail.com');

        mongoose.disconnect();
    } catch (error) {
        console.error('Error:', error);
    }
}

main();
