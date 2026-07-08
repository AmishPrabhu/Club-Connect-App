import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../services/cloudinary_service.dart';
import 'dart:io';

import '../models/club.dart';
import '../models/post_item.dart';
import '../models/notification_item.dart';
import '../models/user_session.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';
import 'notification_detail_screen.dart';
import 'institution_settings_screen.dart';
import 'event_participants_screen.dart';
import 'notifications_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.appState,
    this.initialClub,
    this.initialRole,
  });

  final AppState appState;
  final Club? initialClub;
  final String? initialRole;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedSection = 'Overview';
  String _advisorActiveTab = 'Events';
  Club? _selectedClub;
  List<Club> _monitoredClubs = [];
  bool _isLoadingMonitored = false;
  bool _isUploadingLogo = false;
  String _clubSearchQuery = '';
  String _teacherActiveTab = 'Overview';
  String _teacherYearFilter = '2026';
  String _teacherBoardFilter = 'All Boards';
  String _teacherReportYearFilter = 'All Years';
  List<Map<String, dynamic>> _allReports = [];

  // Futures for asynchronous views
  Future<List<Map<String, dynamic>>>? _membersFuture;
  Future<List<Map<String, dynamic>>>? _tasksFuture;
  Future<List<Map<String, dynamic>>>? _messagesFuture;
  Future<List<Map<String, dynamic>>>? _teachersFuture;
  Future<List<Map<String, dynamic>>>? _reportsFuture;

  // Controllers for Messages/Chat
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onAppStateChanged);
    _initializeDashboard();
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onAppStateChanged);
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    setState(() {
      if (_selectedClub != null) {
        final matches = widget.appState.clubs.where((c) => c.id == _selectedClub!.id).toList();
        if (matches.isNotEmpty) {
          _selectedClub = matches.first;
        } else {
          _selectedClub = widget.appState.clubs.isNotEmpty ? widget.appState.clubs.first : null;
        }
      } else if (widget.appState.clubs.isNotEmpty) {
        _selectedClub = widget.appState.clubs.first;
      }

      final session = widget.appState.session;
      final activeRole = widget.initialRole ?? session?.role;
      if (session != null && activeRole != null) {
        if (activeRole == 'president' ||
            activeRole == 'club-secretary' ||
            activeRole == 'treasurer' ||
            activeRole == 'advisor') {
          if (widget.initialClub == null) {
            _selectedClub = _resolveManagedClub(session);
          }
        }
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

  void _initializeDashboard() async {
    final session = widget.appState.session;
    if (session == null) return;
    final activeRole = widget.initialRole ?? session.role;
    
    // Resolve managed club for officers
    if (widget.initialClub != null) {
      _selectedClub = widget.initialClub;
    } else if (activeRole == 'president' ||
        activeRole == 'club-secretary' ||
        activeRole == 'treasurer' ||
        activeRole == 'advisor') {
      _selectedClub = _resolveManagedClub(session);
    } else if (activeRole == 'teacher') {
      setState(() => _isLoadingMonitored = true);
      try {
        final monitored = await widget.appState.fetchTeacherClubs();
        final reports = await widget.appState.fetchTeacherReports();
        final List<Club> loaded = [];
        for (final m in monitored) {
          final id = m['_id']?.toString() ?? m['id']?.toString() ?? '';
          final match = widget.appState.clubs.where((c) => c.id == id).toList();
          if (match.isNotEmpty) loaded.add(match.first);
        }
        setState(() {
          _monitoredClubs = loaded;
          _allReports = reports;
          _selectedClub = null;
        });
      } catch (e) {
        print('Error loading teacher clubs: $e');
      } finally {
        setState(() => _isLoadingMonitored = false);
      }
    } else if (activeRole == 'admin') {
      if (widget.appState.clubs.isNotEmpty) {
        _selectedClub = widget.appState.clubs.first;
      }
      _teachersFuture = widget.appState.fetchTeachers();
    }

    if (activeRole == 'advisor') {
      _selectedSection = 'Overview';
    } else if (activeRole == 'treasurer') {
      _selectedSection = 'Overview';
    } else if (activeRole == 'president' || activeRole == 'club-secretary') {
      _selectedSection = 'Overview';
    }

    _reloadSectionData();
  }

  void _reloadSectionData() {
    if (_selectedClub == null) return;
    final clubId = _selectedClub!.id;

    setState(() {
      _membersFuture = widget.appState.fetchClubMembers(clubId);
      _tasksFuture = widget.appState.fetchClubTasks(clubId);
      _messagesFuture = widget.appState.fetchClubMessages(clubId);
      _reportsFuture = widget.appState.fetchTeacherReports().then(
            (all) => all.where((r) => r['clubId'] == clubId).toList(),
          );
    });
  }

  Club? _resolveManagedClub(UserSession session) {
    final clubs = widget.appState.clubs;
    final byId = clubs.where((club) => club.id == session.clubId).toList();
    if (byId.isNotEmpty) return byId.first;
    final byName = clubs.where((club) => club.name == session.clubName).toList();
    if (byName.isNotEmpty) return byName.first;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.appState.session;
    if (session == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    final activeRole = widget.initialRole ?? session.role;
    final isAdmin = activeRole == 'admin';
    final isTeacher = activeRole == 'teacher';
    final isOfficer = activeRole == 'president' ||
        activeRole == 'club-secretary' ||
        activeRole == 'treasurer' ||
        activeRole == 'advisor';

    return Scaffold(
      appBar: isAdmin
          ? null
          : AppBar(
              title: isTeacher
                  ? Text(
                      'WCE, Sangli',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    )
                  : Text(_selectedSection == 'Overview' ? (isOfficer ? 'Club Dashboard' : 'Campus Dashboard') : _selectedSection),
              elevation: 0,
              leading: isTeacher
                  ? null
                  : (_selectedSection != 'Overview'
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                          onPressed: () => setState(() => _selectedSection = 'Overview'),
                        )
                      : (Navigator.of(context).canPop()
                          ? IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                              onPressed: () => Navigator.of(context).pop(),
                            )
                          : null)),
              actions: isTeacher
                  ? [
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded, size: 22),
                        tooltip: 'Notifications',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: const Text('Notifications')),
                                body: NotificationsScreen(appState: widget.appState),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                    ]
                  : null,
            ),
      body: _isLoadingMonitored
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [


                  if (isAdmin)
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          await widget.appState.refreshAll();
                          _reloadSectionData();
                        },
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_selectedSection == 'Overview') ...[
                                _buildNewAdminHeader(session),
                                const SizedBox(height: 16),
                                _buildNewAdminStatsOverview(),
                                const SizedBox(height: 24),
                                _buildNewAdminQuickActions(),
                              ] else ...[
                                _buildNewSubSectionHeader(),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                                  child: _buildActiveSectionView(session),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    )
                  else ...[
                    if (_selectedClub == null)
                      Expanded(
                        child: isTeacher
                            ? _buildTeacherDashboardOverview(session)
                            : Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.shield_outlined, size: 64, color: Colors.grey),
                                      const SizedBox(height: 12),
                                      const Text('No Club Selected', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 6),
                                      Text(
                                        isTeacher ? 'Please add a club to monitor first.' : 'No clubs available to manage.',
                                        style: const TextStyle(color: Colors.grey),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (isTeacher) ...[
                                        const SizedBox(height: 16),
                                        FilledButton.icon(
                                          onPressed: _showAddMonitoredClubDialog,
                                          icon: const Icon(Icons.add),
                                          label: const Text('Add Club to Monitor'),
                                        )
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                      )
                    else ...[
                      // Active view body
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            await widget.appState.refreshAll();
                            _reloadSectionData();
                          },
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            child: isTeacher && _selectedSection == 'Overview'
                                ? _buildTeacherClubDetailsView(session)
                                : (isOfficer
                                    ? _buildOfficerClubDetailsView(session)
                                    : _buildActiveSectionView(session)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }




  Widget _buildActiveSectionView(UserSession session) {
    final activeRole = widget.initialRole ?? session.role;
    if (activeRole != 'admin' && _selectedClub == null) return const SizedBox.shrink();

    switch (_selectedSection) {
      case 'Overview':
        if (activeRole == 'admin') {
          return _buildAdminOverviewSection();
        } else {
          return _buildOverviewView(session);
        }
      case 'Manage Clubs':
        return _buildManageClubsSection();
      case 'Manage Posts':
        return _buildManagePostsSection();
      case 'Notifications':
        return activeRole == 'admin' ? _buildAdminNotificationsSection() : _buildNotificationsView(session);
      case 'Teachers':
        return activeRole == 'admin' ? _buildAdminTeachersSection() : const SizedBox.shrink();
      case 'Members':
        return _buildMembersView(session);
      case 'Drafts & Posts':
      case 'Posts & Announcements':
        return _buildPostsView(session);
      case 'Events':
        if (activeRole == 'advisor') {
          final clubPosts = widget.appState.posts.where((p) => p.clubId == _selectedClub!.id).toList();
          final clubEvents = clubPosts.where((p) => p.isEvent).toList();
          return _buildAdvisorEventsTab(clubEvents);
        }
        return _buildEventsView(session);
      case 'Tasks':
        return _buildTasksView(session);
      case 'Live Chat':
        return _buildMessagesView(session);
      case 'Budgets':
      case 'Budget':
        if (activeRole == 'advisor') {
          final clubPosts = widget.appState.posts.where((p) => p.clubId == _selectedClub!.id).toList();
          final clubEvents = clubPosts.where((p) => p.isEvent).toList();
          return _buildAdvisorBudgetsTab(clubEvents);
        }
        return _buildBudgetView(session);
      case 'Reports':
        if (activeRole == 'advisor') {
          return _buildAdvisorReportsTab();
        }
        return const SizedBox.shrink();
      case 'Team':
        if (activeRole == 'advisor') {
          return _buildAdvisorTeamTab();
        }
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  List<String> _getSectionsForRole(String activeRole) {
    if (activeRole == 'advisor') {
      return ['Events', 'Reports', 'Budgets', 'Team'];
    } else if (activeRole == 'treasurer') {
      return ['Overview', 'Members', 'Tasks', 'Messages', 'Budgets'];
    } else if (activeRole == 'president' || activeRole == 'club-secretary') {
      return ['Overview', 'Members', 'Drafts & Posts', 'Events', 'Tasks', 'Messages', 'Notifications', 'Budget'];
    }
    return ['Overview'];
  }

  void _showOfficerTabSelector(String activeRole) {
    final sections = _getSectionsForRole(activeRole);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: sections.map((sec) {
            IconData icon = Icons.bookmark_outline_rounded;
            Color iconColor = AppTheme.blue;
            if (sec == 'Overview') {
              icon = Icons.trending_up_rounded;
              iconColor = Colors.blue;
            } else if (sec == 'Members') {
              icon = Icons.people_outline_rounded;
              iconColor = Colors.purple;
            } else if (sec == 'Drafts & Posts') {
              icon = Icons.edit_note_rounded;
              iconColor = Colors.orange;
            } else if (sec == 'Events') {
              icon = Icons.calendar_month_outlined;
              iconColor = Colors.green;
            } else if (sec == 'Tasks') {
              icon = Icons.checklist_rtl_rounded;
              iconColor = Colors.teal;
            } else if (sec == 'Messages') {
              icon = Icons.chat_bubble_outline_rounded;
              iconColor = Colors.indigo;
            } else if (sec == 'Notifications') {
              icon = Icons.notifications_none_rounded;
              iconColor = Colors.red;
            } else if (sec == 'Budget' || sec == 'Budgets') {
              icon = Icons.account_balance_wallet_outlined;
              iconColor = Colors.cyan;
            } else if (sec == 'Reports') {
              icon = Icons.file_copy_outlined;
              iconColor = Colors.amber;
            } else if (sec == 'Team') {
              icon = Icons.groups_3_outlined;
              iconColor = Colors.deepOrange;
            }

            return ListTile(
              leading: Icon(icon, color: iconColor),
              title: Text(sec, style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                setState(() => _selectedSection = sec);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOfficerClubDetailsView(UserSession session) {
    if (_selectedSection == 'Overview') {
      return _buildOverviewView(session);
    }
    return _buildActiveSectionView(session);
  }

  // ─── ADMIN DASHBOARD HELPER METHODS ────────────────────────────────────────

  Widget _buildNewAdminHeader(UserSession session) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hello,',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                session.name,
                style: const TextStyle(
                  fontSize: 26,
                  color: AppTheme.navy,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileSettingsScreen(appState: widget.appState),
                ),
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE), // Light lavender/purple background
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFC084FC), // Light purple border
                      width: 1.5,
                    ),
                    image: session.profileImage != null && session.profileImage!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(session.profileImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: session.profileImage == null || session.profileImage!.isEmpty
                      ? Center(
                          child: Text(
                            session.name.isNotEmpty ? session.name[0].toUpperCase() : 'A',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6D28D9), // Dark purple text
                            ),
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED), // Purple edit badge
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewAdminStatsOverview() {
    final clubsCount = widget.appState.clubs.length;
    final eventsCount = widget.appState.posts.where((p) => p.isEvent).length;
    final postsCount = widget.appState.posts.length;
    final alertsCount = widget.appState.notifications.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.navy,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNewOverviewCard(
                  icon: Icons.groups_rounded,
                  iconColor: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                  value: '$clubsCount',
                  label: 'Clubs',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNewOverviewCard(
                  icon: Icons.calendar_month_rounded,
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                  value: '$eventsCount',
                  label: 'Events',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNewOverviewCard(
                  icon: Icons.edit_note_rounded,
                  iconColor: const Color(0xFFEC4899),
                  bgColor: const Color(0xFFFDF2F8),
                  value: '$postsCount',
                  label: 'Posts',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNewOverviewCard(
                  icon: Icons.notifications_none_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFFFBEB),
                  value: '$alertsCount',
                  label: 'Alerts',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewOverviewCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewAdminQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy,
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildNewActionTile(
            title: 'Manage Clubs',
            subtitle: 'View and manage clubs',
            icon: Icons.groups_outlined,
            iconColor: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
            section: 'Manage Clubs',
          ),
          const SizedBox(height: 12),
          _buildNewActionTile(
            title: 'Manage Posts',
            subtitle: 'Create and edit posts',
            icon: Icons.edit_note_outlined,
            iconColor: const Color(0xFFEC4899),
            bgColor: const Color(0xFFFDF2F8),
            section: 'Manage Posts',
          ),
          const SizedBox(height: 12),
          _buildNewActionTile(
            title: 'Teachers',
            subtitle: 'Manage teachers',
            icon: Icons.person_outline_rounded,
            iconColor: const Color(0xFF10B981),
            bgColor: const Color(0xFFECFDF5),
            section: 'Teachers',
          ),
          const SizedBox(height: 12),
          _buildNewActionTile(
            title: 'Notifications',
            subtitle: 'View all notifications',
            icon: Icons.notifications_none_outlined,
            iconColor: const Color(0xFFF59E0B),
            bgColor: const Color(0xFFFFFBEB),
            section: 'Notifications',
          ),
          const SizedBox(height: 12),
          _buildNewActionTile(
            title: 'Institution Settings',
            subtitle: 'Branding & communication defaults',
            icon: Icons.business_rounded,
            iconColor: const Color(0xFF6366F1),
            bgColor: const Color(0xFFEEF2F6),
            section: 'Institution Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildNewActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String section,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
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
            if (section == 'Institution Settings') {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InstitutionSettingsScreen()),
              );
            } else {
              setState(() => _selectedSection = section);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: bgColor,
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewSubSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.navy),
            onPressed: () => setState(() => _selectedSection = 'Overview'),
          ),
          const SizedBox(width: 8),
          Text(
            _selectedSection,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminHeaderCard(UserSession session) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Administrative Control Center',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage clubs, events, and system settings •',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Welcome, ${session.name}',
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminStatsGrid() {
    final clubsCount = widget.appState.clubs.length;
    final events = widget.appState.posts.where((p) => p.isEvent).toList();
    final announcementsCount = widget.appState.posts.where((p) => p.type == 'announcement').length;
    final alertsCount = widget.appState.notifications.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildStatCard(
            icon: Icons.people_alt_outlined,
            iconColor: Colors.blue.shade700,
            iconBgColor: Colors.blue.shade50,
            value: '$clubsCount',
            label: 'TOTAL CLUBS',
          ),
          _buildStatCard(
            icon: Icons.calendar_month_outlined,
            iconColor: Colors.blue.shade700,
            iconBgColor: Colors.blue.shade50,
            value: '${events.length}',
            label: 'UPCOMING',
          ),
          _buildStatCard(
            icon: Icons.trending_up_rounded,
            iconColor: Colors.purple.shade700,
            iconBgColor: Colors.purple.shade50,
            value: '${events.length + announcementsCount}',
            label: 'POSTS',
          ),
          _buildStatCard(
            icon: Icons.notifications_none_rounded,
            iconColor: Colors.red.shade700,
            iconBgColor: Colors.red.shade50,
            value: '$alertsCount',
            label: 'ALERTS',
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String value,
    required String label,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEventCard(PostItem post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(width: 4, height: 90, color: Colors.cyan.shade600),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.cyan.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.calendar_today_outlined, color: Colors.cyan.shade700, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.cyan.shade100.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'EVENT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF006064),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.access_time, size: 11, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                post.date != null
                                    ? '${post.date!.year}-${post.date!.month.toString().padLeft(2, '0')}-${post.date!.day.toString().padLeft(2, '0')}'
                                    : '',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            post.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.navy,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Posted by ${post.clubName}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminOverviewSection() {
    final events = widget.appState.posts.where((p) => p.isEvent).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(width: 4, height: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Recent Campus Activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _selectedSection = 'Manage Posts'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.cyan.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'VIEW ALL ACTIVITY',
                      style: TextStyle(
                        color: Colors.teal.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.north_east_rounded, size: 12, color: Colors.teal.shade700),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (events.isEmpty)
          const Center(child: Text('No recent events.'))
        else
          ...events.map((e) => _buildRecentEventCard(e)),
      ],
    );
  }

  Widget _buildManageClubsSection() {
    final clubs = widget.appState.clubs.where((club) {
      return club.name.toLowerCase().contains(_clubSearchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Search clubs by name...',
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                onChanged: (val) => setState(() => _clubSearchQuery = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _showCreateClubDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('NEW CLUB', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        if (clubs.isEmpty)
          const Center(child: Text('No clubs found.'))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: clubs.length,
            itemBuilder: (context, index) {
              final club = clubs[index];
              return _buildAdminClubCard(club);
            },
          ),
      ],
    );
  }

  Widget _buildAdminClubCard(Club club) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                padding: const EdgeInsets.all(4),
                child: club.imageAsset.isNotEmpty
                    ? (club.imageAsset.startsWith('http')
                        ? Image.network(club.imageAsset, fit: BoxFit.contain)
                        : Image.asset(
                            club.imageAsset.startsWith('/')
                                ? 'assets/images${club.imageAsset}'
                                : club.imageAsset,
                            fit: BoxFit.contain,
                          ))
                    : const Icon(Icons.groups_rounded, size: 36, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildCategoryBadge(club.category),
                        _buildDeptBadge('CSE'),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.image_outlined, color: Colors.grey, size: 18),
                    onPressed: () => _pickAndUploadLogoForClub(club),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.tune_outlined, color: Colors.grey, size: 18),
                    onPressed: () => _showEditClubDialog(club),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                    onPressed: () => _showDeleteClubConfirmation(club),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            club.description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CLUB LEADERSHIP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: widget.appState.fetchClubMembers(club.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final members = snapshot.data ?? [];

                    Map<String, dynamic>? findOfficer(String roleKey, String clubEmail, [String advisorName = '']) {
                      final registered = members.where((m) {
                        final r = m['role']?.toString().toLowerCase();
                        if (roleKey == 'club-secretary') {
                          return r == 'club-secretary' || r == 'secretary';
                        }
                        return r == roleKey;
                      }).firstOrNull;

                      if (registered != null) return registered;

                      if (clubEmail.isNotEmpty) {
                        return {
                          'name': advisorName.isNotEmpty ? advisorName : clubEmail.split('@')[0],
                          'email': clubEmail,
                          'role': roleKey,
                        };
                      }

                      return null;
                    }

                    final secretary = findOfficer('club-secretary', club.secretaryEmail);
                    final president = findOfficer('president', club.presidentEmail);
                    final treasurer = findOfficer('treasurer', club.treasurerEmail);
                    final advisor = findOfficer('advisor', club.advisorEmail, club.advisorName);

                    return Column(
                      children: [
                        _buildLeadershipRoleRow(club, 'Secretary', secretary, 'club-secretary'),
                        const Divider(height: 12, thickness: 0.5),
                        _buildLeadershipRoleRow(club, 'President', president, 'president'),
                        const Divider(height: 12, thickness: 0.5),
                        _buildLeadershipRoleRow(club, 'Treasurer', treasurer, 'treasurer'),
                        const Divider(height: 12, thickness: 0.5),
                        _buildLeadershipRoleRow(club, 'Advisor', advisor, 'advisor'),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    Color bgColor = Colors.blue.shade50;
    Color textColor = Colors.blue.shade700;

    switch (category.toLowerCase()) {
      case 'academic':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
      case 'cultural':
        bgColor = Colors.purple.shade50;
        textColor = Colors.purple.shade700;
      case 'sports':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildDeptBadge(String dept) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        dept.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple.shade700,
        ),
      ),
    );
  }

  Widget _buildLeadershipRoleRow(Club club, String roleLabel, Map<String, dynamic>? member, String roleKey) {
    if (member != null) {
      final email = member['email']?.toString() ?? '';
      final name = member['name']?.toString() ?? email;
      final display = name.split('@')[0];

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  '$roleLabel: ',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                ),
                Expanded(
                  child: Text(
                    display,
                    style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Remove $roleLabel'),
                  content: Text('Are you sure you want to remove $name from the $roleLabel role?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                try {
                  await widget.appState.removeClubOfficer(club.id, roleKey);
                  _showSuccessSnackBar('$roleLabel removed successfully!');
                  _reloadSectionData();
                } catch (e) {
                  _showErrorSnackBar('Failed to remove $roleLabel: $e');
                }
              }
            },
            child: const Icon(Icons.close, size: 16, color: Colors.redAccent),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$roleLabel: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
          ),
          GestureDetector(
            onTap: () => _showAssignLeadershipDialog(club, roleLabel, roleKey),
            child: Row(
              children: [
                const Icon(Icons.add, size: 14, color: AppTheme.blue),
                const SizedBox(width: 4),
                Text(
                  'Assign',
                  style: TextStyle(color: AppTheme.blue, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  Future<void> _showAssignLeadershipDialog(Club club, String roleLabel, String roleKey) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        return AlertDialog(
          title: Text('Assign $roleLabel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email (@walchandsangli.ac.in)'),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: navigator.pop, child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final email = emailController.text.trim();
                final name = nameController.text.trim();
                if (email.isEmpty || name.isEmpty) {
                  _showErrorSnackBar('Please fill in both name and email.');
                  return;
                }
                try {
                  await widget.appState.assignOfficer(
                    clubId: club.id,
                    email: email,
                    name: name,
                    role: roleKey,
                  );
                  _showSuccessSnackBar('$roleLabel assigned to $name successfully!');
                  _reloadSectionData();
                  navigator.pop();
                } catch (e) {
                  _showErrorSnackBar('Failed to assign $roleLabel: $e');
                }
              },
              child: const Text('Assign'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickAndUploadLogoForClub(Club club) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _isUploadingLogo = true;
      });
      try {
        final file = File(pickedFile.path);
        final imageUrl = await CloudinaryService.uploadImage(file);
        if (imageUrl != null) {
          await widget.appState.updateClub(club.id, {'image': imageUrl});
          _showSuccessSnackBar('Club logo updated successfully!');
          await widget.appState.refreshAll();
        } else {
          _showErrorSnackBar('Failed to upload image.');
        }
      } catch (e) {
        _showErrorSnackBar('Error uploading image: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isUploadingLogo = false;
          });
        }
      }
    }
  }

  Future<void> _showEditClubDialog(Club club) async {
    final nameController = TextEditingController(text: club.name);
    final fullFormController = TextEditingController(text: club.fullForm);
    final descriptionController = TextEditingController(text: club.description);
    String category = club.category.toLowerCase();
    if (category != 'technical' && category != 'academic' && category != 'cultural' && category != 'sports') {
      category = 'technical';
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        return AlertDialog(
          title: const Text('Edit Club Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Club Name')),
                const SizedBox(height: 12),
                TextField(controller: fullFormController, decoration: const InputDecoration(labelText: 'Full Form')),
                const SizedBox(height: 12),
                TextField(controller: descriptionController, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  items: const [
                    DropdownMenuItem(value: 'technical', child: Text('Technical')),
                    DropdownMenuItem(value: 'academic', child: Text('Academic')),
                    DropdownMenuItem(value: 'cultural', child: Text('Cultural')),
                    DropdownMenuItem(value: 'sports', child: Text('Sports')),
                  ],
                  onChanged: (value) => category = value ?? 'technical',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: navigator.pop, child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  _showErrorSnackBar('Club name cannot be empty');
                  return;
                }
                try {
                  await widget.appState.updateClub(club.id, {
                    'name': name,
                    'fullForm': fullFormController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'category': category,
                  });
                  _showSuccessSnackBar('Club "$name" updated successfully!');
                  navigator.pop();
                  await widget.appState.refreshAll();
                } catch (e) {
                  _showErrorSnackBar('Failed to update club: $e');
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteClubConfirmation(Club club) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Club'),
        content: Text('Are you sure you want to delete ${club.name}? This will remove all members, posts, and details of this club.'),
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
        await widget.appState.deleteClub(club.id);
        _showSuccessSnackBar('Club "${club.name}" deleted successfully!');
        await widget.appState.refreshAll();
      } catch (e) {
        _showErrorSnackBar('Failed to delete club: $e');
      }
    }
  }

  Widget _buildManagePostsSection() {
    final posts = widget.appState.posts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'All Posts & Announcements',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.navy,
          ),
        ),
        const SizedBox(height: 16),
        if (posts.isEmpty)
          const Center(child: Text('No posts found.'))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return _buildAdminPostCard(post);
            },
          ),
      ],
    );
  }

  Widget _buildAdminPostCard(PostItem post) {
    final isEvent = post.isEvent;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(width: 4, height: 85, color: isEvent ? Colors.cyan.shade600 : Colors.orange.shade600),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isEvent ? Colors.cyan.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEvent ? Icons.calendar_today_outlined : Icons.campaign_outlined,
                        color: isEvent ? Colors.cyan.shade700 : Colors.orange.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isEvent
                                      ? Colors.cyan.shade100.withValues(alpha: 0.5)
                                      : Colors.orange.shade100.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isEvent ? 'EVENT' : 'ANNOUNCEMENT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isEvent ? Colors.cyan.shade800 : Colors.orange.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (post.date != null) ...[
                                Icon(Icons.access_time, size: 11, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  '${post.date!.year}-${post.date!.month.toString().padLeft(2, '0')}-${post.date!.day.toString().padLeft(2, '0')}',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            post.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.navy,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Posted by ${post.clubName}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Post'),
                            content: const Text('Are you sure you want to delete this post?'),
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
                            await widget.appState.deletePost(post.id);
                            _showSuccessSnackBar('Post deleted successfully!');
                            _reloadSectionData();
                          } catch (e) {
                            _showErrorSnackBar('Failed to delete post: $e');
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminNotificationsSection() {
    final notifications = widget.appState.notifications;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'System Broadcasts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _showNotificationDialog,
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
              label: const Text('NEW BROADCAST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (notifications.isEmpty)
          const Center(child: Text('No notifications broadcasts found.'))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index];
              return _buildAdminNotificationCard(n);
            },
          ),
      ],
    );
  }

  Widget _buildAdminNotificationCard(NotificationItem n) {
    final typeLabel = n.type.toUpperCase();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NotificationDetailScreen(
              appState: widget.appState,
              notification: n,
            ),
          ),
        ).then((_) => setState(() {}));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(width: 4, height: 95, color: AppTheme.blue),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                typeLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                              if (n.timeAgo.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '•  ${n.timeAgo}',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            n.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.navy,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            n.message,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Broadcast'),
                            content: const Text('Are you sure you want to delete this notification broadcast?'),
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
                            await widget.appState.deleteNotification(n.id);
                            _showSuccessSnackBar('Broadcast notification deleted successfully!');
                            _reloadSectionData();
                          } catch (e) {
                            _showErrorSnackBar('Failed to delete notification: $e');
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildAdminTeachersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(width: 4, height: 18, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Teacher Management',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _showAssignTeacherDialog,
              icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 16),
              label: const Text('Add Teacher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade100),
          ),
          child: Text(
            'Note: Teachers can monitor event reports from clubs they manage. When you add a teacher by email, they will receive an invitation to create their account.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade800,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _teachersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final teachers = snapshot.data ?? [];
            if (teachers.isEmpty) {
              return const Center(child: Text('No teachers assigned.'));
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: teachers.length,
              itemBuilder: (context, index) {
                final teacher = teachers[index];
                return _buildAdminTeacherCard(teacher);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAdminTeacherCard(Map<String, dynamic> teacher) {
    final tId = teacher['_id']?.toString() ?? teacher['id']?.toString() ?? '';
    final name = teacher['name']?.toString() ?? 'Teacher';
    final email = teacher['email']?.toString() ?? '';

    int managedCount = 0;
    if (teacher['monitoredClubs'] is List) {
      managedCount = (teacher['monitoredClubs'] as List).length;
    } else if (teacher['clubs'] is List) {
      managedCount = (teacher['clubs'] as List).length;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Teacher'),
                    content: Text('Are you sure you want to delete teacher $name? This will remove their monitor access.'),
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
                    await widget.appState.deleteTeacher(tId);
                    _showSuccessSnackBar('Teacher "$name" deleted successfully!');
                    setState(() {
                      _teachersFuture = widget.appState.fetchTeachers();
                    });
                  } catch (e) {
                    _showErrorSnackBar('Failed to delete teacher: $e');
                  }
                }
              },
              child: Icon(Icons.delete_outline_rounded, color: Colors.grey.shade400, size: 22),
            ),
          ),
          Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person_outline_rounded, color: Colors.grey.shade400, size: 36),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$managedCount CLUBS MANAGED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── OVERVIEW TAB ──────────────────────────────────────────────────────────
  Widget _buildOverviewView(UserSession session) {
    if (_selectedClub == null) return const SizedBox.shrink();

    final clubPosts = widget.appState.posts.where((p) => p.clubId == _selectedClub!.id).toList();
    final clubEvents = clubPosts.where((p) => p.isEvent).toList();
    final upcomingClubEvents = clubEvents.where((p) => p.isUpcoming).toList();

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _membersFuture ?? Future.value(<Map<String, dynamic>>[]),
        _tasksFuture ?? Future.value(<Map<String, dynamic>>[]),
      ]),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final members = data != null ? data[0] as List<dynamic> : [];
        final tasks = data != null ? data[1] as List<dynamic> : [];
        final activeRole = widget.initialRole ?? session.role;
        final canEdit = activeRole == 'admin' || activeRole == 'advisor' || activeRole == 'president' || activeRole == 'club-secretary';
        final isOfficer = activeRole == 'president' || activeRole == 'club-secretary' || activeRole == 'treasurer';

        // Find next upcoming club event
        PostItem? nextUpcoming;
        if (upcomingClubEvents.isNotEmpty) {
          upcomingClubEvents.sort((a, b) {
            final dateA = a.date ?? DateTime.now();
            final dateB = b.date ?? DateTime.now();
            return dateA.compareTo(dateB);
          });
          nextUpcoming = upcomingClubEvents.first;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Club Header Block (Image 2 layout)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade100, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.015),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Club Logo
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: _selectedClub!.imageAsset.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _selectedClub!.imageAsset.startsWith('http')
                                ? Image.network(_selectedClub!.imageAsset, fit: BoxFit.contain)
                                : Image.asset(
                                    _selectedClub!.imageAsset.startsWith('/')
                                        ? 'assets/images${_selectedClub!.imageAsset}'
                                        : _selectedClub!.imageAsset,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.groups_rounded, color: AppTheme.blue),
                                  ),
                          )
                        : const Icon(Icons.groups_rounded, color: AppTheme.blue, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedClub!.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedClub!.fullForm.isNotEmpty
                              ? _selectedClub!.fullForm
                              : _selectedClub!.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFDDD6FE), width: 1),
                          ),
                          child: Text(
                            (widget.initialRole ?? session.role).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7C3AED),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Stat Counters Row (Image 2 layout)
            Row(
              children: [
                Expanded(
                  child: _MiniStatCard(
                    icon: Icons.groups_outlined,
                    iconColor: const Color(0xFF6366F1),
                    bgColor: const Color(0xFFEEF2FF),
                    value: '${members.length}',
                    label: 'Members',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStatCard(
                    icon: Icons.calendar_month_outlined,
                    iconColor: const Color(0xFF10B981),
                    bgColor: const Color(0xFFE6FDF5),
                    value: '${clubEvents.length}',
                    label: 'Events',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStatCard(
                    icon: Icons.edit_note_outlined,
                    iconColor: const Color(0xFFEC4899),
                    bgColor: const Color(0xFFFDF2F8),
                    value: '${clubPosts.length}',
                    label: 'Posts',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStatCard(
                    icon: Icons.playlist_add_check_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    bgColor: const Color(0xFFFFFBEB),
                    value: '${tasks.length}',
                    label: 'Tasks',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 3. Quick Actions Section (Image 2 layout)
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(height: 12),

            // Action Tiles List depending on user roles
            if (activeRole == 'advisor') ...[
              _QuickActionTile(
                title: 'Events',
                subtitle: 'Manage and schedule club events',
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFF10B981),
                bgColor: const Color(0xFFE6FDF5),
                onTap: () => setState(() => _selectedSection = 'Events'),
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                title: 'Reports',
                subtitle: 'View event reports',
                icon: Icons.file_copy_outlined,
                iconColor: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFFFBEB),
                onTap: () => setState(() => _selectedSection = 'Reports'),
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                title: 'Budgets',
                subtitle: 'Verify and view event budgets',
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFEF2F2),
                onTap: () => setState(() => _selectedSection = 'Budgets'),
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                title: 'Team',
                subtitle: 'Manage club officers',
                icon: Icons.people_rounded,
                iconColor: const Color(0xFF6366F1),
                bgColor: const Color(0xFFEEF2FF),
                onTap: () => setState(() => _selectedSection = 'Team'),
              ),
            ] else if (activeRole == 'treasurer') ...[
              _QuickActionTile(
                title: 'Members',
                subtitle: 'View and manage club members',
                icon: Icons.groups_outlined,
                iconColor: const Color(0xFF6366F1),
                bgColor: const Color(0xFFEEF2FF),
                onTap: () => setState(() => _selectedSection = 'Members'),
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                title: 'Tasks',
                subtitle: 'View and assign club tasks',
                icon: Icons.playlist_add_check_rounded,
                iconColor: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFFFBEB),
                onTap: () => setState(() => _selectedSection = 'Tasks'),
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                title: 'Messages',
                subtitle: 'Chat with club members',
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: const Color(0xFF06B6D4),
                bgColor: const Color(0xFFECFEFF),
                onTap: () => setState(() => _selectedSection = 'Live Chat'),
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                title: 'Budgets',
                subtitle: 'Verify and view event budgets',
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFEF2F2),
                onTap: () => setState(() => _selectedSection = 'Budgets'),
              ),
            ] else ...[
              _QuickActionTile(
                title: 'Members',
                subtitle: 'View and manage club members',
                icon: Icons.groups_outlined,
                iconColor: const Color(0xFF6366F1),
                bgColor: const Color(0xFFEEF2FF),
                onTap: () => setState(() => _selectedSection = 'Members'),
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                title: 'Drafts & Posts',
                subtitle: 'Manage and create announcements',
                icon: Icons.edit_note_rounded,
                iconColor: const Color(0xFFEC4899),
                bgColor: const Color(0xFFFDF2F8),
                onTap: () => setState(() => _selectedSection = 'Posts & Announcements'),
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                title: 'Events',
                subtitle: 'Manage and schedule club events',
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFF10B981),
                bgColor: const Color(0xFFE6FDF5),
                onTap: () => setState(() => _selectedSection = 'Events'),
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                title: 'Tasks',
                subtitle: 'Assign and track club tasks',
                icon: Icons.playlist_add_check_rounded,
                iconColor: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFFFBEB),
                onTap: () => setState(() => _selectedSection = 'Tasks'),
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                title: 'Messages',
                subtitle: 'Chat with club members',
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: const Color(0xFF06B6D4),
                bgColor: const Color(0xFFECFEFF),
                onTap: () => setState(() => _selectedSection = 'Live Chat'),
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                title: 'Notifications',
                subtitle: 'Broadcast alerts and notices',
                icon: Icons.notifications_none_rounded,
                iconColor: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF5F3FF),
                onTap: () => setState(() => _selectedSection = 'Notifications'),
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                title: 'Budget',
                subtitle: 'Submit or verify event budgets',
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFEF2F2),
                onTap: () => setState(() => _selectedSection = 'Budgets'),
              ),
            ],
            const SizedBox(height: 24),

            // 4. Upcoming Event Section (Image 2 layout)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upcoming Event',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navy,
                  ),
                ),
                if (upcomingClubEvents.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selectedSection = 'Events'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.blue)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (nextUpcoming == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100, width: 1.5),
                ),
                alignment: Alignment.center,
                child: const Text('No upcoming events scheduled.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              )
            else
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(
                        appState: widget.appState,
                        initialPost: nextUpcoming!,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.015),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Date Block
                      Container(
                        width: 54,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _getMonthName(nextUpcoming.date),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.blue,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${nextUpcoming.date?.day ?? ""}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nextUpcoming.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.navy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nextUpcoming.time ?? 'TBD',
                              style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                            ),
                            Text(
                              nextUpcoming.location ?? 'Campus',
                              style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                            ),
                          ],
                        ),
                      ),

                      // Going badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Going',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Secondary: WhatsApp / Instagram Profile and template links
            const Text(
              'Social & Configurations',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.navy),
            ),
            const SizedBox(height: 10),
            _buildProfilePictureCard(canEdit),
            _buildWhatsAppCard(canEdit),
            _buildInstagramCard(canEdit),
          ],
        );
      },
    );
  }

  String _getMonthName(DateTime? date) {
    if (date == null) return "MAY";
    const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
    if (date.month >= 1 && date.month <= 12) {
      return months[date.month - 1];
    }
    return "MAY";
  }

  Future<void> _updateClubField(Map<String, dynamic> updates) async {
    if (_selectedClub == null) return;
    try {
      final updatedClub = await widget.appState.updateClub(_selectedClub!.id, updates);
      setState(() {
        _selectedClub = updatedClub;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update club: $e')),
        );
      }
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

  Widget _buildAdvisorDashboardView(UserSession session) {
    if (_selectedClub == null) return const SizedBox.shrink();

    final clubPosts = widget.appState.posts.where((p) => p.clubId == _selectedClub!.id).toList();
    final clubEvents = clubPosts.where((p) => p.isEvent).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Advisor Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(6),
                child: _selectedClub!.imageAsset.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _selectedClub!.imageAsset.startsWith('http')
                            ? Image.network(_selectedClub!.imageAsset, fit: BoxFit.contain)
                            : Image.asset(
                                _selectedClub!.imageAsset.startsWith('/')
                                    ? 'assets/images${_selectedClub!.imageAsset}'
                                    : _selectedClub!.imageAsset,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.groups_rounded, color: AppTheme.blue),
                              ),
                      )
                    : const Icon(Icons.groups_rounded, color: AppTheme.blue, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Advisor Dashboard',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage event posts, budgets, and team members for ${_selectedClub!.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
                      ),
                      child: const Text(
                        'ADVISOR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 2. Segmented Pill Tab Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Events', 'Reports', 'Budgets', 'Team'].map((tab) {
              final isActive = _advisorActiveTab == tab;
              IconData tabIcon = Icons.event_rounded;
              if (tab == 'Reports') tabIcon = Icons.file_copy_rounded;
              if (tab == 'Budgets') tabIcon = Icons.account_balance_wallet_rounded;
              if (tab == 'Team') tabIcon = Icons.people_rounded;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tabIcon,
                        size: 16,
                        color: isActive ? Colors.white : AppTheme.navy.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(tab),
                    ],
                  ),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isActive ? Colors.white : AppTheme.navy,
                  ),
                  selected: isActive,
                  selectedColor: AppTheme.blue,
                  backgroundColor: Colors.grey.shade100,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _advisorActiveTab = tab;
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),

        // 3. Tab Contents
        if (_advisorActiveTab == 'Events')
          _buildAdvisorEventsTab(clubEvents)
        else if (_advisorActiveTab == 'Reports')
          _buildAdvisorReportsTab()
        else if (_advisorActiveTab == 'Budgets')
          _buildAdvisorBudgetsTab(clubEvents)
        else if (_advisorActiveTab == 'Team')
          _buildAdvisorTeamTab(),
      ],
    );
  }

  // ─── TEACHER DASHBOARD IMPLEMENTATION ─────────────────────────────────────
  
  void _downloadAllReports(String clubId) {
    final clubReports = _allReports.where((r) => r['clubId'] == clubId).toList();
    if (clubReports.isEmpty) {
      _showErrorSnackBar('No reports available to download.');
      return;
    }
    for (final report in clubReports) {
      final url = report['reportUrl']?.toString() ?? '';
      if (url.isNotEmpty) {
        Share.share(url, subject: '${report['eventTitle'] ?? 'Event'} Report');
      }
    }
    _showSuccessSnackBar('Sharing ${clubReports.length} report(s)...');
  }

  void _showTeacherTabSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_copy_rounded, color: AppTheme.blue),
              title: const Text('Event Reports', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                setState(() => _teacherActiveTab = 'Reports');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_rounded, color: AppTheme.purple),
              title: const Text('Members', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                setState(() => _teacherActiveTab = 'Members');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherDashboardOverview(UserSession session) {
    return RefreshIndicator(
      onRefresh: () async {
        final monitored = await widget.appState.fetchTeacherClubs();
        final reports = await widget.appState.fetchTeacherReports();
        final List<Club> loaded = [];
        for (final m in monitored) {
          final id = m['_id']?.toString() ?? m['id']?.toString() ?? '';
          final match = widget.appState.clubs.where((c) => c.id == id).toList();
          if (match.isNotEmpty) loaded.add(match.first);
        }
        setState(() {
          _monitoredClubs = loaded;
          _allReports = reports;
        });
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Teacher Dashboard',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Monitor club event reports and activities',
                      style: TextStyle(fontSize: 12, color: AppTheme.muted),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _showAddMonitoredClubDialog,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_monitoredClubs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 60),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No Monitored Clubs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text('Please add a club to monitor first.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _showAddMonitoredClubDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Club to Monitor'),
                    )
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _monitoredClubs.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (context, index) {
                  final club = _monitoredClubs[index];
                  final reportCount = _allReports.where((r) => r['clubId'] == club.id).length;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.015),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: club.imageAsset.isNotEmpty
                                    ? (club.imageAsset.startsWith('http')
                                        ? Image.network(club.imageAsset, fit: BoxFit.contain)
                                        : Image.asset(
                                            club.imageAsset.startsWith('/')
                                                ? 'assets/images${club.imageAsset}'
                                                : club.imageAsset,
                                            fit: BoxFit.contain,
                                          ))
                                    : const Icon(Icons.groups_rounded, color: AppTheme.blue, size: 16),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    club.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navy),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.file_copy_outlined, size: 10, color: Colors.cyan),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$reportCount reports',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _confirmRemoveMonitoredClub(club),
                              child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 18),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 28,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: EdgeInsets.zero,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedClub = club;
                                      _teacherActiveTab = 'Overview';
                                      _reloadSectionData();
                                    });
                                  },
                                  child: const Text('View Details', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                            if (reportCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.download_rounded, size: 14, color: Color(0xFF2563EB)),
                                  onPressed: () => _downloadAllReports(club.id),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherClubDetailsView(UserSession session) {
    final clubReportCount = _allReports.where((r) => r['clubId'] == _selectedClub!.id).length;

    // If a tab is selected (not on overview), show that tab content directly
    if (_teacherActiveTab != 'Overview') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _teacherActiveTab = 'Overview'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: AppTheme.blue),
                SizedBox(width: 4),
                Text(
                  'Back to Overview',
                  style: TextStyle(color: AppTheme.blue, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _teacherActiveTab == 'Reports'
              ? _buildTeacherReportsTab()
              : _buildTeacherMembersTab(),
        ],
      );
    }

    // Overview layout (admin-style)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _selectedClub = null),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: AppTheme.blue),
              SizedBox(width: 4),
              Text(
                'Back to Dashboard',
                style: TextStyle(color: AppTheme.blue, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Club Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(6),
                child: _selectedClub!.imageAsset.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _selectedClub!.imageAsset.startsWith('http')
                            ? Image.network(_selectedClub!.imageAsset, fit: BoxFit.contain)
                            : Image.asset(
                                _selectedClub!.imageAsset.startsWith('/')
                                    ? 'assets/images${_selectedClub!.imageAsset}'
                                    : _selectedClub!.imageAsset,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.groups_rounded, color: AppTheme.blue),
                              ),
                      )
                    : const Icon(Icons.groups_rounded, color: AppTheme.blue, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedClub!.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedClub!.fullForm.isNotEmpty
                          ? _selectedClub!.fullForm
                          : 'Monitor club reports and activities',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFDDD6FE), width: 1),
                      ),
                      child: const Text(
                        'TEACHER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7C3AED),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Stat Cards
        Row(
          children: [
            Expanded(
              child: _MiniStatCard(
                icon: Icons.file_copy_outlined,
                iconColor: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFFFBEB),
                value: '$clubReportCount',
                label: 'Reports',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Quick Actions
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.navy,
          ),
        ),
        const SizedBox(height: 12),
        _QuickActionTile(
          title: 'Event Reports',
          subtitle: 'View event reports for this club',
          icon: Icons.file_copy_outlined,
          iconColor: const Color(0xFFF59E0B),
          bgColor: const Color(0xFFFFFBEB),
          onTap: () => setState(() => _teacherActiveTab = 'Reports'),
        ),
        const SizedBox(height: 10),
        _QuickActionTile(
          title: 'Members',
          subtitle: 'View club members',
          icon: Icons.groups_outlined,
          iconColor: const Color(0xFF6366F1),
          bgColor: const Color(0xFFEEF2FF),
          onTap: () => setState(() => _teacherActiveTab = 'Members'),
        ),
      ],
    );
  }

  Widget _buildTeacherReportsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _reportsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading reports: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        final reports = snapshot.data ?? [];
        
        var filteredReports = reports;
        if (_teacherReportYearFilter != 'All Years') {
          filteredReports = reports.where((r) {
            final dateStr = r['eventDate']?.toString() ?? r['reportSubmittedAt']?.toString();
            return dateStr != null && dateStr.startsWith(_teacherReportYearFilter);
          }).toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Event Reports',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navy),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _teacherReportYearFilter,
                          style: const TextStyle(fontSize: 12, color: AppTheme.navy, fontWeight: FontWeight.bold),
                          items: ['All Years', '2026', '2027', '2028'].map((y) {
                            return DropdownMenuItem(value: y, child: Text(y));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _teacherReportYearFilter = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _downloadAllReports(_selectedClub!.id),
                      icon: const Icon(Icons.download_rounded, size: 14),
                      label: const Text('Download All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (filteredReports.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100, width: 1.5),
                ),
                child: Column(
                  children: [
                    Icon(Icons.file_copy_outlined, size: 44, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    const Text('No reports available.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredReports.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final report = filteredReports[index];
                  final eventDate = report['eventDate'] != null ? DateTime.tryParse(report['eventDate'].toString()) : null;
                  final submittedAt = report['reportSubmittedAt'] != null ? DateTime.tryParse(report['reportSubmittedAt'].toString()) : null;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100, width: 1.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE0F7FA),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.file_copy_rounded, color: Colors.cyan, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report['eventTitle']?.toString() ?? 'Untitled Event',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navy),
                              ),
                              const SizedBox(height: 2),
                              const Text('ID: N/A', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_month_outlined, size: 12, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Event Date: ${eventDate != null ? eventDate.toLocal().toString().split(' ')[0] : '10/01/2026'}',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        'By: ${report['reportSubmittedByName']?.toString() ?? 'Club Officer'}',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 12, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Submitted: ${submittedAt != null ? submittedAt.toLocal().toString().split(' ')[0] : '26/02/2026'}',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.download_rounded, size: 16, color: Colors.grey),
                            onPressed: () {
                              final url = report['reportUrl']?.toString() ?? '';
                              if (url.isNotEmpty) {
                                Share.share(url, subject: '${report['eventTitle'] ?? 'Event'} Report');
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildTeacherMembersTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _membersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading members: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        final members = snapshot.data ?? [];

        var filteredMembers = members;
        if (_teacherYearFilter != 'All Years') {
          filteredMembers = filteredMembers.where((m) {
            final joined = m['joinedAt']?.toString() ?? '';
            final acYear = m['academicYear']?.toString() ?? '';
            return joined.contains(_teacherYearFilter) || acYear.contains(_teacherYearFilter);
          }).toList();
        }
        if (_teacherBoardFilter != 'All Boards') {
          String type = 'member';
          if (_teacherBoardFilter.contains('Main')) type = 'main';
          if (_teacherBoardFilter.contains('Executive')) type = 'executive';
          
          filteredMembers = filteredMembers.where((m) {
            final bType = m['boardType']?.toString().toLowerCase() ?? 'member';
            return bType == type;
          }).toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selectedClub!.name} Members',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navy),
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _exportRoster(filteredMembers.cast<Map<String, dynamic>>()),
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text('Export', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _teacherYearFilter,
                        isExpanded: true,
                        style: const TextStyle(fontSize: 12, color: AppTheme.navy, fontWeight: FontWeight.bold),
                        items: ['All Years', '2026', '2027', '2028'].map((y) {
                          return DropdownMenuItem(value: y, child: Text(y));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _teacherYearFilter = val);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _teacherBoardFilter,
                        isExpanded: true,
                        style: const TextStyle(fontSize: 12, color: AppTheme.navy, fontWeight: FontWeight.bold),
                        items: ['All Boards', 'Main Board (TY)', 'Executive Board (SY)', 'Member Board (FY)'].map((b) {
                          return DropdownMenuItem(value: b, child: Text(b));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _teacherBoardFilter = val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (filteredMembers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100, width: 1.5),
                ),
                child: Column(
                  children: [
                    Icon(Icons.groups_outlined, size: 44, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    const Text('No members found matching filters.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredMembers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final member = filteredMembers[index];
                  final name = member['name']?.toString() ?? 'Member';
                  final email = member['email']?.toString() ?? '';
                  final role = member['role']?.toString() ?? 'Member';
                  final boardType = member['boardType']?.toString() ?? 'member';
                  
                  String boardLabel = 'Member Board (FY)';
                  if (boardType == 'main') boardLabel = 'Main Board (TY)';
                  if (boardType == 'executive') boardLabel = 'Executive Board (SY)';

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navy),
                            ),
                            const SizedBox(width: 8),
                            _buildPill(boardLabel),
                            if (role != 'Member') ...[
                              const SizedBox(width: 6),
                              _buildPill(role),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 12, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(email, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined, size: 12, color: Colors.grey),
                            const SizedBox(width: 6),
                            const Text('Joined: 06/02/2026', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
      ),
    );
  }

  void _confirmRemoveMonitoredClub(Club club) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop Monitoring?'),
        content: Text('Are you sure you want to remove "${club.name}" from your monitored clubs list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.appState.removeTeacherClub(club.id);
                _showSuccessSnackBar('Club "${club.name}" removed successfully!');
                _initializeDashboard(); // Reload monitored clubs list
              } catch (e) {
                _showErrorSnackBar('Failed to remove club: $e');
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisorEventsTab(List<PostItem> clubEvents) {
    final now = DateTime.now();
    final totalEvents = clubEvents.length;
    final upcomingEvents = clubEvents.where((e) => e.date != null && e.date!.isAfter(now)).length;
    final pastEvents = clubEvents.where((e) => e.date != null && e.date!.isBefore(now)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Stats Row
        Row(
          children: [
            Expanded(
              child: _MiniStatCard(
                icon: Icons.calendar_month_outlined,
                iconColor: const Color(0xFF06B6D4),
                bgColor: const Color(0xFFECFEFF),
                value: '$totalEvents',
                label: 'Total Events',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniStatCard(
                icon: Icons.schedule_rounded,
                iconColor: const Color(0xFF10B981),
                bgColor: const Color(0xFFE6FDF5),
                value: '$upcomingEvents',
                label: 'Upcoming',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniStatCard(
                icon: Icons.history_rounded,
                iconColor: const Color(0xFF64748B),
                bgColor: const Color(0xFFF1F5F9),
                value: '$pastEvents',
                label: 'Past',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // 2. Events List
        const Text(
          'Club Events',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navy),
        ),
        const SizedBox(height: 12),
        if (clubEvents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100, width: 1.5),
            ),
            child: Column(
              children: [
                Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                const Text('No events found for your club.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: clubEvents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final event = clubEvents[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100, width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.calendar_month_rounded, size: 14, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(
                                event.date != null ? event.date!.toLocal().toString().split(' ')[0] : 'N/A',
                                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.people_alt_rounded, size: 14, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(
                                '${event.rsvps ?? 0} RSVPs',
                                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, color: AppTheme.blue),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostDetailScreen(
                              appState: widget.appState,
                              initialPost: event,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildAdvisorReportsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _reportsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading reports: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        final reports = snapshot.data ?? [];
        if (reports.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100, width: 1.5),
            ),
            child: Column(
              children: [
                Icon(Icons.file_copy_outlined, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                const Text('No reports available.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reports.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final report = reports[index];
            final submittedAt = report['reportSubmittedAt'] != null
                ? DateTime.tryParse(report['reportSubmittedAt'].toString())
                : null;
            final eventDate = report['eventDate'] != null
                ? DateTime.tryParse(report['eventDate'].toString())
                : null;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          report['eventTitle']?.toString() ?? 'Untitled Event',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_all_rounded, color: AppTheme.blue),
                        onPressed: () {
                          final url = report['reportUrl']?.toString() ?? '';
                          if (url.isNotEmpty) {
                            _copyLink('Report PDF', url);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('Submitted By: ', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                            Text(
                              report['reportSubmittedByName']?.toString() ?? 'Unknown',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.navy),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Event Date: ', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                            Text(
                              eventDate != null ? eventDate.toLocal().toString().split(' ')[0] : 'N/A',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.navy),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Submitted: ', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                            Text(
                              submittedAt != null ? submittedAt.toLocal().toString().split(' ')[0] : 'N/A',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.navy),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAdvisorBudgetsTab(List<PostItem> clubEvents) {
    final budgetedEvents = clubEvents.where((e) => e.budgetImageUrl != null && e.budgetImageUrl!.isNotEmpty).toList();

    if (budgetedEvents.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            const Text('No budgets have been submitted yet.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: budgetedEvents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final event = budgetedEvents[index];
        final isVerified = event.budgetVerified ?? false;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isVerified ? Icons.check_circle_rounded : Icons.pending_rounded,
                          size: 12,
                          color: isVerified ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isVerified ? 'Verified' : 'Pending',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isVerified ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                      label: const Text('View Receipt'),
                      onPressed: () {
                        if (event.budgetImageUrl != null) {
                          _copyLink('Budget Receipt', event.budgetImageUrl!);
                        }
                      },
                    ),
                  ),
                  if (!isVerified) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text('Verify'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          final success = await widget.appState.verifyEventBudget(event.id);
                          if (success) {
                            _showSuccessSnackBar('Budget verified successfully!');
                            await widget.appState.refreshAll();
                            _reloadSectionData();
                          } else {
                            _showErrorSnackBar('Failed to verify budget.');
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdvisorTeamTab() {
    if (_selectedClub == null) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Club Officers',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navy),
        ),
        const SizedBox(height: 12),
        
        _buildOfficerCard('President', _selectedClub!.presidentEmail),
        const SizedBox(height: 12),
        _buildOfficerCard('Secretary', _selectedClub!.secretaryEmail),
        const SizedBox(height: 12),
        _buildOfficerCard('Treasurer', _selectedClub!.treasurerEmail),
      ],
    );
  }

  Widget _buildOfficerCard(String role, String email) {
    final isAssigned = email.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navy),
                ),
                const SizedBox(height: 2),
                Text(
                  isAssigned ? email : 'Not Assigned',
                  style: TextStyle(fontSize: 12, color: isAssigned ? AppTheme.muted : Colors.red.shade400),
                ),
              ],
            ),
          ),
          if (isAssigned)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: () => _confirmRemoveOfficer(role),
            )
          else
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.blue),
              onPressed: () => _showAssignOfficerDialog(role),
            ),
        ],
      ),
    );
  }

  void _confirmRemoveOfficer(String role) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Remove $role'),
          content: Text('Are you sure you want to remove the $role? This will unlink their account from the club.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await widget.appState.removeClubOfficer(_selectedClub!.id, role.toLowerCase());
                  _showSuccessSnackBar('$role removed successfully!');
                  await widget.appState.refreshAll();
                  _reloadSectionData();
                } catch (e) {
                  _showErrorSnackBar('Failed to remove officer: $e');
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showAssignOfficerDialog(String role) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Assign $role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter officer\'s full name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'Enter officer\'s college email',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('Assign'),
              onPressed: () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                if (name.isEmpty || email.isEmpty) {
                  _showErrorSnackBar('Please fill in all fields.');
                  return;
                }
                Navigator.pop(context);
                try {
                  await widget.appState.assignOfficer(
                    clubId: _selectedClub!.id,
                    email: email,
                    name: name,
                    role: role.toLowerCase() == 'secretary' ? 'club-secretary' : role.toLowerCase(),
                  );
                  _showSuccessSnackBar('$role assigned successfully!');
                  await widget.appState.refreshAll();
                  _reloadSectionData();
                } catch (e) {
                  _showErrorSnackBar('Failed to assign officer: $e');
                }
              },
            ),
          ],
        );
      },
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

  Widget _buildProfilePictureCard(bool isOfficer) {
    if (_selectedClub == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              const Icon(Icons.image_outlined, color: Colors.purple, size: 20),
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
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: _isUploadingLogo
                      ? const Center(child: CircularProgressIndicator())
                      : _selectedClub!.imageAsset.isNotEmpty
                          ? _selectedClub!.imageAsset.startsWith('http')
                              ? Image.network(_selectedClub!.imageAsset, fit: BoxFit.contain)
                              : Image.asset(
                                  _selectedClub!.imageAsset.startsWith('/')
                                      ? 'assets/images${_selectedClub!.imageAsset}'
                                      : _selectedClub!.imageAsset,
                                  fit: BoxFit.contain,
                                )
                          : const Icon(Icons.groups_rounded, size: 48, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                if (isOfficer) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isUploadingLogo ? null : _pickAndUploadLogo,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Upload from Device'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppCard(bool isOfficer) {
    if (_selectedClub == null) return const SizedBox.shrink();
    final hasLink = _selectedClub!.whatsappUrl.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green, size: 20),
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
                    currentValue: _selectedClub!.whatsappUrl,
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _selectedClub!.whatsappUrl,
                style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.copy_rounded, size: 20),
              onTap: () => _copyLink('WhatsApp', _selectedClub!.whatsappUrl),
            )
          else if (isOfficer)
            GestureDetector(
              onTap: () => _showLinkDialog(
                title: 'Add WhatsApp Link',
                fieldKey: 'whatsappUrl',
                currentValue: '',
              ),
              child: CustomPaint(
                painter: DashedBorderPainter(color: Colors.grey.shade400, gap: 6),
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
            )
          else
            const Text(
              'No WhatsApp link provided by the club.',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  Widget _buildInstagramCard(bool isOfficer) {
    if (_selectedClub == null) return const SizedBox.shrink();
    final hasLink = _selectedClub!.instagramUrl.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              const Icon(Icons.camera_alt_outlined, color: Colors.pink, size: 20),
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
                    currentValue: _selectedClub!.instagramUrl,
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _selectedClub!.instagramUrl,
                style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.copy_rounded, size: 20),
              onTap: () => _copyLink('Instagram', _selectedClub!.instagramUrl),
            )
          else if (isOfficer)
            GestureDetector(
              onTap: () => _showLinkDialog(
                title: 'Add Instagram Page',
                fieldKey: 'instagramUrl',
                currentValue: '',
              ),
              child: CustomPaint(
                painter: DashedBorderPainter(color: Colors.grey.shade400, gap: 6),
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
            )
          else
            const Text(
              'No Instagram link provided by the club.',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  // ─── MEMBERS TAB ───────────────────────────────────────────────────────────
  Widget _buildMembersView(UserSession session) {
    final activeRole = widget.initialRole ?? session.role;
    final canEdit = activeRole == 'admin' || activeRole == 'advisor' || activeRole == 'president' || activeRole == 'club-secretary';
    final isTreasurer = activeRole == 'treasurer';
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _membersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final members = snapshot.data ?? [];
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Club Members (${members.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (canEdit)
                  FilledButton.icon(
                    onPressed: () => _showAddMemberDialog(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Member'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
              ],
            ),
            if (canEdit || isTreasurer) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (canEdit) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.file_upload_outlined, size: 16),
                        label: const Text('Import Excel/CSV', style: TextStyle(fontSize: 12)),
                        onPressed: () => _importRoster(),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.file_download_outlined, size: 16),
                      label: const Text('Export Roster', style: TextStyle(fontSize: 12)),
                      onPressed: () => _exportRoster(members),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (members.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No members found.')))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final m = members[index];
                  final mId = m['_id']?.toString() ?? m['id']?.toString() ?? '';
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text((m['name']?.toString() ?? 'U')[0].toUpperCase()),
                      ),
                      title: Text(m['name']?.toString() ?? 'Member', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${m['role'] ?? 'Member'} · ${m['email'] ?? ''}'),
                      trailing: canEdit
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => _showAddMemberDialog(member: m),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.person_remove_outlined, color: Colors.red, size: 18),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Remove Member'),
                                        content: Text('Are you sure you want to remove ${m['name']}?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                          FilledButton(
                                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                            onPressed: () => Navigator.of(ctx).pop(true),
                                            child: const Text('Remove'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      try {
                                        await widget.appState.removeClubMember(_selectedClub!.id, mId);
                                        _showSuccessSnackBar('Member "${m['name']}" removed successfully!');
                                        _reloadSectionData();
                                      } catch (e) {
                                        _showErrorSnackBar('Failed to remove member: $e');
                                      }
                                    }
                                  },
                                ),
                              ],
                            )
                          : null,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _importRoster() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;

      _showSuccessSnackBar('Importing spreadsheet roster...');
      final response = await widget.appState.bulkImportMembers(_selectedClub!.id, path);

      _reloadSectionData();

      if (response != null && response['summary'] != null) {
        final summary = response['summary'];
        _showSuccessSnackBar('Import complete! Added: ${summary['added']}, Failed: ${summary['failed']}.');
      } else {
        _showSuccessSnackBar('Roster bulk imported successfully.');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to import roster: $e');
    }
  }

  void _exportRoster(List<Map<String, dynamic>> members) {
    if (members.isEmpty) {
      _showErrorSnackBar('Roster is empty.');
      return;
    }
    final csv = StringBuffer();
    csv.writeln('Name,Email,Role,Board Type,Academic Year');
    for (final m in members) {
      csv.writeln('"${m['name'] ?? ''}","${m['email'] ?? ''}","${m['role'] ?? ''}","${m['boardType'] ?? ''}","${m['academicYear'] ?? ''}"');
    }

    Share.share(csv.toString(), subject: '${_selectedClub?.name ?? 'Club'} Member Roster');
    _showSuccessSnackBar('Roster CSV generated. Opening sharing options...');
  }

  // ─── DRAFTS & POSTS TAB ────────────────────────────────────────────────────
  Widget _buildPostsView(UserSession session) {
    final activeRole = widget.initialRole ?? session.role;
    final canEdit = activeRole == 'admin' || activeRole == 'advisor' || activeRole == 'president' || activeRole == 'club-secretary';
    final clubPosts = widget.appState.posts.where((p) => p.clubId == _selectedClub!.id).toList();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Announcements & Posts (${clubPosts.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (canEdit)
              FilledButton.icon(
                onPressed: () => _showCreatePostDialog(_selectedClub!, isEvent: false),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Post'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (clubPosts.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No posts found.')))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: clubPosts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final post = clubPosts[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Icon(post.isEvent ? Icons.event : Icons.campaign_outlined, color: AppTheme.blue),
                  ),
                  title: Text(post.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(post.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text(post.isEvent ? 'Event' : 'Announcement', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  trailing: canEdit
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
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
                                _reloadSectionData();
                              } catch (e) {
                                _showErrorSnackBar('Failed to delete post: $e');
                              }
                            }
                          },
                        )
                      : null,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(appState: widget.appState, initialPost: post),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ─── EVENTS TAB ────────────────────────────────────────────────────────────
  Widget _buildEventsView(UserSession session) {
    final activeRole = widget.initialRole ?? session.role;
    final canEdit = activeRole == 'admin' || activeRole == 'advisor' || activeRole == 'president' || activeRole == 'club-secretary';
    final clubEvents = widget.appState.posts.where((p) => p.clubId == _selectedClub!.id && p.isEvent).toList();
    final now = DateTime.now();
    final upcoming = clubEvents.where((e) => e.date != null && e.date!.isAfter(now)).toList();
    final past = clubEvents.where((e) => e.date != null && !e.date!.isAfter(now)).toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Club Events',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (canEdit)
                FilledButton.icon(
                  onPressed: () => _showCreatePostDialog(_selectedClub!, isEvent: true),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create Event'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const TabBar(
            labelColor: AppTheme.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.blue,
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 400,
            child: TabBarView(
              children: [
                _buildEventsList(upcoming, canEdit),
                _buildEventsList(past, canEdit),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(List<PostItem> events, bool canEdit) {
    if (events.isEmpty) {
      return const Center(child: Text('No events found.'));
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final e = events[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.event_available)),
            title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(e.date != null ? '${e.date!.day}/${e.date!.month}/${e.date!.year} · ${e.time ?? "All Day"}' : 'No date'),
            trailing: e.rsvps != null ? Chip(label: Text('${e.rsvps} RSVPs')) : null,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(appState: widget.appState, initialPost: e),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── TASKS TAB ─────────────────────────────────────────────────────────────
  Widget _buildTasksView(UserSession session) {
    final activeRole = widget.initialRole ?? session.role;
    final canEdit = activeRole == 'admin' || activeRole == 'advisor' || activeRole == 'president' || activeRole == 'club-secretary';
    final clubEvents = widget.appState.posts.where((p) => p.clubId == _selectedClub!.id && p.isEvent).toList();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _tasksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final tasks = snapshot.data ?? [];
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Club Tasks (${tasks.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (canEdit)
                  FilledButton.icon(
                    onPressed: () => _showCreateTaskDialog(_selectedClub!, clubEvents),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Task'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (tasks.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No active tasks.')))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final t = tasks[index];
                  final taskId = t['_id']?.toString() ?? t['id']?.toString() ?? '';
                  final status = t['status']?.toString() ?? 'pending';

                  Color statusColor = Colors.grey;
                  if (status == 'in-progress') statusColor = Colors.orange;
                  if (status == 'completed') statusColor = Colors.green;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      title: Text(t['title']?.toString() ?? 'Task', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(t['description']?.toString() ?? ''),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      trailing: canEdit
                          ? PopupMenuButton<String>(
                              onSelected: (val) async {
                                try {
                                  if (val == 'delete') {
                                    await widget.appState.deleteTask(taskId);
                                    _showSuccessSnackBar('Task deleted successfully!');
                                  } else {
                                    await widget.appState.updateTask(taskId, {'status': val});
                                    _showSuccessSnackBar('Task status updated to $val successfully!');
                                  }
                                  _reloadSectionData();
                                } catch (e) {
                                  _showErrorSnackBar('Operation failed: $e');
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'pending', child: Text('Mark Pending')),
                                const PopupMenuItem(value: 'in-progress', child: Text('Mark In Progress')),
                                const PopupMenuItem(value: 'completed', child: Text('Mark Completed')),
                                const PopupMenuDivider(),
                                const PopupMenuItem(value: 'delete', child: Text('Delete Task', style: TextStyle(color: Colors.red))),
                              ],
                            )
                          : null,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  // ─── MESSAGES (LIVE CHAT) TAB ──────────────────────────────────────────────
  Widget _buildMessagesView(UserSession session) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _messagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final messages = snapshot.data ?? [];
        
        // Auto-scroll chat to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_chatScrollController.hasClients) {
            _chatScrollController.animateTo(
              _chatScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        return Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Club Board & Live Messages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: messages.isEmpty
                  ? const Center(child: Text('No messages yet. Start the conversation!'))
                  : ListView.builder(
                      controller: _chatScrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        // Reverse ordering to make it feel like standard chat (or correct index)
                        final msg = messages[messages.length - 1 - index];
                        final isMe = msg['senderId'] == session.id;
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? AppTheme.blue : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(12),
                                topRight: const Radius.circular(12),
                                bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                                bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                              ),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${msg['senderName'] ?? 'Officer'} (${msg['senderRole'] ?? ''})",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    color: isMe ? Colors.white70 : Colors.blue.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  msg['body']?.toString() ?? '',
                                  style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: InputDecoration(
                      hintText: 'Type message...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppTheme.blue,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () async {
                      final text = _chatController.text.trim();
                      if (text.isEmpty) return;
                      try {
                        await widget.appState.sendClubMessage(
                          clubId: _selectedClub!.id,
                          title: 'Board Message',
                          body: text,
                        );
                        _chatController.clear();
                        _reloadSectionData();
                      } catch (e) {
                        _showErrorSnackBar('Failed to send message: $e');
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ─── NOTIFICATIONS TAB ─────────────────────────────────────────────────────
  Widget _buildNotificationsView(UserSession session) {
    final activeRole = widget.initialRole ?? session.role;
    final canEdit = activeRole == 'admin' || activeRole == 'advisor' || activeRole == 'president' || activeRole == 'club-secretary';
    final notifications = widget.appState.notifications;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Club Notifications (${notifications.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (canEdit)
              FilledButton.icon(
                onPressed: _showNotificationDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Send Notice'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (notifications.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No notifications found.')))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final n = notifications[index];
              return Container(
                decoration: BoxDecoration(
                  color: n.isRead ? Colors.white : Colors.blue.shade50.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(n.message),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NotificationDetailScreen(
                          appState: widget.appState,
                          notification: n,
                        ),
                      ),
                    ).then((_) => setState(() {}));
                  },
                  trailing: !n.isRead
                      ? TextButton(
                          onPressed: () async {
                            await widget.appState.markNotificationAsRead(n.id);
                            _reloadSectionData();
                          },
                          child: const Text('Mark Read'),
                        )
                      : null,
                ),
              );
            },
          ),
      ],
    );
  }

  // ─── BUDGET TAB ────────────────────────────────────────────────────────────
  Widget _buildBudgetView(UserSession session) {
    final allEvents = widget.appState.posts.where((p) => p.clubId == _selectedClub!.id && p.isEvent).toList();
    final events = allEvents
        .where((p) => (p.budgetImageUrl?.isNotEmpty ?? false))
        .toList();

    final activeRole = widget.initialRole ?? session.role;
    final isVerifier = activeRole == 'admin' || activeRole == 'advisor';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Budget Approvals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (activeRole == 'treasurer')
              TextButton.icon(
                onPressed: () => _showUploadBudgetDialog(allEvents),
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Budget'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No budgets submitted.')))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final ev = events[index];
              final verified = ev.budgetVerified ?? false;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(ev.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (verified ? Colors.green : Colors.blue).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(verified ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded, size: 14, color: verified ? Colors.green : Colors.blue),
                                const SizedBox(width: 4),
                                Text(verified ? 'Verified' : 'Awaiting', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: verified ? Colors.green : Colors.blue)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening: ${ev.budgetImageUrl}'))),
                            icon: const Icon(Icons.visibility_rounded, size: 16),
                            label: const Text('View Budget'),
                          ),
                          if (!verified && isVerifier) ...[
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: Colors.green),
                               onPressed: () async {
                                try {
                                  final ok = await widget.appState.verifyEventBudget(ev.id);
                                  if (ok) {
                                    _showSuccessSnackBar('Budget verified successfully!');
                                    _reloadSectionData();
                                  } else {
                                    _showErrorSnackBar('Failed to verify budget.');
                                  }
                                } catch (e) {
                                  _showErrorSnackBar('Error verifying budget: $e');
                                }
                              },
                              icon: const Icon(Icons.check_circle_rounded, size: 16),
                              label: const Text('Verify'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ─── DIALOGS & POPUPS ──────────────────────────────────────────────────────

  Future<void> _showUploadBudgetDialog(List<PostItem> events) async {
    String? selectedEventId;
    String? uploadedImageUrl;
    bool isUploading = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        return AlertDialog(
          title: const Text('Upload Budget'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedEventId,
                      hint: const Text('Select Event'),
                      isExpanded: true,
                      items: events.map((ev) {
                        return DropdownMenuItem<String>(
                          value: ev.id,
                          child: Text(ev.title, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setStateDialog(() => selectedEventId = val),
                    ),
                    const SizedBox(height: 16),
                    if (uploadedImageUrl != null)
                      Container(
                        height: 100,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(image: NetworkImage(uploadedImageUrl!), fit: BoxFit.cover),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: isUploading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.image),
                        label: Text(isUploading ? 'Uploading...' : 'Select Budget Image'),
                        onPressed: isUploading
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(source: ImageSource.gallery);
                                if (picked != null) {
                                  setStateDialog(() => isUploading = true);
                                  final url = await CloudinaryService.uploadImage(File(picked.path));
                                  setStateDialog(() {
                                    uploadedImageUrl = url;
                                    isUploading = false;
                                  });
                                }
                              },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => navigator.pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedEventId == null || uploadedImageUrl == null) {
                  _showErrorSnackBar('Please select an event and upload an image.');
                  return;
                }
                try {
                  await widget.appState.uploadEventBudget(selectedEventId!, uploadedImageUrl!);
                  _showSuccessSnackBar('Budget uploaded successfully!');
                  navigator.pop();
                  _reloadSectionData();
                } catch (e) {
                  _showErrorSnackBar('Failed to upload budget: $e');
                }
              },
              child: const Text('Upload'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showNotificationDialog() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String type = widget.appState.session?.role == 'admin' ? 'system' : 'club';

    await showDialog<void>(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        return AlertDialog(
          title: const Text('Create Notification'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageController,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Message'),
                    ),
                    _buildMarkdownToolbar(messageController, setStateDialog),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: type,
                      items: const [
                        DropdownMenuItem(value: 'system', child: Text('System')),
                        DropdownMenuItem(value: 'club', child: Text('Club')),
                        DropdownMenuItem(value: 'announcement', child: Text('Announcement')),
                        DropdownMenuItem(value: 'event', child: Text('Event')),
                      ],
                      onChanged: (value) => setStateDialog(() => type = value ?? 'system'),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.appState.createNotification(
                    title: titleController.text.trim(),
                    message: messageController.text.trim(),
                    type: type,
                    clubId: type == 'club' ? _selectedClub?.id : null,
                  );
                  _showSuccessSnackBar('Broadcast notification sent successfully!');
                  navigator.pop();
                  _reloadSectionData();
                } catch (e) {
                  _showErrorSnackBar('Failed to send notification: $e');
                }
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreatePostDialog(Club club, {required bool isEvent}) async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final dateController = TextEditingController();
    final timeController = TextEditingController();
    final locationController = TextEditingController();
    String? coverImageUrl;
    bool isUploading = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        return AlertDialog(
          title: Text(isEvent ? 'Create Event' : 'Create Announcement'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    _buildMarkdownToolbar(contentController, setStateDialog),
                    if (isEvent) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: dateController,
                        decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: timeController,
                        decoration: const InputDecoration(labelText: 'Time'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: locationController,
                        decoration: const InputDecoration(labelText: 'Location'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (coverImageUrl != null)
                      Container(
                        height: 100,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(image: NetworkImage(coverImageUrl!), fit: BoxFit.cover),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: isUploading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.image),
                        label: Text(isUploading ? 'Uploading...' : 'Upload Cover Image'),
                        onPressed: isUploading
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(source: ImageSource.gallery);
                                if (picked != null) {
                                  setStateDialog(() => isUploading = true);
                                  final url = await CloudinaryService.uploadImage(File(picked.path));
                                  setStateDialog(() {
                                    coverImageUrl = url;
                                    isUploading = false;
                                  });
                                }
                              },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.appState.createPost(
                    clubId: club.id,
                    clubName: club.name,
                    title: titleController.text.trim(),
                    content: contentController.text.trim(),
                    type: isEvent ? 'event' : 'announcement',
                    status: 'published',
                    date: isEvent ? dateController.text.trim() : null,
                    time: isEvent ? timeController.text.trim() : null,
                    location: isEvent ? locationController.text.trim() : null,
                    coverImage: coverImageUrl,
                  );
                  _showSuccessSnackBar(isEvent ? 'Event created successfully!' : 'Announcement created successfully!');
                  _reloadSectionData();
                  navigator.pop();
                } catch (e) {
                  _showErrorSnackBar('Failed to create ${isEvent ? 'event' : 'announcement'}: $e');
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateTaskDialog(Club club, List<PostItem> posts) async {
    final members = await widget.appState.fetchClubMembers(club.id);
    if (!mounted) return;

    final titleController = TextEditingController();
    final descController = TextEditingController();
    final deadlineController = TextEditingController();
    final selectedNames = <String>{};
    String relatedEventId = '';

    await showDialog<void>(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        return AlertDialog(
          title: const Text('Create Task'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Task Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: deadlineController,
                      decoration: const InputDecoration(labelText: 'Deadline (YYYY-MM-DD)'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: '',
                      items: [
                        const DropdownMenuItem(value: '', child: Text('No Related Event')),
                        ...posts.where((post) => post.isEvent).map(
                              (post) => DropdownMenuItem(value: post.id, child: Text(post.title)),
                            ),
                      ],
                      onChanged: (value) => setStateDialog(() => relatedEventId = value ?? ''),
                    ),
                    const SizedBox(height: 12),
                    ...members.map((member) {
                      final name = member['name']?.toString() ?? 'Member';
                      return CheckboxListTile(
                        value: selectedNames.contains(name),
                        title: Text(name),
                        subtitle: Text(member['role']?.toString() ?? ''),
                        onChanged: (checked) {
                          setStateDialog(() {
                            if (checked == true) {
                              selectedNames.add(name);
                            } else {
                              selectedNames.remove(name);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final chosenMembers = members.where((m) => selectedNames.contains(m['name']?.toString() ?? ''));
                await widget.appState.createTask(
                  clubId: club.id,
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  assignedTo: chosenMembers.map((m) => m['name'].toString()).toList(),
                  assignedToEmails: chosenMembers.map((m) => m['email'].toString()).toList(),
                  deadline: deadlineController.text.trim(),
                  relatedEventId: relatedEventId.isNotEmpty ? relatedEventId : null,
                  relatedEventTitle: posts.where((p) => p.id == relatedEventId).firstOrNull?.title,
                );
                _reloadSectionData();
                navigator.pop();
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateClubDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final fullFormController = TextEditingController();
    String category = 'technical';
    final selectedDepartments = <String>{};
    String? uploadedImageUrl;
    bool isUploading = false;
    const departments = [
      'Computer Science(CSE)',
      'Electronics',
      'Mechanical',
      'Civil',
      'Artificial Intelligence and Machine Learning(AIML)',
      'Information Technology(IT)',
    ];

    await showDialog<void>(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        return AlertDialog(
          title: const Text('Create Club'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Club Name')),
                    const SizedBox(height: 12),
                    TextField(controller: fullFormController, decoration: const InputDecoration(labelText: 'Full Form')),
                    const SizedBox(height: 12),
                    TextField(controller: descriptionController, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                    const SizedBox(height: 12),
                    if (uploadedImageUrl != null)
                      Container(
                        height: 80,
                        width: 80,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          image: DecorationImage(image: NetworkImage(uploadedImageUrl!), fit: BoxFit.cover),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: isUploading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add_photo_alternate),
                        label: Text(isUploading ? 'Uploading...' : 'Upload Club Logo'),
                        onPressed: isUploading
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(source: ImageSource.gallery);
                                if (picked != null) {
                                  setStateDialog(() => isUploading = true);
                                  final url = await CloudinaryService.uploadImage(File(picked.path));
                                  setStateDialog(() {
                                    uploadedImageUrl = url;
                                    isUploading = false;
                                  });
                                }
                              },
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      items: const [
                        DropdownMenuItem(value: 'technical', child: Text('Technical')),
                        DropdownMenuItem(value: 'academic', child: Text('Academic')),
                        DropdownMenuItem(value: 'cultural', child: Text('Cultural')),
                        DropdownMenuItem(value: 'sports', child: Text('Sports')),
                      ],
                      onChanged: (value) => setStateDialog(() => category = value ?? 'technical'),
                    ),
                    const SizedBox(height: 12),
                    ...departments.map((department) {
                      return CheckboxListTile(
                        value: selectedDepartments.contains(department),
                        title: Text(department),
                        onChanged: (checked) {
                          setStateDialog(() {
                            if (checked == true) {
                              selectedDepartments.add(department);
                            } else {
                              selectedDepartments.remove(department);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: navigator.pop, child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  _showErrorSnackBar('Club name cannot be empty');
                  return;
                }
                try {
                  await widget.appState.createClub(
                    name: name,
                    description: descriptionController.text.trim(),
                    fullForm: fullFormController.text.trim(),
                    category: category,
                    image: uploadedImageUrl ?? '',
                    departments: selectedDepartments.toList(),
                  );
                  _showSuccessSnackBar('Club "$name" created successfully!');
                  navigator.pop();
                } catch (e) {
                  _showErrorSnackBar('Failed to create club: $e');
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAssignTeacherDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        return AlertDialog(
          title: const Text('Assign Teacher'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Teacher Name')),
              const SizedBox(height: 12),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Teacher Email')),
            ],
          ),
          actions: [
            TextButton(onPressed: navigator.pop, child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                if (name.isEmpty || email.isEmpty) {
                  _showErrorSnackBar('Please fill in both name and email.');
                  return;
                }
                try {
                  await widget.appState.assignTeacher(
                    name: name,
                    email: email,
                  );
                  _showSuccessSnackBar('Teacher "$name" assigned successfully!');
                  setState(() {
                    _teachersFuture = widget.appState.fetchTeachers();
                  });
                  navigator.pop();
                } catch (e) {
                  _showErrorSnackBar('Failed to assign teacher: $e');
                }
              },
              child: const Text('Assign'),
            ),
          ],
        );
      },
    );
  }

  void _showAddMemberDialog({Map<String, dynamic>? member}) {
    final isEditing = member != null;
    final nameController = TextEditingController(text: member?['name']?.toString() ?? '');
    final emailController = TextEditingController(text: member?['email']?.toString() ?? '');
    final roleController = TextEditingController(text: member?['role']?.toString() ?? 'Member');
    String boardType = member?['boardType']?.toString() ?? 'member';
    String academicYear = member?['academicYear']?.toString() ?? 'FY';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Member' : 'Add New Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email (@walchandsangli.ac.in)'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: boardType,
                  decoration: const InputDecoration(labelText: 'Board Type'),
                  items: const [
                    DropdownMenuItem(value: 'main', child: Text('Main Board (TY)')),
                    DropdownMenuItem(value: 'executive', child: Text('Executive Board (SY)')),
                    DropdownMenuItem(value: 'member', child: Text('Member Board (FY)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        boardType = val;
                        if (val == 'member') roleController.text = 'Member';
                      });
                    }
                  },
                ),
                if (boardType != 'member')
                  TextField(controller: roleController, decoration: const InputDecoration(labelText: 'Custom Role')),
                DropdownButtonFormField<String>(
                  value: academicYear,
                  decoration: const InputDecoration(labelText: 'Academic Year'),
                  items: const [
                    DropdownMenuItem(value: 'FY', child: Text('FY')),
                    DropdownMenuItem(value: 'SY', child: Text('SY')),
                    DropdownMenuItem(value: 'TY', child: Text('TY')),
                    DropdownMenuItem(value: 'Final Year', child: Text('Final Year')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => academicYear = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                if (name.isEmpty || email.isEmpty) {
                  _showErrorSnackBar('Please fill in both name and email.');
                  return;
                }
                try {
                  if (isEditing) {
                    final mId = member['_id']?.toString() ?? member['id']?.toString() ?? '';
                    await widget.appState.updateClubMember(_selectedClub!.id, mId, {
                      'name': name,
                      'email': email,
                      'role': roleController.text.trim(),
                      'boardType': boardType,
                      'academicYear': academicYear,
                    });
                    _showSuccessSnackBar('Member "$name" updated successfully!');
                  } else {
                    await widget.appState.addClubMember(
                      _selectedClub!.id,
                      name: name,
                      email: email,
                      role: roleController.text.trim(),
                      boardType: boardType,
                      academicYear: academicYear,
                      joinedAt: DateTime.now(),
                    );
                    _showSuccessSnackBar('Member "$name" added successfully!');
                  }
                  if (mounted) {
                    Navigator.of(ctx).pop();
                    _reloadSectionData();
                  }
                } catch (e) {
                  _showErrorSnackBar('Failed to save member: $e');
                }
              },
              child: Text(isEditing ? 'Save Changes' : 'Add Member'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMonitoredClubDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Add Club to Monitor',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => Navigator.of(ctx).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.appState.clubs.length,
            itemBuilder: (context, index) {
              final club = widget.appState.clubs[index];
              return ListTile(
                title: Text(club.name),
                trailing: const Icon(Icons.add),
                onTap: () async {
                  try {
                    await widget.appState.addTeacherClub(club.id);
                    _showSuccessSnackBar('Club "${club.name}" added to monitored list successfully!');
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    _initializeDashboard(); // Reload monitored clubs list
                  } catch (e) {
                    _showErrorSnackBar('Failed to add club: $e');
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMarkdownToolbar(TextEditingController controller, StateSetter setStateDialog) {
    void insertText(String template) {
      final text = controller.text;
      final selection = controller.selection;

      int start = selection.start;
      int end = selection.end;

      if (start < 0 || end < 0) {
        start = text.length;
        end = text.length;
      }

      final selectedText = text.substring(start, end);
      final newText = text.replaceRange(start, end, template.replaceAll('text', selectedText));

      setStateDialog(() {
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: start + template.indexOf('text') + selectedText.length),
        );
      });
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildToolbarBtn('B', () => insertText('**text**')),
          const SizedBox(width: 6),
          _buildToolbarBtn('I', () => insertText('_text_')),
          const SizedBox(width: 6),
          _buildToolbarBtn('H1', () => insertText('# text')),
          const SizedBox(width: 6),
          _buildToolbarBtn('List', () => insertText('- text')),
        ],
      ),
    );
  }

  Widget _buildToolbarBtn(String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.navy),
        ),
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

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
