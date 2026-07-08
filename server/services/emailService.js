import Brevo from '@getbrevo/brevo';

// Initialize Brevo API client lazily
let apiInstance = null;

function getBrevoClient() {
    if (!apiInstance) {
        const apiKey = process.env.BREVO_API_KEY ? process.env.BREVO_API_KEY.trim() : null;
        if (!apiKey) {
            console.warn('⚠️ BREVO_API_KEY not configured - emails will not be sent');
            return null;
        }

        apiInstance = new Brevo.TransactionalEmailsApi();
        apiInstance.setApiKey(Brevo.TransactionalEmailsApiApiKeys.apiKey, apiKey);
        console.log('✅ Brevo email client initialized');
    }
    return apiInstance;
}

/**
 * Send an email using Brevo
 */
export async function sendEmail({ to, subject, html }) {
    try {
        const client = getBrevoClient();
        if (!client) {
            console.warn('📧 Email not sent (Brevo not configured):', to);
            return { success: false, error: 'Email service not configured' };
        }



        const sendSmtpEmail = new Brevo.SendSmtpEmail();
        sendSmtpEmail.subject = subject;
        sendSmtpEmail.htmlContent = html;
        sendSmtpEmail.sender = {
            name: 'Club Connect',
            email: (process.env.EMAIL_USER || 'noreply@clubconnect.com').trim()
        };
        sendSmtpEmail.to = [{ email: to }];

        const result = await client.sendTransacEmail(sendSmtpEmail);

        return { success: true, messageId: result?.body?.messageId };
    } catch (err) {
        console.error('❌ Email send failed:', err.message || err);
        return { success: false, error: err.message || 'Unknown error' };
    }
}

/**
 * Send password reset email
 */
