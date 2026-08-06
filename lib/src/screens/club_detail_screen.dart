import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/club.dart';
import '../models/post_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/cloudinary_service.dart';
import 'member_board_detail_screen.dart';
import 'post_detail_screen.dart';
import '../widgets/member_form_sheet.dart';

class ClubDetailScreen extends StatefulWidget {
  const ClubDetailScreen({
    super.key,
    required this.appState,
    required this.club,
  });

  final AppState appState;
  final Club club;

  @override
  State<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends State<ClubDetailScreen> {
  late Future<List<Map<String, dynamic>>> _membersFuture;
  late Club _club;
  late StreamSubscription<String> _refreshSub;

  @override
  void initState() {
    super.initState();
    _club = widget.club;
    widget.appState.addListener(_onAppStateChanged);
    _refreshMembers();
    _refreshSub = widget.appState.refreshEvents.listen((event) {
      if (event == 'members_${_club.id}') {
        _refreshMembers();
      }
    });
  }

  @override
  void dispose() {
    _refreshSub.cancel();
    widget.appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    setState(() {
      final matches = widget.appState.clubs.where((c) => c.id == _club.id).toList();
      if (matches.isNotEmpty) {
        _club = matches.first;
      }
    });
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _refreshMembers() {
    setState(() {
      _membersFuture = widget.appState.fetchClubMembers(_club.id);
    });
  }

  bool _isUploadingLogo = false;

  Future<void> _updateClubField(Map<String, dynamic> updates) async {
    try {
      final updatedClub = await widget.appState.updateClub(_club.id, updates);
      setState(() {
        _club = updatedClub;
      });
      _showSuccessSnackBar('Club updated successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to update club: $e');
    }
  }

  Future<void> _pickAndUploadLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _isUploadingLogo = true;
      });
      final file = File(pickedFile.path);
      final imageUrl = await CloudinaryService.uploadImage(file);
      if (imageUrl != null) {
        await _updateClubField({'image': imageUrl});
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image.')),
          );
        }
      }
      if (mounted) {
        setState(() {
          _isUploadingLogo = false;
        });
      }
    }
  }

  void _copyLink(String label, String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label link copied to clipboard!')),
    );
  }

  Future<void> _showLinkDialog({required String title, required String fieldKey, required String currentValue}) async {
    final controller = TextEditingController(text: currentValue);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter URL (e.g., https://...)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _updateClubField({fieldKey: controller.text.trim()});
    }
  }

  Future<void> _showTextDialog({required String title, required String fieldKey, required String currentValue, int maxLines = 1}) async {
    final controller = TextEditingController(text: currentValue);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final text = controller.text.trim();
      if (fieldKey == 'name' && text.isEmpty) {
        _showErrorSnackBar('Club name cannot be empty');
        return;
      }
      await _updateClubField({fieldKey: text});
    }
  }

  Widget _buildProfilePictureCard(bool isOfficer) {
    if (!isOfficer) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image_outlined, color: AppTheme.textColor(context), size: 20),
              const SizedBox(width: 8),
              Text(
                'Club Profile Picture',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBg(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: _isUploadingLogo
                      ? const Center(child: CircularProgressIndicator())
                      : _club.imageAsset.isNotEmpty
                          ? _club.imageAsset.startsWith('http')
                              ? Image.network(_club.imageAsset, fit: BoxFit.contain)
                              : Image.asset(
                                  _club.imageAsset.startsWith('/')
                                      ? 'assets/images${_club.imageAsset}'
                                      : _club.imageAsset,
                                  fit: BoxFit.contain,
                                )
                          : const Icon(Icons.groups_rounded, size: 48, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isUploadingLogo ? null : _pickAndUploadLogo,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Upload from Device'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent(context),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Supports JPG, PNG, GIF, WebP (max 5MB)',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchExternalUrl(String rawUrl) async {
    String url = rawUrl.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar('Could not launch URL');
      }
    } catch (e) {
      _showErrorSnackBar('Could not launch URL: $e');
    }
  }

  Widget _buildLinkActionButton({
    required String label,
    required String url,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _launchExternalUrl(url),
        icon: Icon(icon, size: 20),
        label: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Icon(Icons.open_in_new_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatsAppCard(bool isOfficer) {
    final hasLink = _club.whatsappUrl.isNotEmpty;
    if (!hasLink && !isOfficer) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.textColor(context), size: 20),
              const SizedBox(width: 8),
              Text(
                'WhatsApp Community',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (hasLink && isOfficer) ...[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _showLinkDialog(
                    title: 'Edit WhatsApp Link',
                    fieldKey: 'whatsappUrl',
                    currentValue: _club.whatsappUrl,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  onPressed: () => _updateClubField({'whatsappUrl': ''}),
                ),
              ]
            ],
          ),
          const SizedBox(height: 12),
          if (hasLink)
            _buildLinkActionButton(
              label: 'Open WhatsApp Group',
              url: _club.whatsappUrl,
              icon: Icons.chat_bubble_outline_rounded,
              color: const Color(0xFF25D366),
            )
          else if (isOfficer)
            GestureDetector(
              onTap: () => _showLinkDialog(
                title: 'Add WhatsApp Link',
                fieldKey: 'whatsappUrl',
                currentValue: '',
              ),
              child: CustomPaint(
                painter: DashedBorderPainter(color: Theme.of(context).dividerColor, gap: 6),
                child: Container(
                  height: 48,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Colors.grey, size: 18),
                      SizedBox(width: 6),
                      Text('Add WhatsApp Link', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInstagramCard(bool isOfficer) {
    final hasLink = _club.instagramUrl.isNotEmpty;
    if (!hasLink && !isOfficer) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.camera_alt_outlined, color: AppTheme.textColor(context), size: 20),
              const SizedBox(width: 8),
              Text(
                'Instagram Page',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (hasLink && isOfficer) ...[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _showLinkDialog(
                    title: 'Edit Instagram Page Link',
                    fieldKey: 'instagramUrl',
                    currentValue: _club.instagramUrl,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  onPressed: () => _updateClubField({'instagramUrl': ''}),
                ),
              ]
            ],
          ),
          const SizedBox(height: 12),
          if (hasLink)
            _buildLinkActionButton(
              label: 'Open Instagram Page',
              url: _club.instagramUrl,
              icon: Icons.camera_alt_outlined,
              color: const Color(0xFFE1306C),
            )
          else if (isOfficer)
            GestureDetector(
              onTap: () => _showLinkDialog(
                title: 'Add Instagram Page',
                fieldKey: 'instagramUrl',
                currentValue: '',
              ),
              child: CustomPaint(
                painter: DashedBorderPainter(color: Theme.of(context).dividerColor, gap: 6),
                child: Container(
                  height: 48,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Colors.grey, size: 18),
                      SizedBox(width: 6),
                      Text('Add Instagram Page', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLinkedinCard(bool isOfficer) {
    final hasLink = _club.linkedinUrl.isNotEmpty;
    if (!hasLink && !isOfficer) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.work_outline_rounded, color: AppTheme.textColor(context), size: 20),
              const SizedBox(width: 8),
              Text(
                'LinkedIn Page',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (hasLink && isOfficer) ...[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _showLinkDialog(
                    title: 'Edit LinkedIn Page Link',
                    fieldKey: 'linkedinUrl',
                    currentValue: _club.linkedinUrl,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  onPressed: () => _updateClubField({'linkedinUrl': ''}),
                ),
              ]
            ],
          ),
          const SizedBox(height: 12),
          if (hasLink)
            _buildLinkActionButton(
              label: 'Open LinkedIn Page',
              url: _club.linkedinUrl,
              icon: Icons.work_outline_rounded,
              color: const Color(0xFF0A66C2),
            )
          else if (isOfficer)
            GestureDetector(
              onTap: () => _showLinkDialog(
                title: 'Add LinkedIn Link',
                fieldKey: 'linkedinUrl',
                currentValue: '',
              ),
              child: CustomPaint(
                painter: DashedBorderPainter(color: Theme.of(context).dividerColor, gap: 6),
                child: Container(
                  height: 48,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Colors.grey, size: 18),
                      SizedBox(width: 6),
                      Text('Add LinkedIn Link', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebsiteCard(bool isOfficer) {
    final hasLink = _club.websiteUrl.isNotEmpty;
    if (!hasLink && !isOfficer) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.language_rounded, color: AppTheme.textColor(context), size: 20),
              const SizedBox(width: 8),
              Text(
                'Website',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (hasLink && isOfficer) ...[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _showLinkDialog(
                    title: 'Edit Website Link',
                    fieldKey: 'websiteUrl',
                    currentValue: _club.websiteUrl,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  onPressed: () => _updateClubField({'websiteUrl': ''}),
                ),
              ]
            ],
          ),
          const SizedBox(height: 12),
          if (hasLink)
            _buildLinkActionButton(
              label: 'Visit Website',
              url: _club.websiteUrl,
              icon: Icons.language_rounded,
              color: const Color(0xFF2563EB),
            )
          else if (isOfficer)
            GestureDetector(
              onTap: () => _showLinkDialog(
                title: 'Add Website Link',
                fieldKey: 'websiteUrl',
                currentValue: '',
              ),
              child: CustomPaint(
                painter: DashedBorderPainter(color: Theme.of(context).dividerColor, gap: 6),
                child: Container(
                  height: 48,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Colors.grey, size: 18),
                      SizedBox(width: 6),
                      Text('Add Website Link', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullFormCard(bool isOfficer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: AppTheme.textColor(context), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Full Form',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (isOfficer)
                TextButton(
                  onPressed: () => _showTextDialog(
                    title: 'Edit Full Form',
                    fieldKey: 'fullForm',
                    currentValue: _club.fullForm,
                  ),
                  child: const Text('Edit Full Form'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _club.fullForm.isNotEmpty ? _club.fullForm : 'No full form provided.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _club.fullForm.isNotEmpty ? Theme.of(context).colorScheme.onSurface : Colors.grey,
                  fontStyle: _club.fullForm.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutClubCard(bool isOfficer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.accent(context), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'About Club',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (isOfficer)
                TextButton(
                  onPressed: () => _showTextDialog(
                    title: 'Edit Description',
                    fieldKey: 'description',
                    currentValue: _club.description,
                    maxLines: 4,
                  ),
                  child: const Text('Edit Description'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _club.description.isNotEmpty ? _club.description : 'No description provided.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _club.description.isNotEmpty ? Theme.of(context).colorScheme.onSurface : Colors.grey,
                  fontStyle: _club.description.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingEventsCard(List<PostItem> clubPosts) {
    final upcomingEvents = clubPosts.where((p) => p.isUpcoming).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upcoming Events',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (upcomingEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No upcoming events. Create your first event!',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            )
          else
            Column(
              children: upcomingEvents.map<Widget>((event) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(event.title),
                    subtitle: Text(event.time ?? 'All Day'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PostDetailScreen(
                          appState: widget.appState,
                          initialPost: event,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _showMemberDialog({Map<String, dynamic>? member}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MemberFormSheet(
        appState: widget.appState,
        clubId: _club.id,
        member: member,
        onSuccess: (String message) {
          _showSuccessSnackBar(message);
          _refreshMembers();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.appState.session;
    final isAdmin = session?.role == 'admin';
    final isOfficer = session != null && session.isClubOfficerOf(_club.id);
    final canManageMembers = session != null && session.canManageMembersOf(_club.id, club: _club);
    final canManageEvents = session != null && session.canManageEventsOf(_club.id, club: _club);

    final clubPosts = widget.appState.posts
        .where((post) => post.clubId == _club.id)
        .toList();

    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          final members = snapshot.data ?? const <Map<String, dynamic>>[];
          return RefreshIndicator(
            onRefresh: () async {
              await widget.appState.refreshAll();
              if (mounted) {
                setState(() {
                  _refreshMembers();
                });
              }
            },
            child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              _club.startColor.withValues(alpha: 0.16),
                              _club.endColor.withValues(alpha: 0.18),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: _club.startColor.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(8),
                                child: _club.imageAsset.startsWith('http')
                                    ? Image.network(
                                        _club.imageAsset,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => Image.asset(
                                          'assets/images/club-default.jpg',
                                          fit: BoxFit.contain,
                                        ),
                                      )
                                    : Image.asset(
                                        _club.imageAsset.startsWith('/')
                                            ? 'assets/images${_club.imageAsset}'
                                            : _club.imageAsset,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => Image.asset(
                                          'assets/images/club-default.jpg',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                     Row(
                                       children: [
                                         Expanded(
                                           child: Text(
                                             _club.name,
                                             style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                                   fontWeight: FontWeight.w800,
                                                   letterSpacing: -0.5,
                                                 ),
                                           ),
                                         ),
                                         if (canManageMembers)
                                           IconButton(
                                             constraints: const BoxConstraints(),
                                             padding: const EdgeInsets.symmetric(horizontal: 8),
                                             icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                                             onPressed: () => _showTextDialog(
                                               title: 'Edit Club Name',
                                               fieldKey: 'name',
                                               currentValue: _club.name,
                                             ),
                                             tooltip: 'Edit Club Name',
                                           ),
                                       ],
                                     ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _club.fullForm.isNotEmpty ? _club.fullForm : 'No full form provided',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: _club.fullForm.isNotEmpty
                                                      ? AppTheme.textColor(context).withValues(alpha: 0.7)
                                                      : Colors.grey,
                                                  fontWeight: _club.fullForm.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
                                                  fontStyle: _club.fullForm.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                                                ),
                                          ),
                                        ),
                                        if (canManageMembers)
                                          IconButton(
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
                                            onPressed: () => _showTextDialog(
                                              title: 'Edit Full Form',
                                              fieldKey: 'fullForm',
                                              currentValue: _club.fullForm,
                                            ),
                                            tooltip: 'Edit Full Form',
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _Metric(
                              title: 'Members',
                              value: '${members.length}',
                              icon: Icons.groups_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Metric(
                              title: 'Category',
                              value: _club.category,
                              icon: Icons.hub_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Metric(
                              title: 'Posts',
                              value: '${clubPosts.length}',
                              icon: Icons.event_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildProfilePictureCard(canManageMembers),
                      _buildWhatsAppCard(canManageMembers),
                      _buildInstagramCard(canManageMembers),
                      _buildLinkedinCard(canManageMembers),
                      _buildWebsiteCard(canManageMembers),
                      _buildAboutClubCard(canManageMembers),
                      _buildUpcomingEventsCard(clubPosts),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Member Board',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MemberBoardDetailScreen(
                                  appState: widget.appState,
                                  club: _club,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.groups_outlined, size: 20),
                            tooltip: 'Full Member Board',
                          ),
                          if (canManageMembers) ...[
                            IconButton(
                              onPressed: () {
                                if (members.isEmpty) {
                                  _showErrorSnackBar('No members available to export.');
                                  return;
                                }
                                final csv = StringBuffer();
                                csv.writeln('Name,Email,Role,Board Type,Academic Year');
                                for (final m in members) {
                                  csv.writeln('"${m['name'] ?? ''}","${m['email'] ?? ''}","${m['role'] ?? ''}","${m['boardType'] ?? ''}","${m['academicYear'] ?? ''}"');
                                }
                                Share.share(csv.toString(), subject: '${_club.name} Member Roster');
                                _showSuccessSnackBar('Roster CSV generated. Opening sharing options...');
                              },
                              icon: Icon(Icons.download_rounded, color: AppTheme.accent(context)),
                              tooltip: 'Export Members',
                            ),
                            IconButton(
                              onPressed: () => _showMemberDialog(),
                              icon: Icon(Icons.person_add_alt_1_rounded, color: AppTheme.accent(context)),
                              tooltip: 'Add Member',
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (members.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No members found. Add some!'),
                          ),
                        )
                      else
                        Builder(
                          builder: (context) {
                            final mainMembers = members.where((m) => (m['boardType']?.toString().toLowerCase() ?? 'member') == 'main').toList();
                            if (mainMembers.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('No main board members found.'),
                                ),
                              );
                            }
                            return GlassCard(
                              child: Column(
                                children: mainMembers.map((member) {
                                  final memberId = member['_id']?.toString() ?? member['id']?.toString() ?? '';
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      child: Text(
                                        (member['name']?.toString() ?? 'U')[0],
                                      ),
                                    ),
                                    title: Text(() {
                                      String n = member['name']?.toString() ?? 'Member';
                                      if (['President', 'Secretary', 'Treasurer', 'Advisor', 'Member'].contains(n) && member['email'] != null) {
                                        n = member['email'].toString().split('@')[0].replaceAll('.', ' ');
                                        n = n.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
                                      }
                                      return n;
                                    }()),
                                    subtitle: Text(
                                      member['role']?.toString() ?? 'Member',
                                    ),
                                    trailing: canManageMembers
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 20),
                                                onPressed: () => _showMemberDialog(member: member),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.person_remove, color: Colors.red, size: 20),
                                                onPressed: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: const Text('Remove Member'),
                                                      content: Text('Are you sure you want to remove ${member['name']}?'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                                        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Remove')),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    try {
                                                      await widget.appState.removeClubMember(_club.id, memberId);
                                                      _showSuccessSnackBar('Member "${member['name']}" removed successfully!');
                                                      _refreshMembers();
                                                    } catch (e) {
                                                      _showErrorSnackBar('Failed to remove member: $e');
                                                    }
                                                  }
                                                },
                                              ),
                                            ],
                                          )
                                        : null,
                                  );
                                }).toList(),
                              ),
                            );
                          }
                        ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Text(
                            'Events & Posts',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverList.separated(
                  itemCount: clubPosts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final post = clubPosts[index];
                    return GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(
                            appState: widget.appState,
                            initialPost: post,
                          ),
                        ),
                      ),
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _stripMarkdown(post.content),
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  size: 16,
                                  color: AppTheme.purple,
                                ),
                                const SizedBox(width: 6),
                                Text(post.time ?? 'All Day'),
                                const SizedBox(width: 14),
                                const Icon(
                                  Icons.place_outlined,
                                  size: 16,
                                  color: AppTheme.purple,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(post.location ?? 'Campus'),
                                ),
                                if (canManageEvents)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Post'),
                                          content: const Text('Are you sure you want to delete this post?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                            FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        try {
                                          await widget.appState.deletePost(post.id);
                                          _showSuccessSnackBar('Post deleted successfully!');
                                          _refreshMembers();
                                        } catch (e) {
                                          _showErrorSnackBar('Failed to delete post: $e');
                                        }
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (isAdmin)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Delete Club'),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Club'),
                              content: Text('Are you sure you want to permanently delete ${_club.name}?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await widget.appState.deleteClub(_club.id);
                              _showSuccessSnackBar('Club "${_club.name}" deleted successfully!');
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            } catch (e) {
                              _showErrorSnackBar('Failed to delete club: $e');
                            }
                          }
                        },
                      ),
                    ),
                ),
              ),
            ],
          ),
        );
      },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.accent(context)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 28, // Matches titleLarge typical height to prevent layout jumps
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({required this.color, this.strokeWidth = 1.0, this.gap = 4.0});
  final Color color;
  final double strokeWidth;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(12),
      ));

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final nextDistance = distance + gap;
        final isDash = (distance / gap).floor() % 2 == 0;
        if (isDash) {
          canvas.drawPath(
            metric.extractPath(distance, nextDistance),
            paint,
          );
        }
        distance = nextDistance;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth || oldDelegate.gap != gap;
}

String _stripMarkdown(String markdown) {
  var text = markdown.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (match) => match[1] ?? '');
  text = text.replaceAll(RegExp(r'\*\*|__|\*|_'), '');
  text = text.replaceAll(RegExp(r'^#+\s+', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\s*-\s+', multiLine: true), '');
  return text.trim();
}
