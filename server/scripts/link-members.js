// Link all ClubMembers to Users by email
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from '../models/User.js';
import ClubMember from '../models/ClubMember.js';

dotenv.config();

async function linkMembers() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to MongoDB');

        const members = await ClubMember.find({ userId: { $exists: false } }); // or null/empty
        // Actually, let's find all members and check linking
        const allMembers = await ClubMember.find({});
        console.log(`Found ${allMembers.length} club members total.`);

        let updatedCount = 0;

        for (const member of allMembers) {
            if (!member.email) continue;

            // Find user by email (case insensitive)
            const user = await User.findOne({
                email: { $regex: new RegExp(`^${member.email}$`, 'i') }
            });

            if (user) {
                if (member.userId !== user._id.toString()) {
                    console.log(`Linking ${member.name} (${member.email}) to User ID ${user._id}`);
                    member.userId = user._id.toString();

                    // Also update profileImage if available on user but not on member
                    // Actually, we want to rely on the dynamic fetch, but saving it here doesn't hurt as a cache
                    // But importantly: the dynamic fetch in clubs.js relies on userId finding the user!

                    await member.save();
                    updatedCount++;
                }
            } else {
                console.log(`No user found for member: ${member.name} (${member.email})`);
            }
        }

        console.log(`Updated ${updatedCount} members.`);

        // Specifically check Shruti
        const shruti = await ClubMember.findOne({ email: { $regex: /shruti/i } });
        if (shruti) {
            console.log('Shruti Member Record:', {
                name: shruti.name,
                email: shruti.email,
                userId: shruti.userId,
                role: shruti.role
            });
        }

        mongoose.disconnect();
    } catch (error) {
        console.error('Error:', error);
    }
}

linkMembers();
