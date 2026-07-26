
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
    termYear: {
        type: String, // e.g. "2025-2026"
        default: '2025-2026',
        index: true,
    },
    isCurrent: {
        type: Boolean, // true for active board, false for archived past board
        default: true,
        index: true,
    },
});

// Compound unique index: A student can belong to a club in different academic termYears
clubMemberSchema.index({ clubId: 1, email: 1, termYear: 1 }, { unique: true });

export default mongoose.model('ClubMember', clubMemberSchema);
