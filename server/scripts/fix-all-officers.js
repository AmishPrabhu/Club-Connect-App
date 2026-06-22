// Script to fix officer authorization for ALL clubs
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import Club from '../models/Club.js';
import ClubMember from '../models/ClubMember.js';
import User from '../models/User.js';

dotenv.config();

// Helper to escape regex
function escapeRegExp(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

async function fixAllOfficers() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to MongoDB');

        const clubs = await Club.find({});
        console.log(`Found ${clubs.length} clubs. Checking officers...`);

        let fixedCount = 0;
        let createdCount = 0;

        for (const club of clubs) {
            console.log(`\nChecking Club: ${club.name} (${club._id})`);

            // Define officers to check based on Club model fields
            const officersToCheck = [
                { role: 'Secretary', email: club.secretaryEmail, name: 'Secretary' },
                { role: 'President', email: club.presidentEmail, name: 'President' },
                { role: 'Treasurer', email: club.treasurerEmail, name: 'Treasurer' },
                { role: 'Advisor', email: club.advisorEmail, name: club.advisorName || 'Advisor' },
            ];

            for (const officer of officersToCheck) {
                if (!officer.email) {
                    // console.log(`  - No ${officer.role} email listed in Club record.`);
                    continue;
                }

                // Check if ClubMember exists for this officer
                // We use case-insensitive regex for email match
                let member = await ClubMember.findOne({
                    clubId: club._id.toString(),
                    email: { $regex: new RegExp(`^${escapeRegExp(officer.email)}$`, 'i') },
                    role: { $regex: new RegExp(`^${officer.role}$`, 'i') } // fuzzy match role too
                });

                if (!member) {
                    // Record missing! Create it.
                    console.log(`  ❌ Missing ClubMember for ${officer.role}: ${officer.email}. Creating...`);

                    // Check if User exists to link userId
                    const user = await User.findOne({
                        email: { $regex: new RegExp(`^${escapeRegExp(officer.email)}$`, 'i') }
                    });

                    member = new ClubMember({
                        clubId: club._id.toString(),
                        userId: user ? user._id.toString() : undefined,
                        name: officer.name,
                        email: officer.email,
                        role: officer.role,
                        boardType: 'main',
                        joinedAt: new Date(),
                        profileImage: user?.profileImage || ''
                    });

                    await member.save();
                    createdCount++;
                    console.log(`     ✅ Created ClubMember record.`);
                } else {
                    // Record exists, but maybe userId is missing?
                    let updated = false;

                    if (!member.userId) {
                        const user = await User.findOne({
                            email: { $regex: new RegExp(`^${escapeRegExp(officer.email)}$`, 'i') }
                        });

                        if (user) {
                            member.userId = user._id.toString();
                            member.profileImage = user.profileImage || member.profileImage || '';
                            updated = true;
                            console.log(`  ⚠️ Linked existing ${officer.role} to User ID: ${user._id}`);
                        }
                    }

                    // Ensure role matches exactly (case sensitive normalization)
                    if (member.role !== officer.role) {
                        member.role = officer.role;
                        updated = true;
                        console.log(`  ⚠️ Fixed role casing: ${member.role} -> ${officer.role}`);
                    }

                    if (updated) {
                        await member.save();
                        fixedCount++;
                    } else {
                        console.log(`  ✅ ${officer.role} matches.`);
                    }
                }
            }

            // Update members count just in case
            const count = await ClubMember.countDocuments({ clubId: club._id.toString() });
            if (club.members !== count) {
                console.log(`  Updating member count: ${club.members} -> ${count}`);
                club.members = count;
                await club.save();
            }
        }

        console.log(`\nSummary:`);
        console.log(`- Created ${createdCount} missing officer records.`);
        console.log(`- Fixed/Linked ${fixedCount} existing records.`);
        console.log(`Done.`);

        mongoose.disconnect();
    } catch (error) {
        console.error('Error:', error);
    }
}

fixAllOfficers();
