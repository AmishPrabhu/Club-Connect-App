import express from 'express';
import multer from 'multer';
import ExcelJS from 'exceljs';
import ClubMember from '../models/ClubMember.js';
import User from '../models/User.js';
import { verifyToken } from '../middleware/auth.js';
import { sendClubInvitationEmail } from '../services/emailService.js';

const router = express.Router();

// Configure multer for file upload (memory storage)
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 5 * 1024 * 1024, // 5MB limit
    },
    fileFilter: (req, file, cb) => {
        const allowedTypes = [
            'application/vnd.ms-excel',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'text/csv'
        ];
        if (allowedTypes.includes(file.mimetype)) {
            cb(null, true);
        } else {
            cb(new Error('Invalid file type. Only Excel and CSV files are allowed.'));
        }
    }
});

// Bulk import members from Excel
router.post('/:clubId/members/bulk-import', verifyToken, upload.single('file'), async (req, res) => {
    try {
        const { clubId } = req.params;
        const { id: userId, role } = req.user;

        // Check authorization - only club secretary, president, treasurer, or admin
        if (role !== 'admin') {
            // Verify user is an officer of THIS specific club
            const officer = await ClubMember.findOne({
                clubId,
                userId,
                role: { $in: ['Secretary', 'President', 'Treasurer', 'Advisor'] }
            });
            if (!officer) {
                return res.status(403).json({ message: 'Unauthorized to import members for this club' });
            }
        }

        if (!req.file) {
            return res.status(400).json({ message: 'No file uploaded' });
        }

        // Parse Excel file using ExcelJS
        const workbook = new ExcelJS.Workbook();
        await workbook.xlsx.load(req.file.buffer);
        const worksheet = workbook.getWorksheet(1); // Get first sheet or by name

        if (!worksheet || worksheet.rowCount <= 1) { // rowCount includes header
            return res.status(400).json({ message: 'Excel file is empty or missing data' });
        }

        // Convert worksheet to JSON array
        const data = [];
        const headers = [];

        // Get headers from first row
        worksheet.getRow(1).eachCell((cell, colNumber) => {
            headers[colNumber] = cell.value;
        });

        // specific check for empty headers array which implies an empty sheet
        if (headers.length === 0) {
            return res.status(400).json({ message: 'Excel file appears to be empty or has no headers' });
        }

        // Iterate over rows starting from 2
        worksheet.eachRow((row, rowNumber) => {
            if (rowNumber === 1) return; // Skip header

            const rowData = {};
            row.eachCell((cell, colNumber) => {
                const header = headers[colNumber];
                if (header) {
                    // Handle rich text or strange cell values if necessary, usually .value implies the raw value
                    // For ExcelJS, check if value is object (like hyperlink or rich text)
                    let cellValue = cell.value;
                    if (cellValue && typeof cellValue === 'object') {
                        if (cellValue.text) cellValue = cellValue.text;
                        else if (cellValue.result) cellValue = cellValue.result; // formula result
                    }
                    rowData[header] = cellValue;
                }
            });
            // Only add if we have some data
            if (Object.keys(rowData).length > 0) {
                data.push(rowData);
            }
        });

        if (data.length === 0) {
            return res.status(400).json({ message: 'Excel file contains no valid data rows' });
        }

        if (data.length > 500) {
            return res.status(400).json({ message: 'Maximum 500 members allowed per import' });
        }

        const results = {
            total: data.length,
            added: 0,
            updated: 0,
            failed: 0,
            emailsSent: 0,
            details: {
                added: [],
                updated: [],
                failed: []
            }
        };

        // Process each row
        for (let i = 0; i < data.length; i++) {
            const row = data[i];
            const rowNumber = i + 2; // Excel row number (accounting for header)

            try {
                // Validate required fields
                if (!row.Name || !row.Email || !row.Role) {
                    results.failed++;
                    results.details.failed.push({
                        row: rowNumber,
                        email: row.Email || 'N/A',
                        error: 'Missing required fields (Name, Email, or Role)'
                    });
                    continue;
                }

                // Validate email format
                const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
                if (!emailRegex.test(row.Email)) {
                    results.failed++;
                    results.details.failed.push({
                        row: rowNumber,
                        email: row.Email,
                        error: 'Invalid email format'
                    });
                    continue;
                }

                const email = row.Email.toLowerCase().trim();
                const name = row.Name.trim();
                const memberRole = row.Role.toLowerCase().trim();

                // Check if user exists
                const existingUser = await User.findOne({ email });

                // Check if member already exists in this club
                const existingMember = await ClubMember.findOne({ clubId, email });

                if (existingMember) {
                    // Update existing member
                    existingMember.name = name;
                    existingMember.role = memberRole;
                    if (row['Board Type']) existingMember.boardType = row['Board Type'];
                    if (row['Academic Year']) existingMember.academicYear = row['Academic Year'];
                    if (row['Year Joined']) existingMember.joinedAt = new Date(row['Year Joined']);
                    await existingMember.save();

                    results.updated++;
                    results.details.updated.push({
                        name,
                        email,
                        role: memberRole
                    });
                } else {
                    // Add new member
                    const newMember = new ClubMember({
                        clubId,
                        name,
                        email,
                        role: memberRole,
                        boardType: row['Board Type'] || 'member',
                        academicYear: row['Academic Year'] || '',
                        userId: existingUser?._id,
                        joinedAt: row['Year Joined'] ? new Date(row['Year Joined']) : new Date()
                    });
                    await newMember.save();

                    // Auto-assign club-member role if user exists and has 'user' role
                    if (existingUser && existingUser.role === 'user') {
                        existingUser.role = 'club-member';
                        await existingUser.save();
                    }

                    results.added++;
                    results.details.added.push({
                        name,
                        email,
                        role: memberRole
                    });

                    // Send invitation email if user doesn't exist
                    if (!existingUser) {
                        try {
                            const { default: Club } = await import('../models/Club.js');
                            const club = await Club.findById(clubId);
                            const signUpUrl = `${process.env.FRONTEND_URL}?page=signUp&email=${encodeURIComponent(email)}`;

                            const result = await sendClubInvitationEmail({
                                name,
                                email,
                                role: memberRole,
                                clubName: club?.name || 'a club',
                                signUpUrl
                            });

                            if (result.success) {
                                results.emailsSent++;
                            } else {
                                console.error('Failed to send invitation email:', result.error);
                            }
                        } catch (emailError) {
                            console.error('Error sending invitation email:', emailError);
                            // Don't fail the import if email fails
                        }
                    }
                }
            } catch (error) {
                console.error(`Error processing row ${rowNumber}:`, error);
                results.failed++;
                results.details.failed.push({
                    row: rowNumber,
                    email: row.Email || 'N/A',
                    error: error.message || 'Unknown error'
                });
            }
        }

        res.json({
            success: true,
            message: 'Bulk import completed',
            summary: {
                total: results.total,
                added: results.added,
                updated: results.updated,
                failed: results.failed,
                emailsSent: results.emailsSent
            },
            details: results.details
        });

    } catch (error) {
        console.error('Bulk import error:', error);
        res.status(500).json({
            message: 'Failed to import members',
            error: error.message
        });
    }
});

