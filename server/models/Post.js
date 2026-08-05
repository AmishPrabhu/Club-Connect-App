import mongoose from 'mongoose';

const attachmentSchema = new mongoose.Schema({
    url: { type: String, required: true },
    publicId: { type: String },
    type: { type: String, enum: ['image', 'video', 'pdf', 'link'], default: 'image' },
    label: { type: String },
}, { _id: false });

const postSchema = new mongoose.Schema({
    title: {
        type: String,
        required: true,
    },
    content: { // Description or body
        type: String,
        required: true,
    },
    image: {
        type: String, // URL
        default: '',
    },
    coverImage: { // Alias for image, or used optionally
        type: String,
        default: '',
    },
    type: {
        type: String,
        enum: ['event', 'announcement', 'post', 'service'],
        default: 'post',
    },
    visibility: {
        type: String,
        enum: ['public', 'private'],
        default: 'public',
    },
    status: {
        type: String,
        enum: ['draft', 'published'],
        default: 'published',
    },
    // Relating to Club
    clubId: {
        type: String, // Can be ObjectId if strictly relational, but keeping string to match existing logic
        required: true,
    },
    clubName: {
        type: String,
        required: true,
    },
    clubImage: {
        type: String,
    },

    // Author info
    authorId: {
        type: String,
    },
    authorName: {
        type: String,
    },

    // Event specific fields
    date: {
        type: String, // Storing as string YYYY-MM-DD or similar based on frontend usage
    },
    time: {
        type: String, // "2:30 PM - 5:00 PM"
    },
    timeFrom: {
        type: String,
    },
    timeTo: {
        type: String,
    },
    location: {
        type: String,
    },
    locationType: {
        type: String,
        enum: ['campus', 'external'],
        default: 'campus',
    },
    locationUrl: {
        type: String, // Google Maps URL for external locations
    },

    // Registration fields
    registrationStart: {
        type: String, // YYYY-MM-DD
    },
    registrationStartTime: {
        type: String, // "10:00 AM"
    },
    registrationEnd: {
        type: String, // YYYY-MM-DD
    },
    registrationEndTime: {
        type: String, // "5:00 PM"
    },
    registrationLink: {
        type: String, // URL to registration form (Google Forms, etc.)
    },
    responseSpreadsheetUrl: {
        type: String, // Google Sheets URL for form responses
    },
    eventWhatsappLink: {
        type: String, // WhatsApp group link for the event
    },

    // Session tracking for events
    totalSessions: {
        type: Number,
        default: 1,
        min: 1,
    },

    // Related event for announcements
    relatedEventId: {
        type: String,
    },
    relatedEventTitle: {
        type: String,
    },

    // Attachments
    attachments: [attachmentSchema], // Description images (uploaded when creating post)
    descriptionImages: {
        type: [String],
        default: [],
    },
    eventPhotos: [attachmentSchema], // Event photos/videos (uploaded after event by secretary)



    // Stats
    likes: {
        type: Number,
        default: 0,
    },
    rsvps: {
        type: Number,
        default: 0,
    },

    // Budget fields (for events)
    budgetImage: {
        type: String, // URL of uploaded budget file/image
        default: null,
    },
    budgetVerified: {
        type: Boolean,
        default: false,
    },
    budgetVerifiedBy: {
        type: String, // User ID of advisor who verified
        default: null,
    },
    budgetVerifiedAt: {
        type: Date,
        default: null,
    },

    // Certificate generation fields (for events)
    certificateTemplate: {
        templateUrl: { type: String, default: null }, // Cloudinary URL of certificate template
        namePosition: {
            x: { type: Number, default: 50 }, // X position (percentage)
            y: { type: Number, default: 50 }, // Y position (percentage)
            fontSize: { type: Number, default: 48 },
            fontFamily: { type: String, default: 'Arial' },
            color: { type: String, default: '#000000' },
        },
    },

    // Event report fields
    reportUrl: {
        type: String, // URL of uploaded report document/PDF
        default: null,
    },
    reportFilename: {
        type: String,
        default: null,
    },
    reportSubmittedBy: {
        type: String, // User ID of officer who submitted report
        default: null,
    },
    reportSubmittedByName: {
        type: String, // Name of officer who submitted report
        default: null,
    },
    reportSubmittedAt: {
        type: Date,
        default: null,
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

export default mongoose.model('Post', postSchema);

