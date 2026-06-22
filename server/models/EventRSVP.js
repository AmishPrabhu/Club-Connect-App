
import mongoose from 'mongoose';

const eventRSVPSchema = new mongoose.Schema({
    eventId: {
        type: String, // ID of the Post (Event)
        required: true,
        index: true,
    },
    userId: {
        type: String, // Optional, if user is logged in
    },
    name: {
        type: String,
        required: true,
    },
    email: {
        type: String,
        required: true,
    },
    // Per-session attendance: keys are session numbers ("1", "2", etc.), values are status
    sessionAttendance: {
        type: Map,
        of: {
            type: String,
            enum: ['present', 'absent', 'pending'],
        },
        default: () => new Map([['1', 'pending']]),
    },
    certificateUrl: {
        type: String, // URL of generated certificate for this participant
        default: null,
    },
    rsvpedAt: {
        type: Date,
        default: Date.now,
    },
    source: {
        type: String,
        enum: ['rsvp', 'import', 'manual'],
        default: 'rsvp',
    },

});

// Virtual 'attendance' field: computes overall attendance from sessionAttendance
// Returns 'present' only if ALL sessions are 'present'
// Returns 'absent' if any session is 'absent'
// Otherwise returns 'pending'
eventRSVPSchema.virtual('attendance').get(function () {
    if (!this.sessionAttendance || this.sessionAttendance.size === 0) return 'pending';
    const values = Array.from(this.sessionAttendance.values());
    if (values.every(v => v === 'present')) return 'present';
    if (values.some(v => v === 'absent')) return 'absent';
    return 'pending';
});

// Ensure virtuals are included when converting to JSON/Object
eventRSVPSchema.set('toJSON', { virtuals: true });
eventRSVPSchema.set('toObject', { virtuals: true });

// Compound index to prevent duplicate RSVPs for same email on same event
eventRSVPSchema.index({ eventId: 1, email: 1 }, { unique: true });

export default mongoose.model('EventRSVP', eventRSVPSchema);
