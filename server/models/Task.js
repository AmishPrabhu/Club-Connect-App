import mongoose from 'mongoose';

const taskSchema = new mongoose.Schema({
    title: {
        type: String,
        required: true,
    },
    description: {
        type: String,
        default: '',
    },
    clubId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Club',
        required: true,
    },
    assignedTo: [{
        type: String, // Storing names/emails directly for simplicity as per existing patterns, or could be User IDs
    }],
    assignedToEmails: [{
        type: String,
    }],
    status: {
        type: String,
        enum: ['pending', 'in-progress', 'completed'],
        default: 'pending',
    },
    deadline: {
        type: Date,
    },
    relatedEventId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Post', // Assuming 'Post' is the model name for events
        default: null,
    },
    relatedEventTitle: {
        type: String,
        default: '',
    },
    createdBy: {
        type: String, // Name of the creator
        required: true,
    },
    createdById: {
        type: String, // User ID of the creator
    },
    createdAt: {
        type: Date,
        default: Date.now,
    },
    updatedAt: {
        type: Date,
        default: Date.now,
    },
});

export default mongoose.model('Task', taskSchema);
