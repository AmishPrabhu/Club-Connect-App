import mongoose from 'mongoose';

const eventInterestSchema = new mongoose.Schema({
    eventId: {
        type: String,
        required: true,
        index: true,
    },
    userId: {
        type: String,
        required: true,
    },
    email: {
        type: String,
        required: true,
    },
    name: {
        type: String,
        required: true,
    },
    interestedAt: {
        type: Date,
        default: Date.now,
    },
});

// Prevent duplicate interests: one user per event
eventInterestSchema.index({ eventId: 1, userId: 1 }, { unique: true });

export default mongoose.model('EventInterest', eventInterestSchema);
