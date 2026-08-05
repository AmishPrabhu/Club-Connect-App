import express from 'express';
import mongoose from 'mongoose';
import Club from '../models/Club.js';
import User from '../models/User.js';
import Post from '../models/Post.js';
import ClubMember from '../models/ClubMember.js';
import ClubMessage from '../models/ClubMessage.js';
import { verifyToken, verifySuperAdmin, verifyClubOfficer, verifyClubMember, verifyMemberManagementOfficer } from '../middleware/auth.js';
import { sendClubInvitationEmail } from '../services/emailService.js';
import { sendPushToClubMembers } from '../services/pushService.js';
import { broadcastToUser, broadcastToClub } from '../services/sseService.js';

const router = express.Router();

function escapeRegExp(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// Get all clubs
router.get('/', async (req, res) => {
    try {
        const clubs = await Club.find().sort({ name: 1 });
        // Return clubs with default category if missing
        const clubsWithCategory = clubs.map(club => {
            const clubObj = club.toObject();
            return {
                ...clubObj,
                category: clubObj.category || 'technical'
            };
        });
        res.json(clubsWithCategory);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Get single club
router.get('/:id', async (req, res) => {
    try {
        let club;

        if (mongoose.isValidObjectId(req.params.id)) {
            club = await Club.findById(req.params.id);
        }

        if (!club) {
            club = await Club.findOne({ slug: req.params.id });
        }

        if (!club) return res.status(404).json({ message: 'Club not found' });
        res.json(club);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Create club (Protected - Super Admin Only)
router.post('/', verifySuperAdmin, async (req, res) => {
    try {
        const newClub = new Club(req.body);
        const savedClub = await newClub.save();

        // === AUTO-CREATE ClubMember records for officers ===
        // This ensures officers can perform actions immediately after club creation
        const officerRoles = [
            { email: req.body.secretaryEmail, role: 'Secretary', name: req.body.secretaryName },
            { email: req.body.presidentEmail, role: 'President', name: req.body.presidentName },
            { email: req.body.treasurerEmail, role: 'Treasurer', name: req.body.treasurerName },
            { email: req.body.advisorEmail, role: 'Advisor', name: req.body.advisorName },
        ];

        for (const officer of officerRoles) {
            if (officer.email) {
                // Check if already exists (avoid duplicates)
                const existing = await ClubMember.findOne({
                    clubId: savedClub._id.toString(),
                    email: officer.email
                });

                // Find if user already has an account
                const existingUser = await User.findOne({
                    email: { $regex: new RegExp(`^${officer.email}$`, 'i') }
                });

                if (!existing) {
                    await ClubMember.create({
                        clubId: savedClub._id.toString(),
                        name: officer.name || officer.role,
                        email: officer.email,
                        role: officer.role,
                        boardType: 'main',
                        userId: existingUser?._id?.toString() || null,
                        joinedAt: new Date()
                    });
                    console.log(`[Club Create] Added ${officer.role}: ${officer.email} to ClubMember`);
                }

                // === GLOBAL ROLE SYNC ===
                // If user exists, upgrade their global role to the officer role
                if (existingUser) {
                    const roleMap = {
                        'Secretary': 'club-secretary',
                        'President': 'president',
                        'Treasurer': 'treasurer',
                        'Advisor': 'advisor'
                    };
                    const targetRole = roleMap[officer.role];

                    if (targetRole && existingUser.role !== 'admin') {
                        // Initialize roles array if it doesn't exist
                        if (!existingUser.roles) {
                            existingUser.roles = [];
                        }

                        // Add role to roles array if not already present
                        if (!existingUser.roles.includes(targetRole)) {
                            existingUser.roles.push(targetRole);
                        }

                        // Update primary role if not admin and current role is 'user'
                        if (existingUser.role === 'user' || existingUser.role !== targetRole) {
                            existingUser.role = targetRole;
                        }

                        // Also set club context if missing
                        if (!existingUser.clubId) existingUser.clubId = savedClub._id.toString();
                        if (!existingUser.clubName) existingUser.clubName = savedClub.name;

                        await existingUser.save();
                        console.log(`[Club Create] Synced global role for ${officer.email} to ${targetRole}, roles: ${existingUser.roles.join(', ')}`);
                    }
                }
            }
        }

        // Update member count
        const count = await ClubMember.countDocuments({ clubId: savedClub._id.toString() });
        if (count > 0) {
            await Club.findByIdAndUpdate(savedClub._id, { members: count });
        }

        res.status(201).json(savedClub);
    } catch (error) {
        console.error('Create club error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Update club (Protected - Club Officer or Super Admin)
router.put('/:id', verifyClubOfficer, async (req, res) => {
    try {
        // Allowed fields depend on role
        // For admin, also allow officer email/id updates
        const baseUpdates = ['name', 'description', 'image', 'category', 'departments', 'fullForm'];
        const adminUpdates = ['secretaryEmail', 'presidentEmail', 'treasurerEmail', 'advisorEmail',
            'secretaryId', 'presidentId', 'treasurerId', 'advisorId', 'advisorName'];

        const allowedUpdates = req.user.role === 'admin'
            ? [...baseUpdates, ...adminUpdates]
            : baseUpdates;

        // Create the updates object
        const updates = {};
        allowedUpdates.forEach(field => {
            if (req.body[field] !== undefined) updates[field] = req.body[field];
        });

        updates.updatedAt = Date.now();

        const club = await Club.findById(req.params.id);
        if (!club) return res.status(404).json({ message: 'Club not found' });

        // Logic to support Multiple Officers Per Role:
        // We do NOT demote existing officers when a new one is added.
        // The new officer will be added/promoted in the auto-create block below.
        // Existing officers remain until explicitly removed.

        // === HANDLE OFFICER REMOVAL (Offboarding) ===
        const officerFields = [
            { emailField: 'secretaryEmail', role: 'club-secretary', memberRole: 'Secretary' },
            { emailField: 'presidentEmail', role: 'president', memberRole: 'President' },
            { emailField: 'treasurerEmail', role: 'treasurer', memberRole: 'Treasurer' },
            { emailField: 'advisorEmail', role: 'advisor', memberRole: 'Advisor' },
        ];

        for (const officer of officerFields) {
            // Check if field is present in updates AND is explicitly null (meaning removed)
            // And if the club currently HAS an officer in that slot
            if (updates.hasOwnProperty(officer.emailField) && updates[officer.emailField] === null && club[officer.emailField]) {
                const oldEmail = club[officer.emailField];
                console.log(`[Club Update] Removing ${officer.memberRole}: ${oldEmail}`);

                // 1. Demote ClubMember to 'Member'
                try {
                    const clubMember = await ClubMember.findOne({
                        clubId: req.params.id,
                        email: { $regex: new RegExp(`^${oldEmail}$`, 'i') }
                    });

                    if (clubMember && (clubMember.role === officer.memberRole)) {
                        clubMember.role = 'Member';
                        clubMember.boardType = 'member';
                        await clubMember.save();
                        console.log(`[Club Update] Demoted ${oldEmail} from ${officer.memberRole} to Member`);
                    }
                } catch (err) {
                    console.error(`[Club Update] Error updating ClubMember for ${oldEmail}:`, err);
                }

                // 2. Update User Global Role
                try {
                    const user = await User.findOne({ email: { $regex: new RegExp(`^${oldEmail}$`, 'i') } });
                    if (user) {
                        // Remove the specific role from roles array
                        if (user.roles && user.roles.includes(officer.role)) {
                            user.roles = user.roles.filter(r => r !== officer.role);
                        }

                        // Use set to ensure unique roles and clean array
                        user.roles = [...new Set(user.roles || [])];

                        // Recalculate primary role if the removed role was the primary one
                        if (user.role === officer.role) {
                            // Hierarchy: Admin > Teacher > Advisor > President > Treasurer > Secretary > Member > User
                            const has = (r) => user.roles.includes(r);

                            if (user.role === 'admin') { /* keep admin */ }
                            else if (has('teacher')) user.role = 'teacher';
                            else if (has('advisor')) user.role = 'advisor';
                            else if (has('president')) user.role = 'president';
                            else if (has('treasurer')) user.role = 'treasurer';
                            else if (has('club-secretary')) user.role = 'club-secretary';

                            // If none of the above, check if they are still a member of ANY club
                            else {
                                // We can assume they are at least a member of this club now (since we demoted, not deleted)
                                // So 'club-member' is appropriate if they have no other officer roles
                                user.role = 'club-member';
                            }
                        }

                        // Clear club context if they are no longer an officer of THIS club
                        if (user.clubId === req.params.id) {
                            // If they are now just a member or user, clear the quick-access clubId
                            // (Unless they are an officer of ANOTHER club? 
                            //  Ideally we'd find their "next best" club, but for now clearing is safer)
                            if (['user', 'club-member'].includes(user.role)) {
                                user.clubId = null;
                                user.clubName = null;
                            }
                        }

                        await user.save();
                        console.log(`[Club Update] User ${oldEmail} role updated to ${user.role}, roles: ${user.roles.join(', ')}`);
                    }
                } catch (err) {
                    console.error(`[Club Update] Error updating User for ${oldEmail}:`, err);
                }
            }
        }

        const updatedClub = await Club.findByIdAndUpdate(req.params.id, updates, { new: true });
        if (!updatedClub) return res.status(404).json({ message: 'Club not found' });

        // === AUTO-CREATE ClubMember records when officer emails are updated ===
        const officerMappings = [
            { emailField: 'secretaryEmail', role: 'Secretary' },
            { emailField: 'presidentEmail', role: 'President' },
            { emailField: 'treasurerEmail', role: 'Treasurer' },
            { emailField: 'advisorEmail', role: 'Advisor' },
        ];

        for (const mapping of officerMappings) {
            const email = req.body[mapping.emailField];
            if (email) {
                // Find if user has an account
                const existingUser = await User.findOne({
                    email: { $regex: new RegExp(`^${email}$`, 'i') }
                });

                // Check if ClubMember entry exists
                const existing = await ClubMember.findOne({
                    clubId: req.params.id,
                    email: { $regex: new RegExp(`^${email}$`, 'i') }
                });

                if (!existing) {
                    await ClubMember.create({
                        clubId: req.params.id,
                        name: mapping.role,
                        email: email,
                        role: mapping.role,
                        boardType: 'main',
                        userId: existingUser?._id?.toString() || null,
                        joinedAt: new Date()
                    });
                    console.log(`[Club Update] Auto-created ${mapping.role} ClubMember for ${email}`);
                } else if (existing.role !== mapping.role) {
                    // Update role if officer was already a member
                    existing.role = mapping.role;
                    existing.boardType = 'main';
                    await existing.save();
                    console.log(`[Club Update] Updated role for ${email} to ${mapping.role}`);
                }

                // === GLOBAL ROLE SYNC ===
                if (existingUser) {
                    const roleMap = {
                        'Secretary': 'club-secretary',
                        'President': 'president',
                        'Treasurer': 'treasurer',
                        'Advisor': 'advisor'
                    };
                    const targetRole = roleMap[mapping.role];

                    if (targetRole && existingUser.role !== 'admin') {
                        // Initialize roles array if it doesn't exist
                        if (!existingUser.roles) {
                            existingUser.roles = [];
                        }

                        // Add role to roles array if not already present
                        if (!existingUser.roles.includes(targetRole)) {
                            existingUser.roles.push(targetRole);
                        }

                        // Update primary role
                        if (existingUser.role === 'user' || existingUser.role !== targetRole) {
                            existingUser.role = targetRole;
                        }

                        // Always update club context when role changes
                        existingUser.clubId = req.params.id;
                        existingUser.clubName = updatedClub.name;

                        await existingUser.save();
                        console.log(`[Club Update] Synced global role for ${email} to ${targetRole}, roles: ${existingUser.roles.join(', ')}`);
                    }
                }
            }
        }

        res.json(updatedClub);
    } catch (error) {
        console.error('Update club error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Delete club (Protected - Super Admin Only - was Officer)
router.delete('/:id', verifySuperAdmin, async (req, res) => {
    try {
        const club = await Club.findById(req.params.id);
        if (!club) return res.status(404).json({ message: 'Club not found' });

        // 1. Demote Officers (Secretary, President, Treasurer, Advisor)
        const officerIds = [
            club.secretaryId,
            club.presidentId,
            club.treasurerId,
            club.advisorId
        ].filter(id => id); // Filter out null/undefined

        if (officerIds.length > 0) {
            await User.updateMany(
                { _id: { $in: officerIds } },
                {
                    $set: {
                        role: 'user',
                        clubId: null,
                        clubName: null
                    }
                }
            );
        }

        // 2. Delete related data
        await Promise.all([
            Post.deleteMany({ clubId: req.params.id }),
            ClubMember.deleteMany({ clubId: req.params.id }),
            ClubMessage.deleteMany({ clubId: req.params.id })
        ]);

        // 3. Delete the club
        await Club.findByIdAndDelete(req.params.id);

        res.json({ message: 'Club and associated data deleted' });
    } catch (error) {
        console.error('Delete club error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});




// ... existing routes ...

// ==================== MEMBER ROUTES ====================

// GET members for a club (supports ?termYear=2025-2026 or default active term)
router.get('/:id/members', async (req, res) => {
    try {
        const { termYear, isCurrent } = req.query;
        let query = { clubId: req.params.id };

        if (termYear) {
            query.termYear = termYear;
        } else if (isCurrent !== undefined) {
            query.isCurrent = isCurrent === 'true';
        } else {
            // Default: try to fetch active term members first
            const activeCount = await ClubMember.countDocuments({ clubId: req.params.id, isCurrent: true });
            if (activeCount > 0) {
                query.isCurrent = true;
            }
        }

        const members = await ClubMember.find(query).sort({ name: 1 }).lean();

        // Fetch latest profile info from User collection to ensure avatar is up to date
        const enhancedMembers = await Promise.all(members.map(async (member) => {
            let user = null;

            if (member.userId) {
                user = await User.findById(member.userId).select('profileImage');
            }

            if (!user && member.email) {
                user = await User.findOne({
                    email: { $regex: new RegExp(`^${escapeRegExp(member.email)}$`, 'i') }
                }).select('profileImage');
            }

            return {
                ...member,
                profileImage: user?.profileImage || member.profileImage || ''
            };
        }));

        res.json(enhancedMembers);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// GET distinct academic terms available for a club
router.get('/:id/terms', async (req, res) => {
    try {
        const terms = await ClubMember.distinct('termYear', { clubId: req.params.id });
        const club = await Club.findById(req.params.id);
        const currentTerm = club?.currentTerm || '2025-2026';

        // Filter and sort terms descending
        const validTerms = terms.filter(Boolean);
        const allTerms = [...new Set([currentTerm, ...validTerms])].sort().reverse();

        res.json({ currentTerm, terms: allTerms });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// POST Annual Board Handover (Start New Academic Year)
router.post('/:id/handover', verifyMemberManagementOfficer, async (req, res) => {
    try {
        const { newTermYear, newPresidentEmail, newSecretaryEmail, newTreasurerEmail, newPresidentRoleTitle } = req.body;
        const clubId = req.params.id;

        if (!newTermYear || !newPresidentEmail) {
            return res.status(400).json({ message: 'New academic term and new President email are required.' });
        }

        const club = await Club.findById(clubId);
        if (!club) return res.status(404).json({ message: 'Club not found' });

        // 0. Fetch old active members BEFORE archiving
        const oldActiveMembers = await ClubMember.find({ clubId, isCurrent: true });

        // 1. Archive current active members for this club
        await ClubMember.updateMany(
            { clubId, isCurrent: true },
            { $set: { isCurrent: false } }
        );

        // 2. Update Club model with new current term & new officer emails
        const updates = {
            currentTerm: newTermYear.trim(),
            presidentEmail: newPresidentEmail.trim(),
            updatedAt: Date.now()
        };
        if (newSecretaryEmail) updates.secretaryEmail = newSecretaryEmail.trim();
        if (newTreasurerEmail) updates.treasurerEmail = newTreasurerEmail.trim();

        const updatedClub = await Club.findByIdAndUpdate(clubId, updates, { new: true });

        // 3. Create or update new active ClubMember entries for new President & Officers
        const presidentRoleTitle = newPresidentRoleTitle || 'President';
        const newOfficers = [
            { email: newPresidentEmail.trim(), role: presidentRoleTitle, boardType: 'main' },
        ];
        if (newSecretaryEmail) newOfficers.push({ email: newSecretaryEmail.trim(), role: 'Secretary', boardType: 'main' });
        if (newTreasurerEmail) newOfficers.push({ email: newTreasurerEmail.trim(), role: 'Treasurer', boardType: 'main' });

        for (const officer of newOfficers) {
            const existingUser = await User.findOne({
                email: { $regex: new RegExp(`^${escapeRegExp(officer.email)}$`, 'i') }
            });

            await ClubMember.create({
                clubId,
                name: existingUser?.name || officer.role,
                email: officer.email,
                role: officer.role,
                boardType: officer.boardType,
                userId: existingUser?._id?.toString() || null,
                termYear: newTermYear.trim(),
                isCurrent: true,
                joinedAt: new Date()
            });

            // Global role sync if user exists
            if (existingUser) {
                const roleMap = {
                    'President': 'president',
                    'Secretary': 'club-secretary',
                    'Treasurer': 'treasurer'
                };
                const targetRole = roleMap[officer.role] || 'president';

                if (targetRole && existingUser.role !== 'admin') {
                    if (!existingUser.roles) existingUser.roles = [];
                    if (!existingUser.roles.includes(targetRole)) existingUser.roles.push(targetRole);
                    existingUser.role = targetRole;
                    existingUser.clubId = clubId;
                    existingUser.clubName = updatedClub.name;
                    await existingUser.save();
                }
            }
        }

        // Update member count for active board
        const count = await ClubMember.countDocuments({ clubId, isCurrent: true });
        await Club.findByIdAndUpdate(clubId, { members: count });

        // 4. Clean up global roles of ALL old members (demote officers or revert to default user)
        for (const oldMember of oldActiveMembers) {
            if (!oldMember.email) continue;

            const existingUser = await User.findOne({
                email: { $regex: new RegExp(`^${escapeRegExp(oldMember.email)}$`, 'i') }
            });

            if (existingUser) {
                // Find all active memberships this user still holds in ANY club
                const activeMemberships = await ClubMember.find({
                    $or: [{ userId: existingUser._id }, { email: { $regex: new RegExp(`^${escapeRegExp(oldMember.email)}$`, 'i') } }],
                    isCurrent: true
                });

                if (activeMemberships.length === 0) {
                    // They hold NO active memberships anywhere. Revert to default 'user'.
                    const rolesToRemove = ['president', 'treasurer', 'club-secretary', 'advisor', 'club-member'];
                    if (existingUser.roles) {
                        existingUser.roles = existingUser.roles.filter(r => !rolesToRemove.includes(r));
                    }
                    
                    const privilegedRoles = ['admin', 'teacher'];
                    if (!privilegedRoles.includes(existingUser.role)) {
                        existingUser.role = 'user'; // Fully reset to standard user
                    }
                    
                    existingUser.clubId = null;
                    existingUser.clubName = null;

                    await existingUser.save();
                } else {
                    // They DO have active memberships in other clubs.
                    // Check if they are still an officer anywhere.
                    const isStillOfficer = activeMemberships.some(m => {
                        const r = (m.role || '').toLowerCase();
                        return ['president', 'secretary', 'treasurer', 'advisor', 'vice-president', 'assistant secretary', 'assistant treasurer'].includes(r)
                            || m.boardType === 'main'
                            || m.boardType === 'executive';
                    });

                    if (!isStillOfficer) {
                        // Strip officer privileges, keep as 'club-member'
                        const officerRolesToRemove = ['president', 'treasurer', 'club-secretary', 'advisor'];
                        if (existingUser.roles) {
                            existingUser.roles = existingUser.roles.filter(r => !officerRolesToRemove.includes(r));
                        }
                        
                        const privilegedRoles = ['admin', 'teacher'];
                        if (!privilegedRoles.includes(existingUser.role)) {
                            existingUser.role = 'club-member';
                        }
                    }

                    // Update clubId/clubName to point to an active club if it was pointing to the one they just left
                    if (existingUser.clubId === clubId) {
                        const nextClub = await Club.findById(activeMemberships[0].clubId);
                        if (nextClub) {
                            existingUser.clubId = nextClub._id.toString();
                            existingUser.clubName = nextClub.name;
                        }
                    }
                    
                    await existingUser.save();
                }
            }
        }

        // Broadcast SSE event for real-time app update
        try {
            const { broadcast } = await import('../services/sseService.js');
            broadcast('club_updated', updatedClub.toObject());
        } catch (_) {}

        res.json({ success: true, club: updatedClub, message: `Successfully transitioned to ${newTermYear}!` });
    } catch (error) {
        console.error('Handover error:', error);
        res.status(500).json({ message: error.message });
    }
});

// POST Bulk Promote / Import Members from Previous Term with Assigned Roles
router.post('/:id/members/promote', verifyMemberManagementOfficer, async (req, res) => {
    try {
        const { members, targetTermYear } = req.body;
        const clubId = req.params.id;

        if (!Array.isArray(members) || members.length === 0) {
            return res.status(400).json({ message: 'No members provided for promotion.' });
        }

        const club = await Club.findById(clubId);
        if (!club) return res.status(404).json({ message: 'Club not found' });

        const termToUse = targetTermYear || club.currentTerm || '2026-2027';
        const results = [];

        for (const item of members) {
            const { email, name, newRole, newBoardType, newAcademicYear } = item;
            if (!email) continue;

            const existingUser = await User.findOne({
                email: { $regex: new RegExp(`^${escapeRegExp(email)}$`, 'i') }
            });

            let memberDoc = await ClubMember.findOne({
                clubId,
                email: { $regex: new RegExp(`^${escapeRegExp(email)}$`, 'i') },
                termYear: termToUse
            });

            if (!memberDoc) {
                memberDoc = await ClubMember.create({
                    clubId,
                    name: name || existingUser?.name || 'Member',
                    email: email.trim(),
                    role: newRole || 'Member',
                    boardType: newBoardType || 'executive',
                    academicYear: newAcademicYear || 'TY',
                    userId: existingUser?._id?.toString() || null,
                    termYear: termToUse,
                    isCurrent: true,
                    joinedAt: new Date()
                });
            } else {
                memberDoc.role = newRole || memberDoc.role;
                memberDoc.boardType = newBoardType || memberDoc.boardType;
                if (newAcademicYear) memberDoc.academicYear = newAcademicYear;
                memberDoc.isCurrent = true;
                await memberDoc.save();
            }
            results.push(memberDoc);
        }

        const count = await ClubMember.countDocuments({ clubId, isCurrent: true });
        await Club.findByIdAndUpdate(clubId, { members: count });

        broadcastToClub(clubId, 'club_members_updated', { clubId });
        for (const resItem of results) {
            if (resItem.userId) {
                broadcastToUser(resItem.userId.toString(), 'user_updated', { action: 'member_promoted', clubId });
            }
        }

        res.json({ success: true, count: results.length, members: results });
    } catch (error) {
        console.error('Promote members error:', error);
        res.status(500).json({ message: error.message });
    }
});

// Add member to club (Protected - Member Management Officer)
router.post('/:id/members', verifyMemberManagementOfficer, async (req, res) => {
    try {
        const { name, email, role, userId, boardType, academicYear, joinedAt } = req.body;
        const clubId = req.params.id;

        // Role Verification: Only President/Admin can add Secretary or Treasurer to Main Board
        if (boardType === 'main' && ['secretary', 'treasurer'].includes((role || '').toLowerCase())) {
            if (req.user.role !== 'president' && req.user.role !== 'admin') {
                return res.status(403).json({ message: 'Only Presidents and Admins can assign Secretary or Treasurer roles.' });
            }
        }

        const existing = await ClubMember.findOne({ clubId, email });
        if (existing) {
            return res.status(400).json({ message: 'Member already exists in this club' });
        }

        const newMember = new ClubMember({
            clubId,
            name,
            email,
            role: role || 'Member',
            boardType: boardType || 'member',
            userId: userId || null,
            academicYear: academicYear || '',
            joinedAt: joinedAt || Date.now()
        });

        await newMember.save();

        // Check if user exists and auto-assign club-member role
        let existingUser = null;
        if (userId) {
            existingUser = await User.findById(userId);
        } else if (email) {
            existingUser = await User.findOne({ email });
        }

        if (existingUser) {
            // Initialize roles array if missing
            if (!existingUser.roles) existingUser.roles = [];

            const roleMap = {
                'Secretary': 'club-secretary',
                'President': 'president',
                'Treasurer': 'treasurer',
                'Advisor': 'advisor',
                'Assistant Secretary': 'club-secretary',
                'Assistant Treasurer': 'treasurer',
            };
            
            const memberRoleStr = role || 'Member';
            const mappedRole = roleMap[memberRoleStr];

            // Add 'club-member' to roles if not present
            if (!existingUser.roles.includes('club-member')) {
                existingUser.roles.push('club-member');
            }

            if (mappedRole && !existingUser.roles.includes(mappedRole)) {
                existingUser.roles.push(mappedRole);
            }

            // Only update primary role to 'club-member' or mappedRole if their current role is 'user'
            // Do NOT overwrite if they are teacher, admin, advisor, etc.
            const privilegedRoles = ['admin', 'teacher', 'advisor', 'president', 'treasurer', 'club-secretary'];
            if (!privilegedRoles.includes(existingUser.role)) {
                existingUser.role = mappedRole || 'club-member';
            } else if (existingUser.role === 'club-member' && mappedRole) {
                existingUser.role = mappedRole;
            }

            if (mappedRole) {
                existingUser.clubId = clubId;
            }

            await existingUser.save();
        }

        // Send invitation email if user doesn't exist (fire-and-forget, don't block API response)


        if (!existingUser && !req.body.suppressEmail) {

            // Fire-and-forget: don't await, let it run in background
            (async () => {
                try {
                    const club = await Club.findById(clubId);
                    const signUpUrl = `${process.env.FRONTEND_URL}?page=signUp&email=${encodeURIComponent(email)}`;


                    const result = await sendClubInvitationEmail({
                        name,
                        email,
                        role: role || 'Member',
                        clubName: club?.name || 'a club',
                        signUpUrl
                    });

                    if (result.success) {
                        // Email sent
                    } else {
                        console.error('❌ Failed to send invitation email:', result.error);
                    }
                } catch (emailError) {
                    console.error('❌ Error sending invitation email:', emailError);
                }
            })();
        } else {
            // User already exists
        }

        // Update member count in Club
        const count = await ClubMember.countDocuments({ clubId });
        await Club.findByIdAndUpdate(clubId, { members: count });

        if (existingUser) {
            broadcastToUser(existingUser._id.toString(), 'user_updated', {
                action: 'member_added',
                clubId,
                role: existingUser.role
            });
        }
        broadcastToClub(clubId, 'club_members_updated', { clubId });

        res.status(201).json(newMember);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// Update member (Protected - Member Management Officer)
router.put('/:id/members/:memberId', verifyMemberManagementOfficer, async (req, res) => {
    try {
        const { name, email, role, academicYear, joinedAt, boardType } = req.body;
        
        // Role Verification: Only President/Admin can assign Secretary or Treasurer to Main Board
        if (boardType === 'main' && ['secretary', 'treasurer'].includes((role || '').toLowerCase())) {
            if (req.user.role !== 'president' && req.user.role !== 'admin') {
                return res.status(403).json({ message: 'Only Presidents and Admins can assign Secretary or Treasurer roles.' });
            }
        }

        const updateData = { name, email, role };
        if (academicYear !== undefined) updateData.academicYear = academicYear;
        if (joinedAt !== undefined) updateData.joinedAt = joinedAt;
        if (boardType !== undefined) updateData.boardType = boardType;

        const updatedMember = await ClubMember.findByIdAndUpdate(
            req.params.memberId,
            updateData,
            { new: true }
        );

        // Update member count in Club
        const count = await ClubMember.countDocuments({ clubId: req.params.id });
        await Club.findByIdAndUpdate(req.params.id, { members: count });

        // --- GLOBAL ROLE SYNC ---
        const existingUser = updatedMember.userId 
            ? await User.findById(updatedMember.userId) 
            : await User.findOne({ email: { $regex: new RegExp(`^${escapeRegExp(updatedMember.email)}$`, 'i') } });

        if (existingUser) {
            if (!existingUser.roles) existingUser.roles = [];
            
            const roleMap = {
                'Secretary': 'club-secretary',
                'President': 'president',
                'Treasurer': 'treasurer',
                'Advisor': 'advisor',
                'Assistant Secretary': 'club-secretary',
                'Assistant Treasurer': 'treasurer',
            };
            
            const mappedRole = roleMap[updatedMember.role];
            
            if (!existingUser.roles.includes('club-member')) {
                existingUser.roles.push('club-member');
            }
            
            if (mappedRole && !existingUser.roles.includes(mappedRole)) {
                existingUser.roles.push(mappedRole);
            }
            
            const privilegedRoles = ['admin', 'teacher', 'advisor', 'president', 'treasurer', 'club-secretary'];
            if (!privilegedRoles.includes(existingUser.role)) {
                existingUser.role = mappedRole || 'club-member';
            } else if (existingUser.role === 'club-member' && mappedRole) {
                existingUser.role = mappedRole;
            }

            if (mappedRole) {
                existingUser.clubId = req.params.id;
            }

            await existingUser.save();
            broadcastToUser(existingUser._id.toString(), 'user_updated', {
                action: 'member_updated',
                clubId: req.params.id,
                role: existingUser.role
            });
        }
        // -----------------------

        broadcastToClub(req.params.id, 'club_members_updated', { clubId: req.params.id });

        res.json(updatedMember);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// Remove member (Protected - Club Officer)
// Remove member (Protected - Member Management Officer)
router.delete('/:id/members/:memberId', verifyMemberManagementOfficer, async (req, res) => {
    try {
        const memberToDelete = await ClubMember.findById(req.params.memberId);
        if (!memberToDelete) {
            return res.status(404).json({ message: 'Member not found' });
        }

        const memberEmail = memberToDelete.email;
        const memberRole = memberToDelete.role;

        // Logic Change: If President, demote to Member instead of deleting
        // For other roles, proceed with deletion
        if (memberRole === 'President') {
            memberToDelete.role = 'Member';
            memberToDelete.boardType = 'member';
            memberToDelete.name = memberToDelete.name || 'Member'; // Ensure name exists
            await memberToDelete.save();
            console.log(`[Club Delete] Demoted President ${memberEmail} to Member`);
        } else {
            await ClubMember.findByIdAndDelete(req.params.memberId);
            console.log(`[Club Delete] Removed member ${memberEmail} (${memberRole})`);
        }

        // Check and clear officer fields in Club document if the removed/demoted member was an officer
        const club = await Club.findById(req.params.id);
        if (club) {
            let updates = {};
            // We use case-insensitive comparison for email just in case
            const isMatch = (email1, email2) => email1 && email2 && email1.toLowerCase() === email2.toLowerCase();

            if (isMatch(club.secretaryEmail, memberEmail)) {
                const anotherSec = await ClubMember.findOne({ clubId: req.params.id, role: 'Secretary' });
                updates.secretaryEmail = anotherSec ? anotherSec.email : null;
                updates.secretaryId = anotherSec ? anotherSec.userId : null;
            }
            if (isMatch(club.presidentEmail, memberEmail)) {
                // We just demoted the president (or helper deleted if multiple?), so we must clear the Club's president field
                updates.presidentEmail = null;
                updates.presidentId = null;
            }
            if (isMatch(club.treasurerEmail, memberEmail)) {
                const anotherTreas = await ClubMember.findOne({ clubId: req.params.id, role: 'Treasurer' });
                updates.treasurerEmail = anotherTreas ? anotherTreas.email : null;
                updates.treasurerId = anotherTreas ? anotherTreas.userId : null;
            }
            if (isMatch(club.advisorEmail, memberEmail)) {
                updates.advisorEmail = null;
                updates.advisorName = null;
                updates.advisorId = null;
            }

            if (Object.keys(updates).length > 0) {
                await Club.findByIdAndUpdate(req.params.id, updates);
            }
        }

        // Auto-downgrade global role if user is no longer in any clubs (or role changed)
        // Recalculate and update user role based on remaining memberships
        const user = await User.findOne({ email: { $regex: new RegExp(`^${escapeRegExp(memberEmail)}$`, 'i') } });
        if (user && user.role !== 'admin') {
            // Check all remaining memberships for this user
            const remainingMemberships = await ClubMember.find({
                email: { $regex: new RegExp(`^${escapeRegExp(memberEmail)}$`, 'i') }
            });

            // Initialize roles array if it doesn't exist
            if (!user.roles) {
                user.roles = [];
            }

            let newRole = 'user';
            const newRoles = [];

            if (remainingMemberships.length > 0) {
                // Default base role if any membership exists
                newRole = 'club-member';

                // Determine highest role held across all clubs
                const roles = remainingMemberships.map(m => m.role.toLowerCase());
                const boardTypes = remainingMemberships.map(m => m.boardType);

                const hasAdvisor = roles.includes('advisor');
                const hasPresident = roles.includes('president');
                const hasTreasurer = roles.includes('treasurer');

                // Secretary or any main/executive board member gets officer access
                const hasOfficerAccess = roles.includes('secretary') ||
                    boardTypes.includes('main') ||
                    boardTypes.includes('executive');

                // Build roles array
                if (hasAdvisor) {
                    newRoles.push('advisor');
                    newRole = 'advisor'; // Primary role
                }
                if (hasPresident) {
                    newRoles.push('president');
                    if (newRole === 'user' || newRole === 'club-member') newRole = 'president';
                }
                if (hasTreasurer) {
                    newRoles.push('treasurer');
                    if (newRole === 'user' || newRole === 'club-member') newRole = 'treasurer';
                }
                if (hasOfficerAccess) {
                    newRoles.push('club-secretary');
                    if (newRole === 'user' || newRole === 'club-member') newRole = 'club-secretary';
                }
            }

            // Check if user has teacher role - preserve it if they do
            if (user.roles.includes('teacher') || user.role === 'teacher') {
                newRoles.push('teacher');
                // If they lost advisor role but still have teacher, set primary to teacher
                if (!newRoles.includes('advisor') && newRole !== 'advisor') {
                    newRole = 'teacher';
                }
            }

            // Remove duplicates from roles array
            user.roles = [...new Set(newRoles)];

            // Only update if role actually changes
            if (user.role !== newRole) {
                user.role = newRole;
                await user.save();
                console.log(`[Club Delete] Synced global role for ${memberEmail} to ${newRole}, roles array: ${user.roles.join(', ')}`);
            } else if (JSON.stringify(user.roles.sort()) !== JSON.stringify(newRoles.sort())) {
                // Update if roles array changed even if primary role didn't
                await user.save();
                console.log(`[Club Delete] Updated roles array for ${memberEmail}: ${user.roles.join(', ')}`);
            }
        }

        // Update member count
        const count = await ClubMember.countDocuments({ clubId: req.params.id });
        await Club.findByIdAndUpdate(req.params.id, { members: count });

        const message = memberRole === 'President' ? 'President demoted to member' : 'Member removed';
        res.json({ message });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});




// ... existing routes ...

// ==================== MESSAGE ROUTES ====================

// GET messages for a club (Protected - Club Member Only)
router.get('/:id/messages', verifyClubMember, async (req, res) => {
    try {
        const messages = await ClubMessage.find({ clubId: req.params.id }).sort({ createdAt: -1 });
        res.json(messages);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// Create club message
router.post('/:id/messages', verifyClubOfficer, async (req, res) => {
    try {
        const { title, body } = req.body;
        const clubId = req.params.id;
        const userId = req.user.id;

        // Fetch user from DB to get the latest/real name
        const dbUser = await User.findById(userId);
        const resolvedSenderName = dbUser ? dbUser.name : (req.user.name || 'Club Officer');

        let officerRole = null;

        if (req.user.role === 'admin') {
            officerRole = 'Admin';
        } else if (req.user.role === 'teacher') {
            officerRole = 'Teacher';
        } else if (req.user.role === 'advisor') {
            officerRole = 'Advisor';
        } else {
            const member = await ClubMember.findOne({
                clubId,
                $or: [
                    { userId },
                    { email: { $regex: new RegExp(`^${req.user.email}$`, 'i') } }
                ]
            });
            officerRole = member ? member.role : 'Officer';
        }

        // Fetch club name for the message record
        const club = await Club.findById(clubId);
        if (!club) return res.status(404).json({ message: 'Club not found' });

        const newMessage = new ClubMessage({
            clubId,
            clubName: club.name,
            senderId: userId,
            senderName: resolvedSenderName,
            senderRole: officerRole,
            title,
            body,
        });

        await newMessage.save();

        // Fire-and-forget FCM push to club members for background devices
        sendPushToClubMembers(
            clubId,
            title,
            `${resolvedSenderName} (${officerRole}): ${body.substring(0, 80)}`,
            {
                type: 'club_message',
                action: 'new_club_message',
                clubId: clubId.toString(),
                messageId: newMessage._id.toString(),
            }
        ).catch(err => console.error('[FCM] Club message push error:', err));

        res.status(201).json(newMessage);
    } catch (error) {
        console.error('Create message error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

export default router;
