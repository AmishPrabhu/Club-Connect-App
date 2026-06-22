
import mongoose from 'mongoose';

const clubMessageSchema = new mongoose.Schema({
    clubId: {
        type: String,
        required: true,
        index: true,
    },
    clubName: { // Denormalized for easier display if needed
        type: String,
        required: true,
    },
    senderId: {
        type: String,
        required: true,
    },
    senderName: {
        type: String,
        required: true,
    },
    senderRole: {
        type: String,
        required: true,
    },
    title: {
        type: String,
        required: true,
    },
    body: {
        type: String,
        required: true,
    },
    createdAt: {
        type: Date,
        default: Date.now,
    },
});

export default mongoose.model('ClubMessage', clubMessageSchema);
