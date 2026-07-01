import jwt from 'jsonwebtoken';
import ClubMember from '../models/ClubMember.js';

export const verifyToken = (req, res, next) => {
    const token = req.header('Authorization')?.split(' ')[1];

    if (!token) {
        return res.status(401).json({ message: 'Access denied. No token provided.' });
    }

    try {
        if (!process.env.JWT_SECRET) {
            throw new Error('JWT_SECRET is not defined');
        }
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded;
        next();
    } catch (err) {
        console.error("Token verification error:", err.message);
        res.status(400).json({ message: 'Invalid token.' });
    }
};

export const verifyTokenOptional = (req, res, next) => {
    const token = req.header('Authorization')?.split(' ')[1];

    if (!token) {
        return next();
    }

    try {
        if (!process.env.JWT_SECRET) {
            throw new Error('JWT_SECRET is not defined');
        }
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded;
        next();
    } catch (err) {
        // Optional token, so if invalid, just proceed as guest
        next();
    }
};

// Renamed from verifyAdmin to be more explicit - System Wide Admin only
export const verifySuperAdmin = (req, res, next) => {
    verifyToken(req, res, () => {
        if (req.user.role === 'admin') {
            next();
        } else {
            res.status(403).json({ message: 'Access denied. Super Admin privileges required.' });
        }
    })
}

// Check if user is an officer OF THE SPECIFIC CLUB in the route params OR body
export const verifyClubOfficer = async (req, res, next) => {
    verifyToken(req, res, async () => {
        try {
            // Super Admin always has access. 
            // NOTE: We allow this even if clubId is missing, assuming admin can do anything.
            if (req.user.role === 'admin') {
                return next();
            }

            const clubId = req.params.id || req.params.clubId || req.body.clubId;
            if (!clubId) {
                return res.status(400).json({ message: 'Club ID is required for authorization check.' });
            }

            console.log('[Auth Debug] Checking officer for clubId:', clubId, 'userId:', req.user.id, 'email:', req.user.email);

            // Check if user is an officer of THIS club by userId OR email (case-insensitive)
            // We check BOTH the role field AND the boardType field because:
            // 1. Role field may contain custom labels (e.g., "LEAD" instead of "President")
            // 2. BoardType 'main' or 'executive' indicates officer status regardless of custom role label
            const officerFn = await ClubMember.findOne({
                clubId: clubId,
                $and: [
                    // User identity check (userId OR email)
                    {
                        $or: [
                            { userId: req.user.id },
                            { email: { $regex: new RegExp(`^${req.user.email}$`, 'i') } }
                        ]
                    },
                    // Officer status check (standard role names OR boardType)
                    {
                        $or: [
                            { role: { $in: ['Secretary', 'President', 'Treasurer', 'Advisor', 'secretary', 'president', 'treasurer', 'advisor'] } },
                            { boardType: { $in: ['main', 'executive'] } }
                        ]
                    }
                ]
            });

            console.log('[Auth Debug] Found officer record:', officerFn ? JSON.stringify({ email: officerFn.email, role: officerFn.role, boardType: officerFn.boardType, userId: officerFn.userId }) : 'null');

            if (officerFn) {
                // If found by email but userId not set, link it now
                if (!officerFn.userId && req.user.id) {
                    officerFn.userId = req.user.id;
                    await officerFn.save();
                    console.log('[Auth Debug] Linked userId to officer record');
                }
                next();
            } else {
                console.log('[Auth Debug] Officer check failed. Details:', {
                    clubId,
                    userId: req.user.id,
                    email: req.user.email,
                    providedRole: req.user.role
                });
                res.status(403).json({
                    message: 'Access denied. You are not an officer of this club.',
                    debugInfo: {
                        clubId,
                        userId: req.user.id,
                        email: req.user.email
                    }
                });
            }
        } catch (error) {
            console.error('Club Officer Auth Error:', error);
            res.status(500).json({ message: 'Server authorization error' });
        }
    })
}

// Check if user is a member (or officer) of the club
export const verifyClubMember = async (req, res, next) => {
    verifyToken(req, res, async () => {
        try {
            if (req.user.role === 'admin') {
                return next();
            }

            const clubId = req.params.id || req.params.clubId || req.body.clubId;
            if (!clubId) {
                return res.status(400).json({ message: 'Club ID is required for authorization check.' });
            }

            // Check if user is a member of THIS club by userId OR email (case-insensitive)
            const member = await ClubMember.findOne({
                clubId: clubId,
                $or: [
                    { userId: req.user.id },
                    { email: { $regex: new RegExp(`^${req.user.email}$`, 'i') } }
                ]
            });

            if (member) {
                // Self-healing: If found by email but userId not set, link it now
                if (!member.userId && req.user.id) {
                    member.userId = req.user.id;
                    await member.save();
                    console.log(`[Auth Debug] Linked userId ${req.user.id} to member record ${member._id}`);
                }
                next();
            } else {
                res.status(403).json({ message: 'Access denied. You are not a member of this club.' });
            }
        } catch (error) {
            console.error('Club Member Auth Error:', error);
            res.status(500).json({ message: 'Server authorization error' });
        }
    })
}
