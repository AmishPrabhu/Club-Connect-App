import ClubMember from '../models/ClubMember.js';
import User from '../models/User.js';

/**
 * Middleware to verify that the authenticated user has a specific role in a club.
 * This performs real-time database validation to prevent stale authorization.
 * 
 * @param {string} clubId - The club ID to check membership for
 * @param {string[]} allowedRoles - Array of allowed roles (e.g., ['President', 'Secretary'])
 * @returns {Function} Express middleware function
 */
export const verifyClubOfficerRole = (allowedRoles = []) => {
    return async (req, res, next) => {
        try {
            const userId = req.user?.id;
            const userEmail = req.user?.email;
            const clubId = req.params.id || req.params.clubId || req.body.clubId;

            if (!userId || !userEmail) {
                return res.status(401).json({
                    message: 'Authentication required',
                    code: 'AUTH_REQUIRED'
                });
            }

            if (!clubId) {
                return res.status(400).json({
                    message: 'Club ID is required',
                    code: 'CLUB_ID_REQUIRED'
                });
            }

            // Admin bypass - admins can access all clubs
            if (req.user.role === 'admin') {
                return next();
            }

            // Check ClubMember collection for current role
            const clubMember = await ClubMember.findOne({
                clubId: clubId,
                $or: [
                    { userId: userId },
                    { email: { $regex: new RegExp(`^${userEmail}$`, 'i') } }
                ]
            });

            if (!clubMember) {
                return res.status(403).json({
                    message: 'You are not a member of this club',
                    code: 'NOT_CLUB_MEMBER'
                });
            }

            // Check if user has one of the allowed roles
            const hasAllowedRole = allowedRoles.length === 0 ||
                allowedRoles.some(role =>
                    clubMember.role.toLowerCase() === role.toLowerCase()
                );

            if (!hasAllowedRole) {
                return res.status(403).json({
                    message: `Access denied. Required role: ${allowedRoles.join(' or ')}. Your role: ${clubMember.role}`,
                    code: 'INSUFFICIENT_PERMISSIONS',
                    currentRole: clubMember.role,
                    requiredRoles: allowedRoles
                });
            }

            // Attach club member info to request for downstream use
            req.clubMember = clubMember;
            next();
        } catch (error) {
            console.error('Club role verification error:', error);
            res.status(500).json({
                message: 'Error verifying club permissions',
                code: 'VERIFICATION_ERROR'
            });
        }
    };
};

/**
 * Middleware to verify user has any officer role in a club
 * (President, Secretary, Treasurer, or Advisor)
 */
export const verifyAnyClubOfficer = verifyClubOfficerRole(['President', 'Secretary', 'Treasurer', 'Advisor']);

/**
 * Middleware to verify user is a club member (any role)
 */
export const verifyClubMembership = verifyClubOfficerRole([]);