// Export members to Excel
router.get('/:clubId/members/export', verifyToken, async (req, res) => {
    try {
        const { clubId } = req.params;
        const { id: userId, role } = req.user;

        // Check authorization - only club officer or admin
        if (role !== 'admin') {
            const officer = await ClubMember.findOne({
                clubId,
                userId,
                role: { $in: ['Secretary', 'President', 'Treasurer', 'Advisor'] }
            });
            if (!officer) {
                return res.status(403).json({ message: 'Unauthorized to export members for this club' });
            }
        }

        const members = await ClubMember.find({ clubId });
        
        const workbook = new ExcelJS.Workbook();
        const worksheet = workbook.addWorksheet('Members');
        
        worksheet.columns = [
            { header: 'Name', key: 'name', width: 20 },
            { header: 'Email', key: 'email', width: 30 },
            { header: 'Role', key: 'role', width: 15 },
            { header: 'Board Type', key: 'boardType', width: 15 },
            { header: 'Academic Year', key: 'academicYear', width: 15 },
            { header: 'Year Joined', key: 'joinedAt', width: 15 }
        ];
        
        members.forEach(member => {
            worksheet.addRow({
                name: member.name || '',
                email: member.email || '',
                role: member.role || '',
                boardType: member.boardType || '',
                academicYear: member.academicYear || '',
                joinedAt: member.joinedAt ? new Date(member.joinedAt).getFullYear() : ''
            });
        });
        
        res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        res.setHeader('Content-Disposition', 'attachment; filename=members.xlsx');
        
        await workbook.xlsx.write(res);
        res.end();
    } catch (error) {
        console.error('Export error:', error);
        if (!res.headersSent) {
            res.status(500).json({ message: 'Failed to export members', error: error.message });
        }
    }
});

// Download members template
router.get('/template/members', async (req, res) => {
    try {
        const workbook = new ExcelJS.Workbook();
        const worksheet = workbook.addWorksheet('Template');
        
        worksheet.columns = [
            { header: 'Name', key: 'name', width: 20 },
            { header: 'Email', key: 'email', width: 30 },
            { header: 'Role', key: 'role', width: 15 },
            { header: 'Board Type', key: 'boardType', width: 15 },
            { header: 'Academic Year', key: 'academicYear', width: 15 },
            { header: 'Year Joined', key: 'joinedAt', width: 15 }
        ];
        
        worksheet.addRow({
            name: 'John Doe',
            email: 'john@example.com',
            role: 'member',
            boardType: 'member',
            academicYear: 'SY',
            joinedAt: '2023'
        });
        worksheet.addRow({
            name: 'Jane Smith',
            email: 'jane@example.com',
            role: 'club-secretary',
            boardType: 'core',
            academicYear: 'TY',
            joinedAt: '2022'
        });
        
        res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        res.setHeader('Content-Disposition', 'attachment; filename=template.xlsx');
        
        await workbook.xlsx.write(res);
        res.end();
    } catch (error) {
        console.error('Template error:', error);
        res.status(500).json({ message: 'Failed to download template', error: error.message });
    }
});

export default router;

