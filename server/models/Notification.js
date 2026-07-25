import mongoose from 'mongoose';

const notificationSchema = new mongoose.Schema({
    title: {
        type: String,
        required: true,
    },
    message: {
        type: String,
        required: true,
    },
    userId: {
        type: String, // If null, global notification
        default: null,
    },
    read: {
        type: Boolean,
        default: false,
    },
    readBy: [{
        type: String,
        default: [],
    }],
    type: {
        type: String, // 'info', 'warning', 'success', 'event', 'announcement'
        default: 'info',
    },
    clubId: {
        type: String,
        default: null
    },
    relatedId: { // ID of the related Event/Post
        type: String,
        default: null
    },
    createdAt: {
        type: Date,
        default: Date.now,
    },
});

export default mongoose.model('Notification', notificationSchema);
