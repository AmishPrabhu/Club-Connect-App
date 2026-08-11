import jwt from 'jsonwebtoken';
import ClubMember from '../models/ClubMember.js';
import Club from '../models/Club.js';

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

            // Fetch the club to check direct email assignments as fallback (failsafe/auto-heal)
            const club = await Club.findById(clubId);
            const emailLower = req.user.email?.toLowerCase();
            let isDirectOfficer = false;
            let resolvedDirectRole = null;

            if (club) {
                if (club.presidentEmail?.toLowerCase() === emailLower) {
                    isDirectOfficer = true;
                    resolvedDirectRole = 'President';
                } else if (club.secretaryEmail?.toLowerCase() === emailLower) {
                    isDirectOfficer = true;
                    resolvedDirectRole = 'Secretary';
                } else if (club.treasurerEmail?.toLowerCase() === emailLower) {
                    isDirectOfficer = true;
                    resolvedDirectRole = 'Treasurer';
                } else if (club.advisorEmail?.toLowerCase() === emailLower) {
                    isDirectOfficer = true;
                    resolvedDirectRole = 'Advisor';
                }
            }

            // Check if user is an officer of THIS club by userId OR email (case-insensitive) in ClubMember collection
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
            console.log('[Auth Debug] Is direct officer based on Club emails:', isDirectOfficer);

            if (isDirectOfficer || officerFn) {
                // AUTO-HEAL: If direct officer but ClubMember record is out-of-sync or missing, sync it now
                if (isDirectOfficer && resolvedDirectRole) {
                    const memberRecord = await ClubMember.findOne({
                        clubId: clubId,
                        $or: [
                            { userId: req.user.id },
                            { email: { $regex: new RegExp(`^${req.user.email}$`, 'i') } }
                        ]
                    });

                    if (memberRecord) {
                        let updated = false;
                        if (memberRecord.role !== resolvedDirectRole) {
                            memberRecord.role = resolvedDirectRole;
                            updated = true;
                        }
                        if (memberRecord.boardType !== 'main') {
                            memberRecord.boardType = 'main';
                            updated = true;
                        }
                        if (updated) {
                            await memberRecord.save();
                            console.log(`[Auth Debug] Auto-healed out-of-sync ClubMember record for ${req.user.email} as ${resolvedDirectRole}`);
                        }
                    } else {
                        // Create missing ClubMember record
                        await ClubMember.create({
                            clubId,
                            userId: req.user.id,
                            name: req.user.name || resolvedDirectRole,
                            email: req.user.email,
                            role: resolvedDirectRole,
                            boardType: 'main'
                        });
                        console.log(`[Auth Debug] Auto-created missing ClubMember record for ${req.user.email} as ${resolvedDirectRole}`);
                    }
                }

                // If found by email but userId not set, link it now
                if (officerFn && !officerFn.userId && req.user.id) {
                    officerFn.userId = req.user.id;
                    await officerFn.save();
                    console.log('[Auth Debug] Linked userId to officer record');
                }
                
                return next();
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
};

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

// Check if user is a member management officer (President, Secretary, Advisor)
// NOTE: Assistant Secretary is intentionally excluded — they cannot add/delete members.
export const verifyMemberManagementOfficer = async (req, res, next) => {
    verifyToken(req, res, async () => {
        try {
            if (req.user.role === 'admin') {
                return next();
            }

            const clubId = req.params.id || req.params.clubId || req.body.clubId;
            if (!clubId) {
                return res.status(400).json({ message: 'Club ID is required for authorization check.' });
            }

            const club = await Club.findById(clubId);
            const emailLower = req.user.email?.toLowerCase();
            let isDirectOfficer = false;

            if (club) {
                if (club.presidentEmail?.toLowerCase() === emailLower ||
                    club.secretaryEmail?.toLowerCase() === emailLower ||
                    club.advisorEmail?.toLowerCase() === emailLower) {
                    isDirectOfficer = true;
                }
            }

            // Assistant Secretary is NOT in this list — they cannot manage members.
            const officerFn = await ClubMember.findOne({
                clubId: clubId,
                $and: [
                    {
                        $or: [
                            { userId: req.user.id },
                            { email: { $regex: new RegExp(`^${req.user.email}$`, 'i') } }
                        ]
                    },
                    {
                        role: { $in: ['Secretary', 'President', 'Advisor', 'secretary', 'president', 'advisor'] }
                    }
                ]
            });

            if (isDirectOfficer || officerFn) {
                return next();
            } else {
                res.status(403).json({
                    message: 'Access denied. Only the President, Secretary, or Advisor can manage members.',
                    debugInfo: { clubId, userId: req.user.id, email: req.user.email }
                });
            }
        } catch (error) {
            console.error('Member Management Auth Error:', error);
            res.status(500).json({ message: 'Server authorization error' });
        }
    })
};