export async function sendPasswordResetEmail(user, resetToken) {
    return sendEmail({
        to: user.email,
        subject: 'Password Reset Code - Club Connect',
        html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <div style="background: #002147; padding: 20px; text-align: center;">
                    <h1 style="color: #DAA520; margin: 0;">Club Connect</h1>
                </div>
                <div style="padding: 30px; background: #f9f9f9;">
                    <h2 style="color: #002147;">Password Reset Verification Code</h2>
                    <p>Hello ${user.name},</p>
                    <p>We received a request to reset your password. Use the following 6-digit verification code to complete the reset inside the app:</p>
                    <div style="text-align: center; margin: 30px 0; background: #eee; padding: 15px; border-radius: 8px; font-size: 24px; font-weight: bold; letter-spacing: 2px; color: #002147;">
                        ${resetToken}
                    </div>
                    <p style="color: #666; font-size: 14px;">This code will expire in 1 hour.</p>
                    <p style="color: #666; font-size: 14px;">If you didn't request this, please ignore this email.</p>
                </div>
                <div style="background: #002147; padding: 15px; text-align: center;">
                    <p style="color: #888; font-size: 12px; margin: 0;">© ${new Date().getFullYear()} Club Connect - Walchand College of Engineering</p>
                </div>
            </div>
        `,
    });
}

/**
 * Send club invitation email
 */
export async function sendClubInvitationEmail({ name, email, role, clubName, signUpUrl }) {
    return sendEmail({
        to: email,
        subject: `You've been added to ${clubName} - Create Your Account`,
        html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <div style="background: #002147; padding: 20px; text-align: center;">
                    <h1 style="color: #DAA520; margin: 0;">Club Connect</h1>
                </div>
                <div style="padding: 30px; background: #f9f9f9;">
                    <h2 style="color: #002147;">Welcome to ${clubName}!</h2>
                    <p>Hello ${name},</p>
                    <p>You've been added as a <strong>${role}</strong> to ${clubName} on Club Connect!</p>
                    <p>To get started, please create your account:</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="${signUpUrl}" style="background: #DAA520; color: #002147; padding: 15px 30px; text-decoration: none; border-radius: 8px; font-weight: bold; display: inline-block;">
                            Create Account
                        </a>
                    </div>
                    <p style="color: #666; font-size: 14px;">Your registered email: ${email}</p>
                    <p style="color: #666; font-size: 14px;">Club: ${clubName}</p>
                    <p style="color: #666; font-size: 14px;">Role: ${role}</p>
                </div>
                <div style="background: #002147; padding: 15px; text-align: center;">
                    <p style="color: #888; font-size: 12px; margin: 0;">© ${new Date().getFullYear()} Club Connect - Walchand College of Engineering</p>
                </div>
            </div>
        `,
    });
}

/**
 * Send teacher invitation email
 */
export async function sendTeacherInvitationEmail({ name, email, signUpUrl }) {
    return sendEmail({
        to: email,
        subject: `You've been assigned a Teacher role - Create Your Account`,
        html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <div style="background: #002147; padding: 20px; text-align: center;">
                    <h1 style="color: #DAA520; margin: 0;">Club Connect</h1>
                </div>
                <div style="padding: 30px; background: #f9f9f9;">
                    <h2 style="color: #002147;">Welcome to Club Connect!</h2>
                    <p>Hello ${name},</p>
                    <p>You've been assigned the <strong>Teacher</strong> role by the administration on Club Connect!</p>
                    <p>To get started and manage your clubs, please create your account:</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="${signUpUrl}" style="background: #DAA520; color: #002147; padding: 15px 30px; text-decoration: none; border-radius: 8px; font-weight: bold; display: inline-block;">
                            Create Account
                        </a>
                    </div>
                    <p style="color: #666; font-size: 14px;">Your registered email: ${email}</p>
                </div>
                <div style="background: #002147; padding: 15px; text-align: center;">
                    <p style="color: #888; font-size: 12px; margin: 0;">© ${new Date().getFullYear()} Club Connect - Walchand College of Engineering</p>
                </div>
            </div>
        `,
    });
}

/**
 * Send OTP for registration
 */
export async function sendOtpEmail(email, otp) {
    return sendEmail({
        to: email,
        subject: 'Verify Your Email - Club Connect',
        html: `
        < div style = "font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;" >
                <div style="background: #002147; padding: 20px; text-align: center;">
                    <h1 style="color: #DAA520; margin: 0;">Club Connect</h1>
                </div>
                <div style="padding: 30px; background: #f9f9f9;">
                    <h2 style="color: #002147;">Verify Your Email</h2>
                    <p>Hello,</p>
                    <p>Use the following One-Time Password (OTP) to complete your registration:</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <span style="font-size: 32px; letter-spacing: 5px; font-weight: bold; color: #002147; background: #e0e7ff; padding: 10px 20px; border-radius: 8px;">
                            ${otp}
                        </span>
                    </div>
                    <p style="color: #666; font-size: 14px;">This OTP is valid for 10 minutes.</p>
                    <p style="color: #666; font-size: 14px;">If you didn't request this code, please ignore this email.</p>
                </div>
                <div style="background: #002147; padding: 15px; text-align: center;">
                    <p style="color: #888; font-size: 12px; margin: 0;">© ${new Date().getFullYear()} Club Connect - Walchand College of Engineering</p>
                </div>
            </div >
        `,
    });
}

/**
 * Send OTP for account deletion
 */
export async function sendDeleteAccountOtpEmail(email, otp) {
    return sendEmail({
        to: email,
        subject: 'Confirm Account Deletion - Club Connect',
        html: `
        < div style = "font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;" >
                 <div style="background: #002147; padding: 20px; text-align: center;">
                     <h1 style="color: #DAA520; margin: 0;">Club Connect</h1>
                 </div>
                 <div style="padding: 30px; background: #fff1f2; border: 1px solid #fecdd3;">
                     <h2 style="color: #991b1b;">Account Deletion Request</h2>
                     <p>Hello,</p>
                     <p>We received a request to permanently delete your Club Connect account. This action <strong>cannot be undone</strong> and all your data will be removed.</p>
                     <p>To confirm this action, please use the following One-Time Password (OTP):</p>
                     <div style="text-align: center; margin: 30px 0;">
                         <span style="font-size: 32px; letter-spacing: 5px; font-weight: bold; color: #991b1b; background: #fff; padding: 10px 20px; border-radius: 8px; border: 2px dashed #991b1b;">
                             ${otp}
                         </span>
                     </div>
                     <p style="color: #666; font-size: 14px;">This OTP is valid for 10 minutes.</p>
                     <p style="color: #666; font-size: 14px;">If you did not request this, please <strong>change your password immediately</strong>.</p>
                 </div>
                 <div style="background: #002147; padding: 15px; text-align: center;">
                     <p style="color: #888; font-size: 12px; margin: 0;">© ${new Date().getFullYear()} Club Connect - Walchand College of Engineering</p>
                 </div>
             </div >
        `,
    });
}

/**
 * Send task assignment email
 */
export async function sendTaskAssignmentEmail({ recipientEmail, recipientName, taskTitle, description, deadline, clubName, assignedBy }) {
    const formattedDeadline = deadline ? new Date(deadline).toLocaleDateString('en-US', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric'
    }) : 'No deadline set';

    return sendEmail({
        to: recipientEmail,
        subject: `New Task Assigned: ${taskTitle} - ${clubName}`,
        html: `
    < div style = "font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;" >
                <div style="background: #002147; padding: 20px; text-align: center;">
                    <h1 style="color: #DAA520; margin: 0;">Club Connect</h1>
                </div>
                <div style="padding: 30px; background: #f9f9f9; border: 1px solid #e2e8f0;">
                    <h2 style="color: #002147; border-bottom: 2px solid #DAA520; padding-bottom: 10px;">New Task Assigned</h2>
                    <p>Hello ${recipientName || 'Team Member'},</p>
                    <p>You have been assigned a new task by <strong>${assignedBy}</strong> for <strong>${clubName}</strong>.</p>
                    
                    <div style="background: #fff; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #002147;">
                        <h3 style="margin-top: 0; color: #002147;">${taskTitle}</h3>
                        <p style="color: #475569;">${description || 'No description provided.'}</p>
                        <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 15px 0;" />
                        <p style="margin-bottom: 0;"><strong>Deadline:</strong> ${formattedDeadline}</p>
                    </div>

                    <p>Please log in to the portal to manage your tasks and update their status.</p>
                    
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="${process.env.FRONTEND_URL}?page=userProfile&tab=tasks" style="background: #002147; color: #DAA520; padding: 12px 25px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block;">
                            View My Tasks
                        </a>
                    </div>
                </div>
                <div style="background: #002147; padding: 15px; text-align: center;">
                    <p style="color: #888; font-size: 12px; margin: 0;">© ${new Date().getFullYear()} Club Connect - Walchand College of Engineering</p>
                </div>
            </div >
        `,
    });
}

/**
 * Send event update email to a single attendee
 */
export async function sendEventUpdateEmail({ recipientEmail, recipientName, eventTitle, updateMessage, clubName }) {
    return sendEmail({
        to: recipientEmail,
        subject: `Update for ${eventTitle} - ${clubName}`,
        html: `
        < div style = "font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;" >
                <div style="background: #002147; padding: 20px; text-align: center;">
                    <h1 style="color: #DAA520; margin: 0;">Club Connect</h1>
                </div>
                <div style="padding: 30px; background: #f9f9f9; border: 1px solid #e2e8f0;">
                    <h2 style="color: #002147; border-bottom: 2px solid #DAA520; padding-bottom: 10px;">Event Update</h2>
                    <p>Hello ${recipientName || 'Attendee'},</p>
                    <p>There is an update regarding the event <strong>${eventTitle}</strong> organized by <strong>${clubName}</strong>.</p>
                    
                    <div style="background: #fff; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #002147;">
                        <p style="color: #475569; white-space: pre-wrap; margin: 0;">${updateMessage}</p>
                    </div>

                    <p>If you have any questions, please contact the club through the portal.</p>
                </div>
                <div style="background: #002147; padding: 15px; text-align: center;">
                    <p style="color: #888; font-size: 12px; margin: 0;">© ${new Date().getFullYear()} Club Connect - Walchand College of Engineering</p>
                </div>
            </div >
        `,
    });
}

/**
 * Send password change confirmation email
 */
export async function sendPasswordChangeEmail({ email, name }) {
    const now = new Date();
    const dateStr = now.toLocaleDateString('en-IN', {
        day: 'numeric',
        month: 'short',
        year: 'numeric'
    });
    const timeStr = now.toLocaleTimeString('en-IN', {
        hour: 'numeric',
        minute: '2-digit',
        hour12: true,
        timeZoneName: 'short'
    });

    const resetUrl = `${process.env.FRONTEND_URL}?page = forgot - password`;

    return sendEmail({
        to: email,
        subject: 'Password Changed - Club Connect',
        html: `
        < div style = "font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;" >
                <div style="background: #002147; padding: 20px; text-align: center;">
                    <h1 style="color: #DAA520; margin: 0;">Club Connect</h1>
                </div>
                <div style="padding: 30px; background: #f9f9f9;">
                    <h2 style="color: #002147;">Password Changed</h2>
                    <p>Hi ${name || 'User'},</p>
                    <p>This is to inform you that your Club-Connect account password was changed on <strong>${dateStr}</strong> at <strong>${timeStr}</strong>.</p>
                    <p>If this was you, no further action is required.</p>
                    <div style="background: #fff3cd; border: 1px solid #ffc107; padding: 15px; border-radius: 8px; margin: 20px 0;">
                        <p style="margin: 0; color: #856404;"><strong>⚠️ If you did not make this change</strong>, please reset your password immediately and contact support.</p>
                        <div style="text-align: center; margin-top: 15px;">
                            <a href="${resetUrl}" style="background: #dc3545; color: #fff; padding: 10px 20px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block;">
                                Reset Password Now
                            </a>
                        </div>
                    </div>
                    <p>Stay safe,<br/><strong>Team Club-Connect</strong></p>
                </div>
                <div style="background: #002147; padding: 15px; text-align: center;">
                    <p style="color: #888; font-size: 12px; margin: 0;">© ${new Date().getFullYear()} Club Connect - Walchand College of Engineering</p>
                </div>
            </div >
        `,
    });
}

export default { sendEmail, sendPasswordResetEmail, sendClubInvitationEmail, sendTeacherInvitationEmail, sendOtpEmail, sendDeleteAccountOtpEmail, sendTaskAssignmentEmail, sendEventUpdateEmail, sendPasswordChangeEmail };
