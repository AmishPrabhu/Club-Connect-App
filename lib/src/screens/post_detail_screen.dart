import 'package:club_connect_flutter/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/post_item.dart';
import '../state/app_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/edit_event_sheet.dart';
import '../widgets/create_notification_sheet.dart';
import 'event_participants_screen.dart';

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
  late final Future<PostItem> _postFuture;
  bool _isInterested = false;

  @override
  void initState() {
    super.initState();
    _postFuture = widget.appState.fetchPost(widget.initialPost.id);
    _checkInterestStatus();
  }

  void _checkInterestStatus() async {
    final session = widget.appState.session;
    if (session == null) return;
    try {
      final interested = await widget.appState.checkInterest(widget.initialPost.id);
      if (mounted) {
        setState(() {
          _isInterested = interested;
        });
      }
    } catch (e) {
      debugPrint('Error checking interest status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialPost.type == 'event' ? 'Event Detail' : 'Announcement',
        ),
        actions: [
          if (widget.initialPost.isEvent && widget.appState.session != null)
            Builder(
              builder: (context) {
                final sess = widget.appState.session!;
                final clubMatch = widget.appState.clubs.where((c) => c.id == widget.initialPost.clubId).toList();
                final club = clubMatch.isNotEmpty ? clubMatch.first : null;
                final isOfficer = sess.canManageEventsOf(widget.initialPost.clubId, club: club);
                final isAdmin = sess.role == 'admin' || sess.roles.contains('admin');
                if (isOfficer || isAdmin) {
                  return IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit Event Details',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => EditEventSheet(
                          event: widget.initialPost,
                          appState: widget.appState,
                          onSuccess: () {
                            if (mounted) setState(() {});
                          },
                        ),
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
        ],
      ),
      body: FutureBuilder<PostItem>(
        future: _postFuture,
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
                        GestureDetector(
                          onTap: () => _showFullScreenImage(context, post.coverAsset!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: post.coverAsset!.startsWith('http')
                                ? Image.network(
                                    post.coverAsset!,
                                    width: double.infinity,
                                    height: 240,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Image.asset(
                                      'assets/images/club-default.jpg',
                                      width: double.infinity,
                                      height: 240,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    post.coverAsset!.startsWith('/')
                                        ? 'assets/images${post.coverAsset!}'
                                        : post.coverAsset!,
                                    width: double.infinity,
                                    height: 240,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Image.asset(
                                      'assets/images/club-default.jpg',
                                      width: double.infinity,
                                      height: 240,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
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
                             MarkdownBody(
                               data: post.content,
                               styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                 p: Theme.of(context).textTheme.bodyLarge,
                                 listBullet: Theme.of(context).textTheme.bodyLarge,
                               ),
                               onTapLink: (text, href, title) async {
                                 if (href != null) {
                                   final uri = Uri.parse(href);
                                   if (await canLaunchUrl(uri)) {
                                     launchUrl(uri, mode: LaunchMode.externalApplication);
                                   }
                                 }
                               },
                             ),
                             if (post.descriptionImages.isNotEmpty) ...[
                               const SizedBox(height: 16),
                               Text(
                                 'Description Media',
                                 style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                               ),
                               const SizedBox(height: 8),
                               SizedBox(
                                 height: 130,
                                 child: ListView.builder(
                                   scrollDirection: Axis.horizontal,
                                   itemCount: post.descriptionImages.length,
                                   itemBuilder: (context, index) {
                                     final imgUrl = post.descriptionImages[index];
                                     return Padding(
                                       padding: const EdgeInsets.only(right: 10),
                                       child: GestureDetector(
                                         onTap: () => _showFullScreenImage(context, imgUrl),
                                         child: ClipRRect(
                                           borderRadius: BorderRadius.circular(12),
                                           child: Image.network(
                                             imgUrl,
                                             width: 170,
                                             height: 130,
                                             fit: BoxFit.cover,
                                             errorBuilder: (_, _, _) => Container(
                                               width: 170,
                                               height: 130,
                                               color: Colors.grey.shade300,
                                               child: const Icon(Icons.broken_image, color: Colors.grey),
                                             ),
                                           ),
                                         ),
                                       ),
                                     );
                                   },
                                 ),
                               ),
                             ],
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
                            // ── Event Manager Badge ──────────────────────
                            if (post.isEvent &&
                                post.eventManagerName != null &&
                                post.eventManagerName!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B35).withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFFF6B35).withValues(alpha: 0.30),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.shield_outlined,
                                      size: 15,
                                      color: Color(0xFFFF6B35),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Event Manager: ${post.eventManagerName!}',
                                      style: const TextStyle(
                                        color: Color(0xFFFF6B35),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                             if (post.isEvent) ...[
                              _buildReportSection(post),
                              const SizedBox(height: 18),
                              _buildEventActionButton(post),
                              if (widget.appState.session != null) ...[
                                Builder(
                                  builder: (ctx) {
                                    final sess = widget.appState.session!;
                                    final clubMatch = widget.appState.clubs.where((c) => c.id == post.clubId).toList();
                                    final club = clubMatch.isNotEmpty ? clubMatch.first : null;
                                    final isOfficer = sess.canManageEventsOf(post.clubId, club: club);
                                    final isSupervisor = sess.role == 'advisor' ||
                                        sess.role == 'teacher' ||
                                        sess.role == 'admin' ||
                                        sess.roles.contains('advisor') ||
                                        sess.roles.contains('teacher');
                                    // Is this user the assigned event manager?
                                    final isEventManager = post.eventManagerEmail != null &&
                                        post.eventManagerEmail!.isNotEmpty &&
                                        sess.email.toLowerCase() ==
                                            post.eventManagerEmail!.toLowerCase();

                                    final canManage = isOfficer || isSupervisor;
                                    final canAnnounce = isEventManager || canManage;

                                    if (!canManage && !canAnnounce) {
                                      return const SizedBox.shrink();
                                    }

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        if (canManage)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 12.0),
                                            child: OutlinedButton.icon(
                                              icon: const Icon(Icons.people_outline_rounded),
                                              label: const Text('Manage Attendance & Certificates'),
                                              onPressed: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) => EventParticipantsScreen(
                                                      appState: widget.appState,
                                                      event: post,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        if (canAnnounce)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 10.0),
                                            child: FilledButton.icon(
                                              icon: const Icon(Icons.campaign_rounded),
                                              label: const Text('Send Event Announcement'),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: const Color(0xFFFF6B35),
                                              ),
                                              onPressed: () {
                                                showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  backgroundColor: Colors.transparent,
                                                  builder: (_) => CreateNotificationSheet(
                                                    appState: widget.appState,
                                                    initialType: 'event',
                                                    clubId: post.clubId,
                                                    onSuccess: (msg) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(msg),
                                                          behavior: SnackBarBehavior.floating,
                                                          backgroundColor: Colors.green.shade700,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ],
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
              if (post.attachments.isNotEmpty)
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
                      return GestureDetector(
                        onTap: () => _showFullScreenImage(context, src),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: src.startsWith('http')
                              ? Image.network(
                                  src,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Image.asset(
                                    'assets/images/club-default.jpg',
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Image.asset(
                                  src.startsWith('/') ? 'assets/images$src' : src,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Image.asset(
                                    'assets/images/club-default.jpg',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
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

  /// Builds the appropriate action button based on event state and user login:
  /// - Event ended → disabled "Event Ended"
  /// - Before registration & logged in → "I'm Interested" / "You're Interested ✓"
  /// - Registration open & has link → "Register Now →" (opens external link)
  /// - Registration open & no link → nothing
  /// - After registration → nothing
  /// - No registration dates & logged in & event upcoming → "I'm Interested"
  Widget _buildEventActionButton(PostItem post) {
    final isLoggedIn = widget.appState.session != null;

    // Event has ended
    if (!post.isUpcoming) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: null,
          child: const Text('Event Ended'),
        ),
      );
    }

    // If registration dates are configured, use the timeline logic
    if (post.hasRegistrationDates) {
      // Before registration starts
      if (post.isBeforeRegistration) {
        if (!isLoggedIn) {
          return const SizedBox.shrink(); // Not logged in, no "I'm Interested"
        }
        return _buildInterestedButton(post);
      }

      // Registration is open
      if (post.isRegistrationOpen) {
        final link = post.registrationLink;
        if (link == null || link.isEmpty) {
          return const SizedBox.shrink(); // No link → show nothing
        }
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _openRegistrationLink(link),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Register Now →'),
          ),
        );
      }

      // After registration ended
      if (post.isAfterRegistration) {
        return const SizedBox.shrink(); // Show nothing
      }
    }

    // No registration dates configured but event is upcoming
    // Logged-in users see "I'm Interested", logged-out see nothing
    if (isLoggedIn) {
      return _buildInterestedButton(post);
    }

    return const SizedBox.shrink();
  }

  Widget _buildInterestedButton(PostItem post) {
    return SizedBox(
      width: double.infinity,
      child: _submitting
          ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
          : FilledButton.icon(
              onPressed: () => _toggleInterest(post.id),
              icon: Icon(
                _isInterested ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              ),
              label: Text(
                _isInterested ? "You're Interested ✓" : "I'm Interested",
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _isInterested
                    ? Theme.of(context).colorScheme.secondary
                    : null,
              ),
            ),
    );
  }

  Future<void> _toggleInterest(String eventId) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      if (_isInterested) {
        await widget.appState.removeInterest(eventId);
        setState(() {
          _isInterested = false;
          _message = 'Interest removed.';
        });
      } else {
        await widget.appState.markInterested(eventId);
        setState(() {
          _isInterested = true;
          _message = "You'll be notified about updates to this event.";
        });
      }
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openRegistrationLink(String link) async {
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Clipboard.setData(ClipboardData(text: link));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link. Copied to clipboard instead.')),
        );
      }
    }
  }

  Widget _buildReportSection(PostItem post) {
    final session = widget.appState.session;
    if (session == null) return const SizedBox.shrink();

    final clubMatch = widget.appState.clubs.where((c) => c.id == post.clubId).toList();
    final club = clubMatch.isNotEmpty ? clubMatch.first : null;
    final isClubOfficer = session.canSubmitReportFor(post.clubId, club: club);

    final isSupervisor = session.role == 'advisor' ||
        session.role == 'teacher' ||
        session.role == 'admin' ||
        session.roles.contains('advisor') ||
        session.roles.contains('teacher');

    final hasReport = post.reportUrl != null && post.reportUrl!.isNotEmpty;

    if (!isClubOfficer && !isSupervisor) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.file_copy_rounded, size: 16, color: AppTheme.accent(context)),
              const SizedBox(width: 8),
              const Text(
                'ACTIVITY REPORT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasReport) ...[
            Text(
              'Report submitted by ${post.reportSubmittedByName ?? "Club Officer"}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            if (post.reportSubmittedAt != null)
              Text(
                'Submitted on: ${post.reportSubmittedAt!.toLocal().toString().split(' ')[0]}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text('Open Report', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      _openPdfUrl(post.reportUrl!);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Copy Link', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      _copyReportLink(post.reportUrl!);
                    },
                  ),
                ),
                if (isClubOfficer) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () => _confirmRemoveReport(post.id),
                  ),
                ],
              ],
            ),
          ] else ...[
            const Text(
              'No report uploaded yet.',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
            if (isClubOfficer) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: const Text('Upload/Submit Report'),
                  onPressed: () => _showSubmitReportDialog(post.id),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _copyReportLink(String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report link copied to clipboard!')),
    );
  }

  Future<void> _openPdfUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link. Copied to clipboard instead.')),
        );
      }
    }
  }

  void _confirmRemoveReport(String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Report'),
        content: const Text('Are you sure you want to delete the submitted activity report?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _submitting = true);
              try {
                await widget.appState.deleteEventReport(postId);
                setState(() => _message = 'Report removed successfully.');
              } catch (e) {
                setState(() => _message = 'Failed to remove report: $e');
              } finally {
                setState(() => _submitting = false);
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showSubmitReportDialog(String postId) {
    final urlController = TextEditingController();
    final filenameController = TextEditingController();
    bool dialogSubmitting = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Submit Activity Report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                enabled: !dialogSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Report PDF URL',
                  hintText: 'Enter PDF document URL',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: filenameController,
                enabled: !dialogSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Filename / Label',
                  hintText: 'e.g. event_report.pdf',
                ),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 12),
                Text(
                  dialogError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: dialogSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: dialogSubmitting
                  ? null
                  : () async {
                      final url = urlController.text.trim();
                      final filename = filenameController.text.trim();
                      if (url.isEmpty || filename.isEmpty) {
                        setDialogState(() {
                          dialogError = 'Please fill in both fields.';
                        });
                        return;
                      }
                      setDialogState(() {
                        dialogSubmitting = true;
                        dialogError = null;
                      });
                      try {
                        await widget.appState.submitEventReport(postId, url, filename);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        setState(() => _message = 'Report submitted successfully.');
                      } catch (e) {
                        setDialogState(() {
                          dialogSubmitting = false;
                          dialogError = 'Failed to submit report: $e';
                        });
                      }
                    },
              child: dialogSubmitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) {
          return Scaffold(
            backgroundColor: Colors.black.withOpacity(0.9),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.white),
              elevation: 0,
            ),
            body: Center(
              child: InteractiveViewer(
                child: imageUrl.startsWith('http')
                    ? Image.network(imageUrl, fit: BoxFit.contain)
                    : Image.asset(
                        imageUrl.startsWith('/') ? 'assets/images$imageUrl' : imageUrl,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
          );
        },
      ),
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