// Check if user can edit club details (name, image, links, full form, description, etc.)
// Allows: Admin, President, Secretary, Treasurer, Advisor.
// Blocks: Assistant Secretary and any other executive-board member without a full-officer role.
export const verifyClubDetailsOfficer = async (req, res, next) => {
    verifyToken(req, res, async () => {
        try {
            if (req.user.role === 'admin') {
                return next();
            }

            const clubId = req.params.id || req.params.clubId || req.body.clubId;
            if (!clubId) {
                return res.status(400).json({ message: 'Club ID is required for authorization check.' });
            }

            const club = await Club.findById(clubId);
            const emailLower = req.user.email?.toLowerCase();
            let isDirectOfficer = false;

            // Check Club-level direct email assignments (these are always full officers)
            if (club) {
                if (club.presidentEmail?.toLowerCase() === emailLower ||
                    club.secretaryEmail?.toLowerCase() === emailLower ||
                    club.treasurerEmail?.toLowerCase() === emailLower ||
                    club.advisorEmail?.toLowerCase() === emailLower) {
                    isDirectOfficer = true;
                }
            }

            if (isDirectOfficer) {
                return next();
            }

            // Check ClubMember record — only full officer roles, NOT Assistant Secretary
            const officerFn = await ClubMember.findOne({
                clubId: clubId,
                $and: [
                    {
                        $or: [
                            { userId: req.user.id },
                            { email: { $regex: new RegExp(`^${req.user.email}$`, 'i') } }
                        ]
                    },
                    {
                        // Explicitly list allowed roles — Assistant Secretary is NOT here
                        role: { $in: ['Secretary', 'President', 'Treasurer', 'Advisor', 'secretary', 'president', 'treasurer', 'advisor'] }
                    }
                ]
            });

            if (officerFn) {
                return next();
            } else {
                res.status(403).json({
                    message: 'Access denied. Only the President, Secretary, Treasurer, or Advisor can edit club details.',
                    debugInfo: { clubId, userId: req.user.id, email: req.user.email }
                });
            }
        } catch (error) {
            console.error('Club Details Officer Auth Error:', error);
            res.status(500).json({ message: 'Server authorization error' });
        }
    })
};

// Check if user is an event officer (President, Secretary, Assistant Secretary)
export const verifyEventOfficer = async (req, res, next) => {
    verifyToken(req, res, async () => {
        try {
            if (req.user.role === 'admin') {
                return next();
            }

            const clubId = req.params.id || req.params.clubId || req.body.clubId;
            if (!clubId) {
                return res.status(400).json({ message: 'Club ID is required for authorization check.' });
            }

            const club = await Club.findById(clubId);
            const emailLower = req.user.email?.toLowerCase();
            let isDirectOfficer = false;

            if (club) {
                if (club.presidentEmail?.toLowerCase() === emailLower ||
                    club.secretaryEmail?.toLowerCase() === emailLower) {
                    isDirectOfficer = true;
                }
            }

            const officerFn = await ClubMember.findOne({
                clubId: clubId,
                $and: [
                    {
                        $or: [
                            { userId: req.user.id },
                            { email: { $regex: new RegExp(`^${req.user.email}$`, 'i') } }
                        ]
                    },
                    {
                        role: { $in: ['Secretary', 'President', 'Assistant Secretary', 'secretary', 'president', 'assistant secretary'] }
                    }
                ]
            });

            if (isDirectOfficer || officerFn) {
                return next();
            } else {
                res.status(403).json({
                    message: 'Access denied. Only the president, secretary, or assistant secretary can manage events.',
                    debugInfo: { clubId, userId: req.user.id, email: req.user.email }
                });
            }
        } catch (error) {
            console.error('Event Officer Auth Error:', error);
            res.status(500).json({ message: 'Server authorization error' });
        }
    })
};
