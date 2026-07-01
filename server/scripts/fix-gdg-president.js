// Script to add president for GDG club with correct email
import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

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

const UserSchema = new mongoose.Schema({
    email: String,
    name: String,
    role: String,
});

const ClubMember = mongoose.model('ClubMember', ClubMemberSchema);
const User = mongoose.model('User', UserSchema);

async function main() {
    try {
        await mongoose.connect(MONGODB_URI);
        console.log('Connected to MongoDB');

        // Find the user with email test@gmail.com (the one trying to login as president)
        const user = await User.findOne({ email: 'test@gmail.com' });
        console.log('User found:', user ? { id: user._id, name: user.name, email: user.email } : 'NOT FOUND');

        // The GDG club ID from the debug log
        const gdgClubId = '696800e5b85566e533cbbbb3';

        // Check if there's already a president for this club
        const existingPresident = await ClubMember.findOne({
            clubId: gdgClubId,
            role: { $in: ['President', 'president'] }
        });
        console.log('Existing president for GDG:', existingPresident ? existingPresident.email : 'NONE');

        if (!existingPresident && user) {
            // Add this user as president of GDG
            const newPresident = new ClubMember({
                clubId: gdgClubId,
                userId: user._id.toString(),
                name: user.name || 'President',
                email: 'test@gmail.com',
                role: 'President',
                boardType: 'main',
                joinedAt: new Date()
            });
            await newPresident.save();
            console.log('✅ Added test@gmail.com as President of GDG club!');
        } else if (existingPresident) {
            // Update existing president's email to match the login
            existingPresident.email = 'test@gmail.com';
            if (user) existingPresident.userId = user._id.toString();
            await existingPresident.save();
            console.log('✅ Updated existing president email to test@gmail.com!');
        }

        mongoose.disconnect();
    } catch (error) {
        console.error('Error:', error);
    }
}

main();
