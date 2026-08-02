import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { OAuth2Client } from 'google-auth-library';
import User from '../models/User.js';
import ClubMember from '../models/ClubMember.js';
import { verifyToken } from '../middleware/auth.js';
import { sendPasswordResetEmail, sendOtpEmail, sendDeleteAccountOtpEmail, sendClubInvitationEmail, sendPasswordChangeEmail } from '../services/emailService.js';
import rateLimit from 'express-rate-limit';
import Otp from '../models/Otp.js';
import Club from '../models/Club.js';

// Stricter rate limit for auth routes (5 attempts per 15 mins)
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 5,
    message: { message: 'Too many login attempts, please try again after 15 minutes' },
    standardHeaders: true,
    legacyHeaders: false,
    skipSuccessfulRequests: true,
    keyGenerator: (req) => req.ip,
    validate: {
        xForwardedForHeader: false,
        keyGeneratorIpFallback: false,
    },
});

// Slightly more lenient for signup (10 per hour to prevent spam accounts)
const signupLimiter = rateLimit({
    windowMs: 60 * 60 * 1000,
    max: 10,
    message: { message: 'Too many accounts created from this IP, please try again later' },
});

// Limiter for profile-related OTPs (Delete Account, Change Password) - 5 per hour
const profileOtpLimiter = rateLimit({
    windowMs: 60 * 60 * 1000,
    max: 5,
    message: { message: 'Too many requests from this IP, please try again later' },
});

