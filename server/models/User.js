import mongoose from 'mongoose';

const userSchema = new mongoose.Schema({
    email: {
        type: String,
        required: true,
        unique: true,
        trim: true,
        lowercase: true,
    },
    password: {
        type: String,
        required: false, // Optional for Google OAuth users
    },
    name: {
        type: String,
        required: true,
    },
    authProvider: {
        type: String,
        enum: ['local', 'google'],
        default: 'local',
    },
    role: {
        type: String,
        enum: ['user', 'club-member', 'admin', 'secretary', 'president', 'treasurer', 'advisor', 'club-secretary', 'student', 'cabinet-member', 'teacher'],
        default: 'user',
    },
    managedClubs: [{
        type: String, // Club IDs that teachers manage/monitor
    }],
    clubId: {
        type: String,
        default: null,
    },
    clubName: {
        type: String,
        default: null,
    },
    bio: {
        type: String,
        default: '',
    },
    profileImage: {
        type: String,
        default: '',
    },
    likedClubs: [{
        type: String, // Club IDs
    }],
    createdAt: {
        type: Date,
        default: Date.now,
    },
    updatedAt: {
        type: Date,
        default: Date.now,
    },
    resetPasswordToken: {
        type: String,
        default: null,
    },
    resetPasswordExpires: {
        type: Date,
        default: null,
    },
    roles: [{
        type: String,
        enum: ['user', 'club-member', 'admin', 'secretary', 'president', 'treasurer', 'advisor', 'club-secretary', 'student', 'cabinet-member', 'teacher'],
    }]
});

// Helper method to check if user has a specific role
userSchema.methods.hasRole = function (roleName) {
    if (this.roles && this.roles.length > 0) {
        return this.roles.includes(roleName);
    }
    // Fallback to single role field for backward compatibility
    return this.role === roleName;
};

export default mongoose.model('User', userSchema);
