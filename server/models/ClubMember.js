
import mongoose from 'mongoose';

const clubMemberSchema = new mongoose.Schema({
    clubId: {
        type: String, // ID of the Club
        required: true,
        index: true,
    },
    userId: {
        type: String, // Optional, if linked to a registered User
    },
    name: {
        type: String,
        required: true,
    },
    email: {
        type: String,
        required: true,
    },
    role: {
        type: String, // Custom role (e.g., "President", "App Executive", "Member")
        default: 'Member',
    },
    boardType: {
        type: String,
        enum: ['main', 'executive', 'member'], // Main Board (TY), Executive Board (SY), Member Board (FY)
        default: 'member',
    },
    academicYear: {
        type: String, // e.g. "FY", "SY", "TY", "Final Year"
        default: '',
    },
    profileImage: {
        type: String, // Profile picture URL
        default: '',
    },
    joinedAt: {
        type: Date,
        default: Date.now,
    },
});

// Prevent duplicate email in same club
clubMemberSchema.index({ clubId: 1, email: 1 }, { unique: true });

export default mongoose.model('ClubMember', clubMemberSchema);