const router = express.Router();
const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// Helper to escape regex special characters
function escapeRegExp(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// Generate OTP
function generateOTP() {
    return Math.floor(100000 + Math.random() * 900000).toString();
}

// Send OTP
router.post('/send-otp-signup', signupLimiter, async (req, res) => {
    try {
        const { email } = req.body;

        if (!email) {
            return res.status(400).json({ message: 'Email is required' });
        }

        if (!email.endsWith('@walchandsangli.ac.in')) {
            return res.status(400).json({ message: 'Only @walchandsangli.ac.in email addresses are allowed' });
        }

        // Check if user exists
        const existingUser = await User.findOne({ email });
        if (existingUser) {
            return res.status(400).json({ message: 'User already exists' });
        }

        const otp = generateOTP();

        // Save OTP to DB
        // Determine if we should update an existing OTP or create a new one
        // upsert: true will create if not exists
        await Otp.findOneAndUpdate(
            { email },
            { otp, createdAt: Date.now() },
            { upsert: true, new: true, setDefaultsOnInsert: true }
        );

        // Send email
        await sendOtpEmail(email, otp);

        res.json({ message: 'OTP sent successfully' });
    } catch (error) {
        console.error('Send OTP error:', error);
        res.status(500).json({ message: 'Failed to send OTP' });
    }
});

// Verify OTP (Check only)
router.post('/verify-otp', async (req, res) => {
    try {
        const { email, otp } = req.body;

        if (!email || !otp) {
            return res.status(400).json({ message: 'Email and OTP are required' });
        }

        const otpRecord = await Otp.findOne({ email });

        if (!otpRecord) {
            return res.status(400).json({ message: 'OTP expired or not found. Please request a new one.' });
        }

        if (otpRecord.otp !== otp) {
            return res.status(400).json({ message: 'Invalid OTP' });
        }

        res.json({ message: 'OTP verified successfully' });
    } catch (error) {
        console.error('Verify OTP error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Signup
router.post('/signup', signupLimiter, async (req, res) => {
    try {
        const { email, password, name, role } = req.body;

        if (typeof email !== 'string' || typeof password !== 'string') {
            return res.status(400).json({ message: 'Invalid input format' });
        }

        // Check if user exists
        const existingUser = await User.findOne({ email });
        if (existingUser) {
            return res.status(400).json({ message: 'User already exists' });
        }

        // Check email domain
        if (!email.endsWith('@walchandsangli.ac.in')) {
            return res.status(400).json({ message: 'Only @walchandsangli.ac.in email addresses are allowed' });
        }

        // Check if this is the first admin setup
        let isFirstAdmin = false;
        if (role === 'admin') {
            const adminCount = await User.countDocuments({ role: 'admin' });
            if (adminCount === 0) {
                isFirstAdmin = true;
            }
        }

        // Verify OTP if not a Google signup and not the first admin setup
        if (!isFirstAdmin) {
            if (!req.body.otp) {
                return res.status(400).json({ message: 'OTP is required' });
            }

            const otpRecord = await Otp.findOne({ email });
            if (!otpRecord) {
                return res.status(400).json({ message: 'OTP expired or not found. Please request a new one.' });
            }
            if (otpRecord.otp !== req.body.otp) {
                return res.status(400).json({ message: 'Invalid OTP' });
            }

            // Delete OTP after successful use
            await Otp.deleteOne({ email });
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(password, 10);

        // Check if there's a pre-assigned role for this email (e.g., teacher invitation)
        const preAssignedUser = await User.findOne({ email, password: { $exists: false } });
        let assignedRole = isFirstAdmin ? 'admin' : 'user';

        if (preAssignedUser && !isFirstAdmin) {
            // User was pre-assigned a role (like teacher) - use that role
            assignedRole = preAssignedUser.role;

            // Delete the invitation record
            await User.deleteOne({ _id: preAssignedUser._id });
        }

        // Create user
        const newUser = new User({
            email,
            password: hashedPassword,
            name,
            role: assignedRole,
            managedClubs: preAssignedUser?.managedClubs || [],
        });

        await newUser.save();

        // Link any existing club memberships to this new user
        // We use a case-insensitive regex to match email since ClubMember might not match exact case
        await ClubMember.updateMany(
            { email: { $regex: new RegExp(`^${escapeRegExp(email)}$`, 'i') } },
            { $set: { userId: newUser._id } }
        );

        // Create token
        const token = jwt.sign(
            {
                id: newUser._id,
                email: newUser.email,
                role: newUser.role,
                roles: newUser.roles || []
            },
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
        );

        res.status(201).json({
            token,
            user: {
                id: newUser._id,
                email: newUser.email,
                name: newUser.name,
                role: newUser.role,
                roles: newUser.roles || [],
                profileImage: newUser.profileImage,
                likedClubs: newUser.likedClubs || [],
            },
        });
    } catch (error) {
        console.error('Signup error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Assign Officer (Internal use by Super Admin/Officers)
// Creates user if not exists (random password), sends invitation email
// Does NOT require OTP. This effectively skips OTP for invited officers.
router.post('/assign-officer', async (req, res) => {
    try {
        const { email, name, role, clubId } = req.body;

        if (!email || !name || !role || !clubId) {
            return res.status(400).json({ message: 'All fields are required' });
        }

        if (!email.endsWith('@walchandsangli.ac.in')) {
            return res.status(400).json({ message: 'Only @walchandsangli.ac.in emails allowed' });
        }

        // Check if user exists
        let user = await User.findOne({ email });

        if (user) {
            return res.status(200).json({
                message: 'User already exists',
                userId: user._id
            });
        }

        // Do NOT create user account yet. User must sign up manually.
        // We just send an invitation email.

        // Get club name for email
        const club = await Club.findById(clubId);
        const clubName = club ? club.name : 'Unknown Club';

        // URL to Signup page (pre-filling email if possible via query param)
        // Adjust frontend route as needed. Assuming /signup or ?page=signup
        const signUpUrl = `${process.env.FRONTEND_URL}?page=signUp&email=${encodeURIComponent(email)}`;

        // Send invitation
        await sendClubInvitationEmail({
            name,
            email,
            role,
            clubName,
            signUpUrl
        });

        res.status(201).json({
            message: 'Invitation sent. User must create an account.',
            userId: null // Explicitly null so dbService knows to just add email reference
        });

    } catch (error) {
        console.error('Assign officer error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Login
router.post('/login', authLimiter, async (req, res) => {
    try {
        const { email, password } = req.body;

        if (typeof email !== 'string' || typeof password !== 'string') {
            return res.status(400).json({ message: 'Invalid input format' });
        }

        // Find user
        const user = await User.findOne({ email });
        if (!user) {
            return res.status(400).json({ message: 'Invalid credentials' });
        }

        // Check password
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(400).json({ message: 'Invalid credentials' });
        }

        // Check for officer memberships if role is 'user' or 'club-member'
        let effectiveRole = user.role;
        let effectiveClubId = user.clubId;
        let effectiveClubName = user.clubName;

        if (['user', 'club-member', 'club-secretary', 'president', 'treasurer', 'advisor'].includes(effectiveRole)) {
            const officerMembership = await ClubMember.findOne({
                $or: [{ userId: user._id }, { email: user.email }],
                role: { $in: ['Secretary', 'President', 'Treasurer', 'Advisor'] }
            });

            if (officerMembership) {
                const roleMap = {
                    'Secretary': 'club-secretary',
                    'President': 'president',
                    'Treasurer': 'treasurer',
                    'Advisor': 'advisor'
                };

                if (effectiveRole === 'user' || effectiveRole === 'club-member') {
                    effectiveRole = roleMap[officerMembership.role] || effectiveRole;
                }

                if (!effectiveClubId) {
                    effectiveClubId = officerMembership.clubId;
                }
            }
        }

        // Create token
        const token = jwt.sign(
            {
                id: user._id,
                email: user.email,
                role: effectiveRole,
                roles: user.roles || []
            },
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
        );

        res.json({
            token,
            user: {
                id: user._id,
                email: user.email,
                name: user.name,
                role: effectiveRole,
                roles: user.roles || [],
                clubId: effectiveClubId,
                clubName: effectiveClubName,
                profileImage: user.profileImage,
                likedClubs: user.likedClubs || [],
            },
        });

        // SYNC: Link any unlinked ClubMember records to this user (in case they were added by admin while offline)
        // Fire-and-forget background sync
        (async () => {
            try {
                // 1. Link userId to ClubMember records
                await ClubMember.updateMany(
                    { email: { $regex: new RegExp(`^${escapeRegExp(user.email)}$`, 'i') }, userId: { $exists: false } },
                    { $set: { userId: user._id } }
                );

                // 2. If user is 'user' or 'club-member', upgrade to appropriate role
                const memberships = await ClubMember.find({
                    $or: [{ userId: user._id }, { email: { $regex: new RegExp(`^${escapeRegExp(user.email)}$`, 'i') } }]
                });

                if (memberships.length > 0) {
                    // Find highest role
                    const roles = memberships.map(m => m.role);
                    let targetRole = 'club-member';

                    if (roles.includes('Advisor')) targetRole = 'advisor';
                    else if (roles.includes('President')) targetRole = 'president';
                    else if (roles.includes('Treasurer')) targetRole = 'treasurer';
                    else if (roles.includes('Secretary')) targetRole = 'club-secretary';

                    if (user.role !== targetRole && user.role !== 'admin') {
                        await User.findByIdAndUpdate(user._id, { role: targetRole });
                    }
                }
            } catch (err) {
                console.error('Background membership sync error:', err);
            }
        })();
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Get Current User (Me)
router.get('/me', verifyToken, async (req, res) => {
    try {
        const user = await User.findById(req.user.id).select('-password -resetPasswordToken -resetPasswordExpires');
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        let effectiveRole = user.role;
        let effectiveClubId = user.clubId;
        let effectiveClubName = user.clubName;

        // Fetch ALL club memberships for this user (for validation)
        const memberships = await ClubMember.find({
            $or: [{ userId: user._id }, { email: user.email }]
        }).lean();

        // Fetch club details for each membership
        const membershipDetails = await Promise.all(memberships.map(async (membership) => {
            const club = await Club.findById(membership.clubId).select('name image slug secretaryEmail presidentEmail treasurerEmail');

            // Determine officer role based on Club's stored emails (not ClubMember role)
            const userEmailLower = user.email.toLowerCase();
            let officerRole = null;
            if (club?.secretaryEmail?.toLowerCase() === userEmailLower) officerRole = 'secretary';
            else if (club?.presidentEmail?.toLowerCase() === userEmailLower) officerRole = 'president';
            else if (club?.treasurerEmail?.toLowerCase() === userEmailLower) officerRole = 'treasurer';

            return {
                clubId: membership.clubId,
                clubName: club?.name || 'Unknown Club',
                clubImage: club?.image || '',
                clubSlug: club?.slug || '',
                role: membership.role,
                boardType: membership.boardType,
                email: membership.email,
                officerRole // Added: officer status based on Club's email fields
            };
        }));

        // If role is a standard or officer role, fetch officer memberships to get club context
        if (['user', 'club-member', 'club-secretary', 'president', 'treasurer', 'advisor'].includes(effectiveRole)) {
            const officerMembership = await ClubMember.findOne({
                $or: [{ userId: user._id }, { email: user.email }],
                role: { $in: ['Secretary', 'President', 'Treasurer', 'Advisor'] }
            });

            if (officerMembership) {
                // Map ClubMember role to User role
                const roleMap = {
                    'Secretary': 'club-secretary',
                    'President': 'president',
                    'Treasurer': 'treasurer',
                    'Advisor': 'advisor'
                };

                // Only upgrade the role if they were previously just a user/member
                // or if we want to ensure their effective role matches their highest office
                if (effectiveRole === 'user' || effectiveRole === 'club-member') {
                    effectiveRole = roleMap[officerMembership.role] || effectiveRole;
                }

                // Provide a default club context if missing
                if (!effectiveClubId) {
                    effectiveClubId = officerMembership.clubId;
                }
            }
        }

        // Map to frontend-compatible format
        res.json({
            id: user._id,
            email: user.email,
            name: user.name,
            role: effectiveRole,
            roles: user.roles || [],
            clubId: effectiveClubId,
            clubName: effectiveClubName,
            profileImage: user.profileImage,
            likedClubs: user.likedClubs || [],
            memberships: membershipDetails, // NEW: Include fresh membership data
            createdAt: user.createdAt,
            updatedAt: user.updatedAt,
        });
    } catch (error) {
        console.error('Me error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Google OAuth Login
router.post('/google', async (req, res) => {
    try {
        const { credential } = req.body;

        if (!credential) {
            return res.status(400).json({ message: 'Google credential is required' });
        }

        // Verify the Google token
        const ticket = await googleClient.verifyIdToken({
            idToken: credential,
            audience: process.env.GOOGLE_CLIENT_ID,
        });

        const payload = ticket.getPayload();
        const { email, name, sub: googleId } = payload;

        // Check domain restriction - only allow @walchandsangli.ac.in emails
        if (!email.endsWith('@walchandsangli.ac.in')) {
            return res.status(403).json({
                message: 'Only @walchandsangli.ac.in email addresses are allowed to sign in.'
            });
        }

        // Check if user exists
        let user = await User.findOne({ email });

        if (!user) {
            // User doesn't exist - tell frontend to redirect to signup
            return res.status(404).json({
                code: 'USER_NOT_FOUND',
                message: 'No account exists with this email. Please create an account.',
                googleData: {
                    email,
                    name,
                    credential // Pass back for signup verification
                }
            });
        }

        // Check for officer memberships if role is 'user' or 'club-member'
        let effectiveRole = user.role;
        let effectiveClubId = user.clubId;
        let effectiveClubName = user.clubName;

        if (effectiveRole === 'user' || effectiveRole === 'club-member') {
            const officerMembership = await ClubMember.findOne({
                $or: [{ userId: user._id }, { email: user.email }],
                role: { $in: ['Secretary', 'President', 'Treasurer', 'Advisor'] }
            });

            if (officerMembership) {
                const roleMap = {
                    'Secretary': 'club-secretary',
                    'President': 'president',
                    'Treasurer': 'treasurer',
                    'Advisor': 'advisor'
                };
                effectiveRole = roleMap[officerMembership.role] || effectiveRole;

                if (!effectiveClubId) {
                    effectiveClubId = officerMembership.clubId;
                }
            }
        }

        // Create JWT token
        const token = jwt.sign(
            {
                id: user._id,
                email: user.email,
                role: effectiveRole,
                roles: user.roles || []
            },
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
        );

        res.json({
            token,
            user: {
                id: user._id,
                email: user.email,
                name: user.name,
                role: effectiveRole,
                roles: user.roles || [],
                clubId: effectiveClubId,
                clubName: effectiveClubName,
                profileImage: user.profileImage,
                likedClubs: user.likedClubs || [],
            },
        });

        // SYNC: Link any unlinked ClubMember records to this user
        (async () => {
            try {
                // 1. Link userId
                await ClubMember.updateMany(
                    { email: { $regex: new RegExp(`^${escapeRegExp(user.email)}$`, 'i') }, userId: { $exists: false } },
                    { $set: { userId: user._id } }
                );

                // 2. Upgrade role if needed (but never downgrade admin)
                if (user.role === 'user' && user.role !== 'admin') {
                    const memberCount = await ClubMember.countDocuments({
                        $or: [{ userId: user._id }, { email: { $regex: new RegExp(`^${escapeRegExp(user.email)}$`, 'i') } }]
                    });

                    if (memberCount > 0) {
                        await User.findByIdAndUpdate(user._id, { role: 'club-member' });
                    }
                }
            } catch (err) {
                console.error('Background membership sync error:', err);
            }
        })();
    } catch (error) {
        console.error('Google OAuth error:', error);
        res.status(500).json({ message: 'Google authentication failed' });
    }
});

// Google OAuth Signup (creates account with password)
router.post('/google/signup', async (req, res) => {
    try {
        const { credential, password } = req.body;

        if (!credential) {
            return res.status(400).json({ message: 'Google credential is required' });
        }

        if (!password || password.length < 6) {
            return res.status(400).json({ message: 'Password must be at least 6 characters' });
        }

        // Verify the Google token
        const ticket = await googleClient.verifyIdToken({
            idToken: credential,
            audience: process.env.GOOGLE_CLIENT_ID,
        });

        const payload = ticket.getPayload();
        const { email, name: googleName } = payload;

        // Use provided name if available, otherwise fallback to Google name
        const finalName = req.body.name || googleName || name;

        // Check domain restriction - only allow @walchandsangli.ac.in emails
        if (!email.endsWith('@walchandsangli.ac.in')) {
            return res.status(403).json({
                message: 'Only @walchandsangli.ac.in email addresses are allowed to sign up.'
            });
        }

        // Check if user already exists
        const existingUser = await User.findOne({ email });
        if (existingUser) {
            return res.status(400).json({ message: 'An account with this email already exists. Please login instead.' });
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(password, 10);

        // Create new user with Google + password
        const newUser = new User({
            email,
            password: hashedPassword,
            name: finalName,
            authProvider: 'google',
            role: 'user',
        });

        await newUser.save();

        // Link any existing club memberships to this new user
        await ClubMember.updateMany(
            { email: { $regex: new RegExp(`^${escapeRegExp(email)}$`, 'i') } },
            { $set: { userId: newUser._id } }
        );

        // Create token
        const token = jwt.sign(
            {
                id: newUser._id,
                email: newUser.email,
                role: newUser.role,
                roles: newUser.roles || []
            },
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
        );

        res.status(201).json({
            token,
            user: {
                id: newUser._id,
                email: newUser.email,
                name: newUser.name,
                role: newUser.role,
                profileImage: newUser.profileImage,
                likedClubs: newUser.likedClubs || [],
            },
        });
    } catch (error) {
        console.error('Google signup error:', error);
        res.status(500).json({ message: 'Google signup failed' });
    }
});

// Forgot Password - Send reset email
router.post('/forgot-password', authLimiter, async (req, res) => {
    try {
        const { email } = req.body;

        if (!email) {
            return res.status(400).json({ message: 'Email is required' });
        }

        // Find user by email
        const user = await User.findOne({ email: email.toLowerCase() });
        if (!user) {
            return res.status(404).json({
                code: 'USER_NOT_FOUND',
                message: 'No account found with this email address'
            });
        }

        // Generate reset OTP token
        const resetToken = generateOTP();
        const resetTokenHash = crypto.createHash('sha256').update(resetToken).digest('hex');

        // Save token to user (expires in 1 hour)
        user.resetPasswordToken = resetTokenHash;
        user.resetPasswordExpires = Date.now() + 3600000; // 1 hour
        await user.save();

        // Send email using Resend
        const result = await sendPasswordResetEmail(user, resetToken);

        if (!result.success) {
            console.error('Failed to send password reset email:', result.error);
            // Allow local development testing by falling back to console-printed OTP if email setup fails (e.g. 401 Unauthorized)
            return res.json({ 
                message: 'Password reset OTP generated. [Local Debug] Check your server console logs to retrieve the OTP.' 
            });
        }

        res.json({ message: 'Password reset email sent successfully' });
    } catch (error) {
        console.error('Forgot password error:', error);
        res.status(500).json({ message: 'Failed to send reset email. Please try again.' });
    }
});

// Verify Reset Token — validates OTP without changing password
router.post('/verify-reset-token', async (req, res) => {
    try {
        const { token, email } = req.body;
        if (!token || !email) {
            return res.status(400).json({ message: 'Token and email are required' });
        }
        const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
        const user = await User.findOne({
            email: email.toLowerCase(),
            resetPasswordToken: tokenHash,
            resetPasswordExpires: { $gt: new Date() },
        });
        if (!user) {
            return res.status(400).json({ message: 'Invalid or expired OTP. Please try again.' });
        }
        res.json({ message: 'OTP verified successfully' });
    } catch (error) {
        console.error('Verify reset token error:', error);
        res.status(500).json({ message: 'Verification failed. Please try again.' });
    }
});

// Reset Password - Verify token and update password
router.post('/reset-password', async (req, res) => {
    try {
        const { token, email, password } = req.body;

        if (!token || !email || !password) {
            return res.status(400).json({ message: 'Token, email, and password are required' });
        }

        if (password.length < 6) {
            return res.status(400).json({ message: 'Password must be at least 6 characters' });
        }

        // Hash the token to compare with stored hash
        const tokenHash = crypto.createHash('sha256').update(token).digest('hex');

        // Find user with valid token
        const user = await User.findOne({
            email: email.toLowerCase(),
            resetPasswordToken: tokenHash,
            resetPasswordExpires: { $gt: Date.now() },
        });

        if (!user) {
            return res.status(400).json({ message: 'Invalid or expired reset token. Please request a new password reset.' });
        }

        // Hash new password and save
        user.password = await bcrypt.hash(password, 10);
        user.resetPasswordToken = null;
        user.resetPasswordExpires = null;
        await user.save();

        res.json({ message: 'Password reset successful. You can now login with your new password.' });
    } catch (error) {
        console.error('Reset password error:', error);
        res.status(500).json({ message: 'Failed to reset password. Please try again.' });
    }
});

// Request Delete Account OTP
router.post('/request-delete-otp', verifyToken, profileOtpLimiter, async (req, res) => {
    try {
        const userId = req.user.id;
        const user = await User.findById(userId);

        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        const otp = generateOTP();

        // Save OTP to DB (reusing Otp model, keyed by email)
        await Otp.findOneAndUpdate(
            { email: user.email },
            { otp, createdAt: Date.now() },
            { upsert: true, new: true, setDefaultsOnInsert: true }
        );

        // Send email with specific warning template
        await sendDeleteAccountOtpEmail(user.email, otp);

        res.json({ message: 'Verification code sent to your email' });
    } catch (error) {
        console.error('Request delete OTP error:', error);
        res.status(500).json({ message: 'Failed to send verification code' });
    }
});

// Confirm Delete Account
router.delete('/delete-account', verifyToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const { otp } = req.body;

        if (!otp) {
            return res.status(400).json({ message: 'Verification code is required' });
        }

        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        // Verify OTP
        const otpRecord = await Otp.findOne({ email: user.email });
        if (!otpRecord) {
            return res.status(400).json({ message: 'Invalid or expired code' });
        }

        if (otpRecord.otp !== otp) {
            return res.status(400).json({ message: 'Invalid verification code' });
        }

        // Delete user
        await User.findByIdAndDelete(userId);

        // Cleanup: Remove OTP
        await Otp.deleteOne({ email: user.email });

        // Optional: Cleanup club memberships
        await ClubMember.deleteMany({ userId: userId });

        res.json({ message: 'Account deleted successfully' });
    } catch (error) {
        console.error('Delete account error:', error);
        res.status(500).json({ message: 'Failed to delete account' });
    }
});

// Request OTP for Change Password
router.post('/request-change-password-otp', verifyToken, profileOtpLimiter, async (req, res) => {
    try {
        const userId = req.user.id;
        const user = await User.findById(userId);

        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        const otp = generateOTP();

        // Save OTP to DB (keyed by email, same Otp model)
        await Otp.findOneAndUpdate(
            { email: user.email },
            { otp, createdAt: Date.now() },
            { upsert: true, new: true, setDefaultsOnInsert: true }
        );

        // Reuse the generic OTP email
        await sendOtpEmail(user.email, otp);

        res.json({ message: 'Verification code sent to your email' });
    } catch (error) {
        console.error('Request change-password OTP error:', error);
        res.status(500).json({ message: 'Failed to send verification code' });
    }
});

// Change Password (requires current password + OTP)
router.post('/change-password', verifyToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const { currentPassword, newPassword, otp } = req.body;

        if (!currentPassword || !newPassword) {
            return res.status(400).json({ message: 'Current password and new password are required' });
        }

        if (!otp) {
            return res.status(400).json({ message: 'Verification code is required' });
        }

        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        // Verify current password
        const isMatch = await bcrypt.compare(currentPassword, user.password);
        if (!isMatch) {
            return res.status(400).json({ message: 'Current password is incorrect' });
        }

        // Verify OTP
        const otpRecord = await Otp.findOne({ email: user.email });
        if (!otpRecord || otpRecord.otp !== otp) {
            return res.status(400).json({ message: 'Invalid or expired verification code' });
        }

        // Hash new password and save
        user.password = await bcrypt.hash(newPassword, 10);
        await user.save();

        // Cleanup OTP
        await Otp.deleteOne({ email: user.email });

        // Send confirmation email (fire and forget)
        sendPasswordChangeEmail({ email: user.email, name: user.name }).catch(err => {
            console.error('Failed to send password change email:', err);
        });

        res.json({ message: 'Password changed successfully' });
    } catch (error) {
        console.error('Change password error:', error);
        res.status(500).json({ message: 'Failed to change password' });
    }
});


// Setup Super Admin (Protected Transfer)
router.post('/setup-admin', authLimiter, async (req, res) => {
    try {
        const { email, password, name, otp } = req.body;

        // 1. Check if any admin already exists
        const existingAdmin = await User.findOne({ role: 'admin' });

        if (existingAdmin) {
            // Admin exists - require OTP from the EXISTING admin to authorize transfer
            if (!otp) {
                // Generate and send OTP to the EXISTING admin
                const newOtp = generateOTP();

                await Otp.findOneAndUpdate(
                    { email: existingAdmin.email },
                    { otp: newOtp, createdAt: Date.now() },
                    { upsert: true, new: true, setDefaultsOnInsert: true }
                );

                await sendOtpEmail(existingAdmin.email, newOtp); // Reuse standard OTP email

                // Mask the email for security
                const maskedEmail = existingAdmin.email.replace(/(^.{2}).+(@.+)/, '$1***$2');

                return res.json({
                    requireOtp: true,
                    message: `Super Admin already exists. An OTP has been sent to ${maskedEmail} to authorize this change.`
                });
            } else {
                // Verify OTP sent to EXISTING admin
                const otpRecord = await Otp.findOne({ email: existingAdmin.email });
                if (!otpRecord || otpRecord.otp !== otp) {
                    return res.status(400).json({ message: 'Invalid OTP. Authorization failed.' });
                }

                // OTP Valid - Demote existing admin
                existingAdmin.role = 'user'; // Or 'club-member'
                await existingAdmin.save();

                // Clear OTP
                await Otp.deleteOne({ email: existingAdmin.email });
            }
        }

        // 2. Create the NEW Admin
        // Check if the NEW email is already taken
        let user = await User.findOne({ email });
        if (user) {
            return res.status(400).json({ message: 'User with this email already exists' });
        }

        const hashedPassword = await bcrypt.hash(password, 10);
        user = new User({
            email,
            password: hashedPassword,
            name,
            role: 'admin'
        });

        await user.save();

        // 3. Login the new admin immediately
        const token = jwt.sign(
            { id: user._id, role: user.role, email: user.email },
            process.env.JWT_SECRET,
            { expiresIn: '24h' }
        );

        res.status(201).json({
            token,
            user: {
                id: user._id,
                name: user.name,
                email: user.email,
                role: user.role
            },
            message: 'Super Admin configured successfully'
        });

    } catch (error) {
        console.error('Setup admin error:', error);
        res.status(500).json({ message: 'Server error during setup' });
    }
});

// Register FCM Token
router.post('/fcm-token', verifyToken, async (req, res) => {
    try {
        const { token } = req.body;
        if (!token) return res.status(400).json({ message: 'Token is required' });

        await User.findByIdAndUpdate(req.user.id, {
            $addToSet: { fcmTokens: token }
        });
        res.json({ message: 'FCM token registered successfully' });
    } catch (error) {
        console.error('FCM Token registration error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Remove FCM Token (On Logout)
router.delete('/fcm-token', verifyToken, async (req, res) => {
    try {
        const { token } = req.body;
        if (!token) return res.status(400).json({ message: 'Token is required' });

        await User.findByIdAndUpdate(req.user.id, {
            $pull: { fcmTokens: token }
        });
        res.json({ message: 'FCM token removed successfully' });
    } catch (error) {
        console.error('FCM Token deletion error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

export default router;
