import 'package:flutter/material.dart';

import '../models/post_item.dart';
import '../state/app_state.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';
import '../widgets/glass_card.dart';
 import 'attendance_management_screen.dart';
import 'certificate_setup_screen.dart';
import 'event_management_screen.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.appState,
    required this.initialPost,
  });

  final AppState appState;
  final PostItem initialPost;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  bool _submitting = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialPost.type == 'event' ? 'Event Detail' : 'Announcement',
        ),
      ),
      body: FutureBuilder<PostItem>(
        future: widget.appState.fetchPost(widget.initialPost.id),
        initialData: widget.initialPost,
        builder: (context, snapshot) {
          final post = snapshot.data ?? widget.initialPost;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post.coverAsset != null &&
                          post.coverAsset!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: post.coverAsset!.startsWith('http')
                              ? Image.network(
                                  post.coverAsset!,
                                  width: double.infinity,
                                  height: 240,
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  post.coverAsset!,
                                  width: double.infinity,
                                  height: 240,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      const SizedBox(height: 18),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.title,
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'by ${post.clubName}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              post.content,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            if (post.date != null) ...[
                              const SizedBox(height: 20),
                              _MetaRow(
                                icon: Icons.calendar_month_rounded,
                                label:
                                    '${post.date!.day}/${post.date!.month}/${post.date!.year}',
                              ),
                            ],
                            if (post.time != null) ...[
                              const SizedBox(height: 10),
                              _MetaRow(
                                icon: Icons.schedule_rounded,
                                label: post.time!,
                              ),
                            ],
                            if (post.location != null) ...[
                              const SizedBox(height: 10),
                              _MetaRow(
                                icon: Icons.place_outlined,
                                label: post.location!,
                              ),
                            ],
                            if (post.isEvent) ...[
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _submitting
                                      ? null
                                      : () => _rsvp(post.id),
                                  child: Text(
                                    _submitting ? 'Submitting...' : 'RSVP',
                                  ),
                                ),
                              ),
                            ],
                            if (widget.appState.session != null && post.isEvent &&
                                (widget.appState.session!.role == 'super-admin' ||
                                    (widget.appState.session!.clubId == post.clubId &&
                                        ['club-secretary', 'president', 'advisor']
                                            .contains(widget.appState.session!.role)))) ...[
                               const SizedBox(height: 12),
                               SizedBox(
                                 width: double.infinity,
                                 child: FilledButton.icon(
                                   icon: const Icon(Icons.settings_suggest_rounded),
                                   onPressed: () {
                                     Navigator.of(context).push(
                                       MaterialPageRoute(
                                         builder: (context) => EventManagementScreen(
                                           event: post,
                                           appState: widget.appState,
                                         ),
                                       ),
                                     );
                                   },
                                   label: const Text('Manage Event'),
                                 ),
                               ),
                            ],
                            if (_message != null) ...[
                              const SizedBox(height: 12),
                              Text(_message!),
                            ],
                          ],
                        ),
                      ),
                      if (post.attachments.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Attachments',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.1,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final src = post.attachments[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: src.startsWith('http')
                          ? Image.network(src, fit: BoxFit.cover)
                          : Image.asset(src, fit: BoxFit.cover),
                    );
                  }, childCount: post.attachments.length),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _rsvp(String eventId) async {
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      await widget.appState.rsvpToEvent(eventId);
      setState(() => _message = 'RSVP submitted successfully.');
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
  Future<void> _submitBudgetDialog(String postId) async {
    bool isUploading = false;
    await showDialog<void>(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Submit Budget'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Upload a screenshot or document of the budget proposal.'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate),
                      label: Text(isUploading ? 'Uploading...' : 'Upload Budget File'),
                      onPressed: isUploading
                          ? null
                          : () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(source: ImageSource.gallery);
                              if (picked != null) {
                                setStateDialog(() => isUploading = true);
                                final url = await CloudinaryService.uploadImage(File(picked.path));
                                setStateDialog(() => isUploading = false);
                                
                                if (url != null) {
                                  if (mounted) navigator.pop();
                                  setState(() => _submitting = true);
                                  try {
                                    await widget.appState.updatePost(postId, {'budgetImage': url});
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Budget submitted successfully!')),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to submit budget: $e')),
                                      );
                                    }
                                  } finally {
                                    setState(() => _submitting = false);
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to upload image.')),
                                    );
                                  }
                                }
                              }
                            },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => navigator.pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitReportDialog(String postId) async {
    bool isUploading = false;
    await showDialog<void>(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Submit Report'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Upload the post-event report document (image format).'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate),
                      label: Text(isUploading ? 'Uploading...' : 'Upload Report File'),
                      onPressed: isUploading
                          ? null
                          : () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(source: ImageSource.gallery);
                              if (picked != null) {
                                setStateDialog(() => isUploading = true);
                                final url = await CloudinaryService.uploadImage(File(picked.path));
                                setStateDialog(() => isUploading = false);
                                
                                if (url != null) {
                                  if (mounted) navigator.pop();
                                  setState(() => _submitting = true);
                                  try {
                                    await widget.appState.submitReport(
                                      postId,
                                      url,
                                      picked.name,
                                    );
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Report submitted successfully!')),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to submit report: $e')),
                                      );
                                    }
                                  } finally {
                                    setState(() => _submitting = false);
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to upload image.')),
                                    );
                                  }
                                }
                              }
                            },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => navigator.pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}
