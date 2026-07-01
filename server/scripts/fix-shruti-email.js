// Fix Shruti's email mismatch
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from '../models/User.js';
import ClubMember from '../models/ClubMember.js';

dotenv.config();

async function fixShruti() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to MongoDB');

        // 1. Find the User with the correct email
        const correctEmail = 'shruti.patil_997@walchandsangli.ac.in';
        const user = await User.findOne({ email: correctEmail });

        if (!user) {
            console.log('User not found with email:', correctEmail);
            return;
        }
        console.log('Found User:', user.name, user._id);

        // 2. Find the ClubMember with the old/wrong email
        const oldEmail = 'shruti.patil@walchandsangli.ac.in';
        const member = await ClubMember.findOne({ email: oldEmail });

        if (!member) {
            console.log('ClubMember not found with email:', oldEmail);
        } else {
            console.log('Found ClubMember:', member.name, member.email);

            // 3. Update ClubMember to match User
            member.email = correctEmail;
            member.userId = user._id.toString();
            member.profileImage = user.profileImage || ''; // Sync image too

            await member.save();
            console.log('✅ Updated ClubMember email and linked to User!');

            // 4. Update User role to club-member
            if (user.role === 'user') {
                user.role = 'club-member';
                await user.save();
                console.log('✅ Updated User role to club-member');
            }
        }

        // Also check if there are any other unlinked members with similar names?
        // Ideally we rely on exact email match, but manual fix is sometimes needed.

        mongoose.disconnect();
    } catch (error) {
        console.error('Error:', error);
    }
}

fixShruti();
