import mongoose from 'mongoose';

const clubSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true,
        unique: true,
    },
    slug: {
        type: String,
        unique: true,
        sparse: true, // Allow nulls initially, but migration will fill them
    },
    description: {
        type: String,
        default: '',
    },
    fullForm: {
        type: String,
        required: false,
        default: ''
    },
    whatsappUrl: {
        type: String,
        default: '',
    },
    instagramUrl: {
        type: String,
        default: '',
    },
    linkedinUrl: {
        type: String,
        default: '',
    },
    websiteUrl: {
        type: String,
        default: '',
    },
    image: {
        type: String, // URL
        default: '',
    },
    category: {
        type: String,
        default: 'technical', // Default to technical for existing clubs
        enum: ['technical', 'cultural', 'sports', 'academic', 'other'],
    },
    departments: {
        type: [String],
        enum: [
            'Computer Science(CSE)',
            'Electronics',
            'Mechanical',
            'Civil',
            'Artificial Intelligence and Machine Learning(AIML)',
            'Information Technology(IT)'
        ],
        default: []
    },
    // Officers
    secretaryId: { type: String },
    secretaryEmail: { type: String },
    presidentId: { type: String },
    presidentEmail: { type: String },
    treasurerId: { type: String },
    treasurerEmail: { type: String },
    advisorId: { type: String },
    advisorEmail: { type: String },
    advisorName: { type: String },
    currentTerm: {
        type: String,
        default: '2025-2026',
    },

    members: {
        type: Number,
        default: 0,
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

import slugify from 'slugify';

clubSchema.pre('save', function (next) {
    if (this.isModified('name') || !this.slug) {
        this.slug = slugify(this.name, { lower: true, strict: true });
    }
    next();
});

export default mongoose.model('Club', clubSchema);
