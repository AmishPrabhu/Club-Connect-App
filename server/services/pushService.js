import { getMessaging } from 'firebase-admin/messaging';
import User from '../models/User.js';
import ClubMember from '../models/ClubMember.js';

/**
 * Send push notification to a list of user IDs
 * @param {Array<string>} userIds 
 * @param {string} title 
 * @param {string} body 
 * @param {Object} dataPayload 
 */
export async function sendPushToUsers(userIds, title, body, dataPayload = {}) {
    try {
        const users = await User.find({ 
            _id: { $in: userIds }, 
            fcmTokens: { $exists: true, $ne: [] } 
        }).select('fcmTokens');
        
        const tokens = users.flatMap(u => u.fcmTokens || []);
        if (tokens.length === 0) return;
        
        await sendMulticast(tokens, title, body, dataPayload);
    } catch (err) {
        console.error("Error in sendPushToUsers:", err);
    }
}

/**
 * Send push notification to all members of a specific club
 * @param {string} clubId 
 * @param {string} title 
 * @param {string} body 
 * @param {Object} dataPayload 
 */
export async function sendPushToClubMembers(clubId, title, body, dataPayload = {}) {
    try {
        const memberships = await ClubMember.find({ clubId }).select('userId email');
        const userIds = memberships.map(m => m.userId).filter(Boolean);
        
        // Find users by email as fallback (if userId isn't populated on ClubMember yet)
        const emails = memberships.map(m => m.email).filter(Boolean);
        const usersByEmail = await User.find({ email: { $in: emails } }).select('_id');
        usersByEmail.forEach(u => {
            const uidStr = u._id.toString();
            if (!userIds.includes(uidStr)) {
                userIds.push(uidStr);
            }
        });

        if (userIds.length === 0) return;

        await sendPushToUsers(userIds, title, body, dataPayload);
    } catch (err) {
        console.error("Error in sendPushToClubMembers:", err);
    }
}

/**
 * Send push notification globally to all registered devices
 * @param {string} title 
 * @param {string} body 
 * @param {Object} dataPayload 
 */
export async function sendPushGlobal(title, body, dataPayload = {}) {
    try {
        const users = await User.find({ 
            fcmTokens: { $exists: true, $ne: [] } 
        }).select('fcmTokens');
        
        const tokens = users.flatMap(u => u.fcmTokens || []);
        if (tokens.length === 0) return;

        await sendMulticast(tokens, title, body, dataPayload);
    } catch (err) {
        console.error("Error in sendPushGlobal:", err);
    }
}

/**
 * Send multicast notification helper
 * @param {Array<string>} tokens 
 * @param {string} title 
 * @param {string} body 
 * @param {Object} dataPayload 
 */
async function sendMulticast(tokens, title, body, dataPayload) {
    // Stringify payload values to meet Firebase Admin SDK requirements (all values must be strings)
    const sanitizedData = {};
    for (const [key, val] of Object.entries(dataPayload)) {
        if (val !== undefined && val !== null) {
            sanitizedData[key] = val.toString();
        }
    }

    const message = {
        data: sanitizedData,
        tokens: tokens,
    };

    if (title || body) {
        message.notification = {
            title: title || '',
            body: body || '',
        };
    }

    try {
        const response = await getMessaging().sendEachForMulticast(message);
        console.log(`FCM Multicast: ${response.successCount} sent successfully, ${response.failureCount} failed.`);
        
        // Clean up invalid/inactive tokens (uninstalled apps, etc.)
        if (response.failureCount > 0) {
            const tokensToRemove = [];
            response.responses.forEach((resp, idx) => {
                if (!resp.success) {
                    const code = resp.error?.code;
                    if (
                        code === 'messaging/invalid-registration-token' || 
                        code === 'messaging/registration-token-not-registered'
                    ) {
                        tokensToRemove.push(tokens[idx]);
                    }
                }
            });
            
            if (tokensToRemove.length > 0) {
                await User.updateMany(
                    { fcmTokens: { $in: tokensToRemove } },
                    { $pull: { fcmTokens: { $in: tokensToRemove } } }
                );
                console.log(`Cleaned up ${tokensToRemove.length} inactive FCM tokens from DB.`);
            }
        }
    } catch (error) {
        console.error("Error running FCM multicast:", error);
    }
}
