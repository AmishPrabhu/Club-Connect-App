// Script to fix GDG officers correctly
import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

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

async function fix() {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');

    const gdgClubId = '696800e5b85566e533cbbbb3';

    // Update test@gmail.com to be Secretary instead of President
    const updateResult = await ClubMember.updateOne(
        { clubId: gdgClubId, email: 'test@gmail.com' },
        { $set: { role: 'Secretary' } }
    );
    console.log('Updated test@gmail.com to Secretary:', updateResult.modifiedCount > 0 ? 'SUCCESS' : 'Not found');

    // Check if gdgpresident@gmail.com exists for this club
    const existing = await ClubMember.findOne({ clubId: gdgClubId, email: 'gdgpresident@gmail.com' });
    if (!existing) {
        await ClubMember.create({
            clubId: gdgClubId,
            name: 'GDG President',
            email: 'gdgpresident@gmail.com',
            role: 'President',
            boardType: 'main',
            joinedAt: new Date()
        });
        console.log('✅ Added gdgpresident@gmail.com as President');
    } else {
        console.log('President already exists:', existing.email);
    }

    // Show all officers for GDG
    const officers = await ClubMember.find({
        clubId: gdgClubId,
        role: { $in: ['President', 'Secretary', 'Treasurer', 'Advisor'] }
    });
    console.log('\n=== GDG Officers ===');
    officers.forEach(o => console.log(`  ${o.role}: ${o.email}`));

    mongoose.disconnect();
}

fix();
