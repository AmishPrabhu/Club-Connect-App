import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/app_utils.dart';

import '../models/user_session.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import '../services/cloudinary_service.dart';
import '../widgets/animated_otp_input.dart';
import 'user_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final session = widget.appState.session;

    if (session == null) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: _GuestCard(appState: widget.appState),
            ),
          ),
        ],
      );
    }

    if (session.role == 'admin') {
      return DashboardScreen(appState: widget.appState);
    }

    if (session.role == 'teacher' || session.roles.contains('teacher')) {
      return DashboardScreen(appState: widget.appState, initialRole: 'teacher');
    }

    return UserDashboardScreen(
      appState: widget.appState,
      onOpenProfileSettings: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfileSettingsScreen(appState: widget.appState),
          ),
        );
      },
    );
  }
}

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Profile & Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _ProfileBody(appState: appState),
      ),
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({required this.appState});

  final AppState appState;

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _isUploading = true;
      });
      final file = File(pickedFile.path);
      final imageUrl = await CloudinaryService.uploadImage(file);
      if (imageUrl != null) {
        try {
          await widget.appState.updateProfile(
            name: widget.appState.session!.name,
            profileImage: imageUrl,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile picture updated!')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to save profile picture: $e')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image.')),
          );
        }
      }
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _deleteProfilePicture() async {
    setState(() {
      _isUploading = true;
    });
    try {
      await widget.appState.deleteProfileImage();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture deleted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete profile picture: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _confirmDeleteProfilePicture() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Profile Picture?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: const Text(
          'Are you sure you want to remove your profile picture?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteProfilePicture();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showProfileImageOptions(UserSession session) {
    final hasImage = session.profileImage != null && session.profileImage!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Profile Picture',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2E1065) : const Color(0xFFF5F3FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: Color(0xFF7C3AED),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    hasImage ? 'Edit / Change Picture' : 'Upload Picture',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    hasImage ? 'Choose a new photo from gallery' : 'Choose a photo from gallery',
                    style: TextStyle(fontSize: 12, color: AppTheme.mutedColor(context)),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickAndUploadImage();
                  },
                ),
                if (hasImage) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 22,
                      ),
                    ),
                    title: const Text(
                      'Delete Picture',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                      ),
                    ),
                    subtitle: Text(
                      'Remove your current profile picture',
                      style: TextStyle(fontSize: 12, color: AppTheme.mutedColor(context)),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _confirmDeleteProfilePicture();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }


  void _showEditProfileDialog(String currentName) {
    final nameController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Edit Profile Details', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(dialogContext).colorScheme.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter your name',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name cannot be empty.')),
                  );
                  return;
                }
                try {
                  await widget.appState.updateProfile(
                    name: newName,
                    profileImage: widget.appState.session!.profileImage,
                  );
                  if (mounted) {
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile updated successfully!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update profile: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showNotificationSettingsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return ListenableBuilder(
          listenable: widget.appState,
          builder: (context, _) {
            return _NotificationSettingsSheet(appState: widget.appState);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.appState.session;
    if (session == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: widget.appState.refreshAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            _buildCenteredAvatar(session),
            const SizedBox(height: 16),
            Text(
              session.name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            if (session.role.isNotEmpty && session.role.toLowerCase() != 'user')
              _buildCenteredRoleBadge(session.role),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session.email,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.mutedColor(context),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.verified_rounded,
                  size: 14,
                  color: Color(0xFF10B981),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildProfileLinkTile(
              title: 'Edit Profile',
              subtitle: 'Update your personal information',
              icon: Icons.person_outline_rounded,
              iconColor: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFF5F3FF),
              onTap: () => _showEditProfileDialog(session.name),
            ),
            const SizedBox(height: 16),
            _buildProfileLinkTile(
              title: 'Account Settings',
              subtitle: 'Change password, delete account',
              icon: Icons.settings_outlined,
              iconColor: AppTheme.accent(context),
              bgColor: const Color(0xFFEFF6FF),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AccountSettingsScreen(appState: widget.appState),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildProfileLinkTile(
              title: 'Notification Settings',
              subtitle: 'Manage notification preferences',
              icon: Icons.notifications_none_rounded,
              iconColor: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
              onTap: _showNotificationSettingsDialog,
            ),
            const SizedBox(height: 16),
            _buildLogoutTile(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredAvatar(UserSession session) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = session.profileImage != null && session.profileImage!.isNotEmpty;
    return GestureDetector(
      onTap: _isUploading ? null : () => _showProfileImageOptions(session),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2E1065) : const Color(0xFFEDE9FE),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFC084FC), width: 2),
              image: hasImage
                  ? DecorationImage(
                      image: NetworkImage(session.profileImage!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: !hasImage
                ? Center(
                    child: Text(
                      session.name.isNotEmpty ? session.name[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFD8B4FE) : const Color(0xFF6D28D9),
                      ),
                    ),
                  )
                : null,
          ),
          if (_isUploading)
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                hasImage ? Icons.edit_rounded : Icons.camera_alt_rounded,
                size: 16,
                color: isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7C3AED),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredRoleBadge(String role) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E1065) : const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF581C87) : const Color(0xFFDDD6FE), width: 1),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7C3AED),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildProfileLinkTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Theme.of(context).dividerColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.015),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkElevated : bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
                  ),
                  child: Icon(icon, color: isDark ? Colors.white : iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.mutedColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppTheme.mutedColor(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutTile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D0E0E) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF3F1B1B) : const Color(0xFFFEE2E2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text(
                  'Logout',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: const Text('Are you sure you want to sign out?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      HapticFeedback.mediumImpact();
                      final appState = widget.appState;
                      final navigator = Navigator.of(context);
                      if (navigator.canPop()) navigator.pop();
                      appState.logout();
                    },
                    child: const Text('Logout'),
                  ),
                ],
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D1414) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    border: isDark ? Border.all(color: const Color(0xFF3F1B1B)) : null,
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: isDark ? Colors.white : const Color(0xFFEF4444),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sign out from your account',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFF87171),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white30 : const Color(0xFFF87171).withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Account Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              _buildSettingsTile(
                title: 'Change Password',
                subtitle: 'Update your password',
                icon: Icons.lock_outline_rounded,
                iconColor: AppTheme.accent(context),
                bgColor: const Color(0xFFEFF6FF),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangePasswordScreen(appState: widget.appState),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildDeleteAccountTile(),
              const SizedBox(height: 16),
              _buildSettingsTile(
                title: 'Privacy & Security',
                subtitle: 'Manage your privacy settings',
                icon: Icons.shield_outlined,
                iconColor: AppTheme.accent(context),
                bgColor: const Color(0xFFEFF6FF),
                onTap: _showPrivacyDialog,
              ),
              const SizedBox(height: 16),
              _buildSettingsTile(
                title: 'App Information',
                subtitle: 'Version ${widget.appState.appVersion}',
                icon: Icons.info_outline_rounded,
                iconColor: AppTheme.accent(context),
                bgColor: const Color(0xFFEFF6FF),
                onTap: _showAppInfoDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Theme.of(context).dividerColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.015),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? bgColor.withValues(alpha: 0.15) : bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navyColor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.mutedColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).dividerColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountTile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor(context), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.015),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DeleteAccountScreen(appState: widget.appState),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D1414) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: isDark ? Border.all(color: const Color(0xFF3F1B1B)) : null,
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: isDark ? Colors.white : const Color(0xFFEF4444),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delete Account',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Permanently delete your account',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFF87171),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white30 : const Color(0xFFF87171).withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Privacy & Security', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: const Text(
          'Your account security is our priority. We encrypt all data in transit and at rest. You can manage authorization states and view active devices from this device.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _showAppInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('App Information', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Club Connect Mobile App', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Version ${widget.appState.appVersion}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            const Text('WCE Technical Societies Platform • 2026', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isLoadingOtp = false;
  bool _isChanging = false;
  bool _otpSent = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _changeSuccess = false;
  int _otpAttempts = 0;
  static const int _maxOtpAttempts = 3;
  String? _changeError;

  Timer? _resendTimer;
  int _resendSeconds = 0;
  int _resendCount = 0;
  static const int _maxResends = 5;

  @override
  void initState() {
    super.initState();
    _checkPersistentOtpLock();
  }

  void _checkPersistentOtpLock() async {
    final remaining = await OtpLockManager.getRemainingLockSeconds('change_pass');
    final count = await OtpLockManager.getResendCount('change_pass');
    if (mounted) {
      setState(() {
        _resendCount = count;
        if (remaining > 0) {
          _resendSeconds = remaining;
          _startResendTimer();
        }
      });
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _validateFields() {
    final cur = _currentPasswordController.text;
    final nw = _newPasswordController.text;
    final conf = _confirmPasswordController.text;
    if (cur.isEmpty || nw.isEmpty || conf.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all password fields.')),
      );
      return false;
    }
    if (nw.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password must be at least 8 characters.')),
      );
      return false;
    }
    if (nw != conf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match.')),
      );
      return false;
    }
    if (nw == cur) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password must be different from your current password.')),
      );
      return false;
    }
    return true;
  }

  void _scrollToBottom() {
    void doScroll() {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => doScroll());
    Future.delayed(const Duration(milliseconds: 150), doScroll);
    Future.delayed(const Duration(milliseconds: 350), doScroll);
    Future.delayed(const Duration(milliseconds: 600), doScroll);
  }

  void _startResendTimer() {
    setState(() => _resendSeconds = 15);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _requestOtp() async {
    FocusScope.of(context).unfocus();
    if (!_validateFields()) return;
    if (_resendCount >= _maxResends) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum resend limit reached (5/5). Please try again in 15 minutes.')),
      );
      return;
    }
    setState(() => _isLoadingOtp = true);
    try {
      await widget.appState.requestChangePasswordOtp(
        currentPassword: _currentPasswordController.text,
      );
      if (mounted) {
        _otpController.clear();
        final newCount = await OtpLockManager.incrementResendCount('change_pass');
        setState(() {
          _otpSent = true;
          _otpAttempts = 0;
          _resendCount = newCount;
        });
        _startResendTimer();
        _scrollToBottom();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification code sent to your email. (${_resendCount}/$_maxResends)')),
        );
      }
    } catch (error) {
      final msg = error.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
      final isRateLimited = msg.toLowerCase().contains('too many') || msg.toLowerCase().contains('limit');
      if (isRateLimited) {
        await OtpLockManager.lockFlow('change_pass');
      }
      if (mounted) {
        if (isRateLimited) {
          setState(() {
            _resendCount = _maxResends;
            _resendSeconds = 15 * 60;
            _startResendTimer();
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingOtp = false);
    }
  }

  Future<void> _handleChangePassword() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the verification code.')),
      );
      return;
    }
    setState(() {
      _isChanging = true;
      _changeError = null;
      _changeSuccess = false;
    });
    try {
      await widget.appState.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        otp: otp,
      );
      if (mounted) {
        setState(() => _changeSuccess = true);
        await Future.delayed(const Duration(milliseconds: 1800));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully.')),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        final newAttempts = _otpAttempts + 1;
        if (newAttempts >= _maxOtpAttempts) {
          setState(() {
            _otpAttempts = 0;
            _otpSent = false;
            _changeError = null;
            _otpController.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Too many incorrect OTP attempts. Please request a new code.')),
          );
        } else {
          setState(() {
            _otpAttempts = newAttempts;
            _changeError = error.toString();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isChanging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'Change Password',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              36 + MediaQuery.of(context).viewInsets.bottom,
            ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update Password',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your current and new password, then verify with a code sent to your email.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: const Icon(Icons.lock_open_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
              ),
              PasswordStrengthIndicator(
                password: _newPasswordController.text,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: (_isLoadingOtp || _resendSeconds > 0 || _resendCount >= _maxResends) ? null : _requestOtp,
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: _isLoadingOtp
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_resendCount >= _maxResends
                          ? 'Resend limit reached (5/5)'
                          : _resendSeconds > 0 
                              ? 'Resend Code in ${_resendSeconds}s'
                              : _otpSent
                                  ? 'Resend Verification Code'
                                  : 'Send Verification Code'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: 24),
                Text(
                  'Enter Verification Code',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedOtpInput(
                  controller: _otpController,
                  length: 6,
                  isVerifying: _isChanging,
                  isError: _changeError != null,
                  isSuccess: _changeSuccess,
                  onFocus: _scrollToBottom,
                  onChanged: (code) {
                    if (_changeError != null) setState(() => _changeError = null);
                  },
                  onCompleted: (code) {
                    if (!_isChanging) {
                      _handleChangePassword();
                    }
                  },
                ),
                if (_changeError != null && _otpAttempts > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFB91C1C)),
                        const SizedBox(width: 4),
                        Text(
                          _maxOtpAttempts - _otpAttempts == 1
                              ? '1 more try remaining'
                              : '${_maxOtpAttempts - _otpAttempts} more tries remaining',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isChanging ? null : _handleChangePassword,
                    child: _isChanging
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Update Password',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
}




class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _deleteOtpController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoadingOtp = false;
  bool _isDeleting = false;
  bool _otpSent = false;
  bool _otpError = false;
  int _otpAttempts = 0;
  static const int _maxOtpAttempts = 3;

  Timer? _resendTimer;
  int _resendSeconds = 0;
  int _resendCount = 0;
  static const int _maxResends = 5;

  @override
  void initState() {
    super.initState();
    _checkPersistentOtpLock();
  }

  void _checkPersistentOtpLock() async {
    final remaining = await OtpLockManager.getRemainingLockSeconds('delete_account');
    final count = await OtpLockManager.getResendCount('delete_account');
    if (mounted) {
      setState(() {
        _resendCount = count;
        if (remaining > 0) {
          _resendSeconds = remaining;
          _startResendTimer();
        }
      });
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _deleteOtpController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'Delete Account',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              36 + MediaQuery.of(context).viewInsets.bottom,
            ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Danger Zone',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Once you delete your account, all your data will be permanently removed. There is no going back. Please be certain.',
                style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: (_isLoadingOtp || _resendSeconds > 0 || _resendCount >= _maxResends) ? null : _requestOtp,
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: _isLoadingOtp
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
                        )
                      : Text(_resendCount >= _maxResends
                          ? 'Resend limit reached (5/5)'
                          : _resendSeconds > 0 
                              ? 'Resend Code in ${_resendSeconds}s'
                              : _otpSent
                                  ? 'Resend Verification Code'
                                  : 'Request Verification Code'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: 24),
                Text(
                  'Enter Verification Code',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 12),
                AnimatedOtpInput(
                  controller: _deleteOtpController,
                  length: 6,
                  isVerifying: _isDeleting,
                  isError: _otpError,
                  onFocus: _scrollToBottom,
                  onChanged: (_) {
                    if (_otpError) setState(() => _otpError = false);
                  },
                  onCompleted: (code) {
                    if (!_isDeleting) {
                      _deleteAccount();
                    }
                  },
                ),
                if (_otpError && _otpAttempts > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFB91C1C)),
                        const SizedBox(width: 4),
                        Text(
                          _maxOtpAttempts - _otpAttempts == 1
                              ? '1 more try remaining'
                              : '${_maxOtpAttempts - _otpAttempts} more tries remaining',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isDeleting ? null : _deleteAccount,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isDeleting
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Delete My Account Permanently', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

  void _scrollToBottom() {
    void doScroll() {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => doScroll());
    Future.delayed(const Duration(milliseconds: 150), doScroll);
    Future.delayed(const Duration(milliseconds: 350), doScroll);
    Future.delayed(const Duration(milliseconds: 600), doScroll);
  }

  void _startResendTimer() {
    setState(() => _resendSeconds = 15);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _requestOtp() async {
    FocusScope.of(context).unfocus();
    if (_resendCount >= _maxResends) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum resend limit reached (5/5). Please try again in 15 minutes.')),
      );
      return;
    }
    setState(() {
      _isLoadingOtp = true;
    });

    try {
      await widget.appState.requestDeleteOtp();
      if (mounted) {
        _deleteOtpController.clear();
        final newCount = await OtpLockManager.incrementResendCount('delete_account');
        setState(() {
          _otpSent = true;
          _otpAttempts = 0;
          _otpError = false;
          _resendCount = newCount;
        });
        _startResendTimer();
        _scrollToBottom();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification code sent to your email. (${_resendCount}/$_maxResends)')),
        );
      }
    } catch (error) {
      final msg = error.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
      final isRateLimited = msg.toLowerCase().contains('too many') || msg.toLowerCase().contains('limit');
      if (isRateLimited) {
        await OtpLockManager.lockFlow('delete_account');
      }
      if (mounted) {
        if (isRateLimited) {
          setState(() {
            _resendCount = _maxResends;
            _resendSeconds = 15 * 60;
            _startResendTimer();
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOtp = false;
        });
      }
    }
  }

  Future<void> _deleteAccount() async {
    final otp = _deleteOtpController.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the verification code.')),
      );
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await widget.appState.deleteAccount(otp);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted.')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      if (mounted) {
        final newAttempts = _otpAttempts + 1;
        if (newAttempts >= _maxOtpAttempts) {
          setState(() {
            _otpAttempts = 0;
            _otpSent = false;
            _otpError = false;
            _deleteOtpController.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Too many incorrect attempts. Please request a new verification code.')),
          );
        } else {
          setState(() {
            _otpAttempts = newAttempts;
            _otpError = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Profile', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 12),
          Text(
            'Sign in to access your dashboard, account settings, and features.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LoginScreen(appState: appState),
                ),
              ),
              child: const Text('Sign In'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SignupScreen(appState: appState),
                ),
              ),
              child: const Text('Create Account'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSettingsSheet extends StatefulWidget {
  const _NotificationSettingsSheet({required this.appState});

  final AppState appState;

  @override
  State<_NotificationSettingsSheet> createState() => _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<_NotificationSettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = appState.notificationsEnabled;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notification Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage push & app alert preferences',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.mutedColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Master Enable / Disable Notifications Tile
            Container(
              decoration: BoxDecoration(
                color: isEnabled
                    ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5))
                    : (isDark ? AppTheme.darkElevated : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isEnabled
                      ? const Color(0xFF10B981).withValues(alpha: 0.5)
                      : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                  width: 1.5,
                ),
              ),
              child: SwitchListTile(
                value: isEnabled,
                onChanged: (value) async {
                  HapticFeedback.selectionClick();
                  await appState.setNotificationsEnabled(value);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value ? 'Notifications Enabled' : 'Notifications Disabled',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: value ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                activeColor: const Color(0xFF10B981),
                title: Text(
                  'Allow Notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  isEnabled
                      ? 'Push & banner alerts are enabled'
                      : 'All push & floating alerts are turned off',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mutedColor(context),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (isEnabled) ...[
              Text(
                'Notification Categories',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.mutedColor(context),
                ),
              ),
              const SizedBox(height: 10),

              // Event & Activity Alerts
              _buildCategorySwitch(
                context: context,
                title: 'Event & Activity Alerts',
                subtitle: 'Reminders for upcoming events and RSVPs',
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                value: appState.eventAlertsEnabled,
                onChanged: (val) => appState.setEventAlertsEnabled(val),
              ),
              const SizedBox(height: 10),

              // Club Announcements
              _buildCategorySwitch(
                context: context,
                title: 'Club Announcements',
                subtitle: 'News, announcements and club updates',
                icon: Icons.campaign_rounded,
                iconColor: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFF5F3FF),
                value: appState.clubAnnouncementsEnabled,
                onChanged: (val) => appState.setClubAnnouncementsEnabled(val),
              ),
              const SizedBox(height: 10),

              // Task & Duty Alerts
              _buildCategorySwitch(
                context: context,
                title: 'Task & Duty Alerts',
                subtitle: 'Updates on assigned club tasks and deadlines',
                icon: Icons.checklist_rounded,
                iconColor: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFFFBEB),
                value: appState.taskAlertsEnabled,
                onChanged: (val) => appState.setTaskAlertsEnabled(val),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navyColor(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySwitch({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkElevated : bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: isDark ? Colors.white : iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: AppTheme.mutedColor(context)),
        ),
        trailing: Switch(
          value: value,
          onChanged: (val) {
            HapticFeedback.selectionClick();
            onChanged(val);
          },
          activeColor: const Color(0xFF10B981),
        ),
      ),
    );
  }
}
