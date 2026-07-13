import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
import '../widgets/member_form_sheet.dart';
import '../widgets/create_notification_sheet.dart';
import '../widgets/assign_teacher_sheet.dart';
import '../widgets/create_club_sheet.dart';
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
    } else if (activeRole != 'admin' && activeRole != 'teacher' && activeRole != 'user' && activeRole != 'club-member') {
      // Any non-admin, non-teacher role with a club context is an officer
      _selectedClub = _resolveManagedClub(session);
    } else if (session.isAnyClubOfficer && activeRole != 'admin' && activeRole != 'teacher') {
      // Fallback: user has officer memberships but role didn't match above
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
    // Use membership-based check: if a club is selected, check officer status for that club;
    // otherwise fall back to checking if they're an officer of any club.
    final isOfficer = !isAdmin && !isTeacher && (
        (_selectedClub != null && session.isClubOfficerOf(_selectedClub!.id, club: _selectedClub)) ||
        (widget.initialClub != null && session.isClubOfficerOf(widget.initialClub!.id, club: widget.initialClub)) ||
        session.isAnyClubOfficer
    );

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
            if (sec == 'Overview') {
              icon = Icons.trending_up_rounded;
            } else if (sec == 'Members') {
              icon = Icons.people_outline_rounded;
            } else if (sec == 'Drafts & Posts' || sec == 'Posts & Announcements') {
              icon = Icons.edit_note_rounded;
            } else if (sec == 'Events') {
              icon = Icons.calendar_month_outlined;
            } else if (sec == 'Tasks') {
              icon = Icons.checklist_rtl_rounded;
            } else if (sec == 'Messages' || sec == 'Live Chat') {
              icon = Icons.chat_bubble_outline_rounded;
            } else if (sec == 'Notifications') {
              icon = Icons.notifications_none_rounded;
            } else if (sec == 'Budget' || sec == 'Budgets') {
              icon = Icons.account_balance_wallet_outlined;
            } else if (sec == 'Reports') {
              icon = Icons.file_copy_outlined;
            } else if (sec == 'Team') {
              icon = Icons.groups_3_outlined;
            }

            final isSelected = _selectedSection == sec;
            final itemColor = isSelected ? AppTheme.textColor(ctx) : AppTheme.mutedColor(ctx);

            return ListTile(
              leading: Icon(icon, color: itemColor),
              title: Text(
                sec,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: itemColor,
                ),
              ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello,',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.mutedColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 26,
                    color: AppTheme.navyColor(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
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
                      border: Border.all(color: Theme.of(context).cardColor, width: 1.5),
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
          Text(
            'Dashboard Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.navyColor(context),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.015),
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
              color: isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
            ),
            child: Icon(
              icon,
              color: isDark ? Colors.white : const Color(0xFF475569),
              size: 20,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.navyColor(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.mutedColor(context),
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
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyColor(context),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1,
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
                    color: isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
                  ),
                  child: Icon(
                    icon,
                    color: isDark ? Colors.white : const Color(0xFF475569),
                    size: 22,
                  ),
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

  Widget _buildNewSubSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppTheme.navyColor(context)),
            onPressed: () => setState(() => _selectedSection = 'Overview'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedSection,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.navyColor(context),
              ),
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
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
          Text(
            'Administrative Control Center',
            style: TextStyle(
              color: AppTheme.navyColor(context),
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
            style: TextStyle(
              color: AppTheme.accent(context),
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
            iconColor: AppTheme.accent(context),
            iconBgColor: AppTheme.accent(context),
            value: '$clubsCount',
            label: 'TOTAL CLUBS',
          ),
          _buildStatCard(
            icon: Icons.calendar_month_outlined,
            iconColor: AppTheme.accent(context),
            iconBgColor: AppTheme.accent(context),
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? iconColor.withValues(alpha: 0.15)
                  : iconBgColor,
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
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.textColor(context)
                      : AppTheme.navyColor(context),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
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
            Container(
              width: 4,
              height: 90,
              color: isDark ? Colors.white : AppTheme.navy,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_today_outlined,
                        color: isDark ? Colors.white : const Color(0xFF475569),
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
                                  color: isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
                                ),
                                child: Text(
                                  'EVENT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.access_time, size: 11, color: AppTheme.mutedColor(context)),
                              const SizedBox(width: 4),
                              Text(
                                post.date != null
                                    ? '${post.date!.year}-${post.date!.month.toString().padLeft(2, '0')}-${post.date!.day.toString().padLeft(2, '0')}'
                                    : '',
                                style: TextStyle(fontSize: 10, color: AppTheme.mutedColor(context)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            post.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.navyColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Posted by ${post.clubName}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.mutedColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppTheme.mutedColor(context)),
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
                  Container(width: 4, height: 18, color: AppTheme.accent(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recent Campus Activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyColor(context),
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
                  color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Theme.of(context).brightness == Brightness.dark ? Border.all(color: AppTheme.darkBorder) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'VIEW ALL ACTIVITY',
                      style: TextStyle(
                        color: AppTheme.textColor(context),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.north_east_rounded, size: 12, color: AppTheme.textColor(context)),
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
                  fillColor: Theme.of(context).cardColor,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _showCreateClubDialog,
            icon: const Icon(Icons.add),
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
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
                  color: AppTheme.surfaceBg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkBorder : Theme.of(context).dividerColor),
                ),
                padding: const EdgeInsets.all(4),
                child: club.imageAsset.isNotEmpty
                    ? (club.imageAsset.startsWith('http')
                        ? Image.network(
                            club.imageAsset,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.groups_rounded, size: 36, color: Colors.grey),
                          )
                        : Image.asset(
                            club.imageAsset.startsWith('/')
                                ? 'assets/images${club.imageAsset}'
                                : club.imageAsset,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.groups_rounded, size: 36, color: Colors.grey),
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyColor(context),
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
              color: AppTheme.mutedColor(context),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBg(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white70 : const Color(0xFF475569);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white70 : const Color(0xFF475569);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
      ),
      child: Text(
        dept.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textColor(context)),
                ),
                Expanded(
                  child: Text(
                    display,
                    style: TextStyle(color: AppTheme.textColor(context), fontSize: 13, fontWeight: FontWeight.w500),
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
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textColor(context)),
          ),
          GestureDetector(
            onTap: () => _showAssignLeadershipDialog(club, roleLabel, roleKey),
            child: Row(
              children: [
                Icon(Icons.add, size: 14, color: AppTheme.accent(context)),
                const SizedBox(width: 4),
                Text(
                  'Assign',
                  style: TextStyle(color: AppTheme.accent(context), fontWeight: FontWeight.bold, fontSize: 13),
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
        Text(
          'All Posts & Announcements',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.navyColor(context),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
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
            Container(
              width: 4,
              height: 85,
              color: isEvent
                  ? (isDark ? Colors.white : AppTheme.navy)
                  : AppTheme.mutedColor(context),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEvent ? Icons.calendar_today_outlined : Icons.campaign_outlined,
                        color: isDark ? Colors.white : const Color(0xFF475569),
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
                                  color: isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
                                ),
                                child: Text(
                                  isEvent ? 'EVENT' : 'ANNOUNCEMENT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (post.date != null) ...[
                                Icon(Icons.access_time, size: 11, color: AppTheme.mutedColor(context)),
                                const SizedBox(width: 4),
                                Text(
                                  '${post.date!.year}-${post.date!.month.toString().padLeft(2, '0')}-${post.date!.day.toString().padLeft(2, '0')}',
                                  style: TextStyle(fontSize: 10, color: AppTheme.mutedColor(context)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            post.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.navyColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Posted by ${post.clubName}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.mutedColor(context),
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
            Expanded(
              child: Text(
                'System Broadcasts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyColor(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _showNotificationDialog,
              icon: const Icon(Icons.send_rounded, size: 16),
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
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
            Container(width: 4, height: 95, color: AppTheme.accent(context)),
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
                                  color: AppTheme.accent(context),
                                ),
                              ),
                              if (n.timeAgo.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '•  ${n.timeAgo}',
                                  style: TextStyle(fontSize: 10, color: AppTheme.mutedColor(context)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            n.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.navyColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            n.plainMessage,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.mutedColor(context),
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
                  Container(
                    width: 4,
                    height: 18,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.navy,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Teacher Management',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyColor(context),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _showAssignTeacherDialog,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
              label: const Text('Add Teacher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Theme.of(context).brightness == Brightness.dark
                ? Border.all(color: AppTheme.darkBorder)
                : Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            'Note: Teachers can monitor event reports from clubs they manage. When you add a teacher by email, they will receive an invitation to create their account.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF475569),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
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
              child: Icon(Icons.delete_outline_rounded, color: Theme.of(context).dividerColor, size: 22),
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
                    backgroundColor: isDark ? AppTheme.darkElevated : Colors.white,
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: isDark ? Colors.white : Theme.of(context).dividerColor,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navyColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mutedColor(context),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
                  ),
                  child: Text(
                    '$managedCount CLUBS MANAGED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final data = snapshot.data;
        final members = data != null ? data[0] as List<dynamic> : [];
        final tasks = data != null ? data[1] as List<dynamic> : [];
        final activeRole = widget.initialRole ?? session.role;
        final canEdit = activeRole == 'admin' || (_selectedClub != null && session.isClubOfficerOf(_selectedClub!.id, club: _selectedClub));
        final isOfficer = _selectedClub != null && session.isClubOfficerOf(_selectedClub!.id, club: _selectedClub);

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
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderColor(context), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.015),
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
                      color: isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: _selectedClub!.imageAsset.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _selectedClub!.imageAsset.startsWith('http')
                                ? Image.network(
                                    _selectedClub!.imageAsset,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Icon(Icons.groups_rounded, color: isDark ? Colors.white : AppTheme.accent(context)),
                                  )
                                : Image.asset(
                                    _selectedClub!.imageAsset.startsWith('/')
                                        ? 'assets/images${_selectedClub!.imageAsset}'
                                        : _selectedClub!.imageAsset,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Icon(Icons.groups_rounded, color: isDark ? Colors.white : AppTheme.accent(context)),
                                  ),
                          )
                        : Icon(Icons.groups_rounded, color: isDark ? Colors.white : AppTheme.accent(context), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedClub!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navyColor(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedClub!.fullForm.isNotEmpty
                              ? _selectedClub!.fullForm
                              : _selectedClub!.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.mutedColor(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF7C3AED).withValues(alpha: 0.15)
                                : const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFDDD6FE).withValues(alpha: 0.3)
                                    : const Color(0xFFDDD6FE),
                                width: 1),
                          ),
                          child: Text(
                            (widget.initialRole ?? session.role).toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFFA78BFA)
                                  : const Color(0xFF7C3AED),
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
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.navyColor(context),
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
                Text(
                  'Upcoming Event',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navyColor(context),
                  ),
                ),
                if (upcomingClubEvents.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selectedSection = 'Events'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.blue)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (nextUpcoming == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
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
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
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
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.blue,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${nextUpcoming.date?.day ?? ""}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.navyColor(context),
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
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.navyColor(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nextUpcoming.time ?? 'TBD',
                              style: TextStyle(fontSize: 11, color: AppTheme.mutedColor(context)),
                            ),
                            Text(
                              nextUpcoming.location ?? 'Campus',
                              style: TextStyle(fontSize: 11, color: AppTheme.mutedColor(context)),
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
            Text(
              'Social & Configurations',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.navyColor(context)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final clubPosts = widget.appState.posts.where((p) => p.clubId == _selectedClub!.id).toList();
    final clubEvents = clubPosts.where((p) => p.isEvent).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Advisor Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
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
                  color: isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
                ),
                padding: const EdgeInsets.all(6),
                child: _selectedClub!.imageAsset.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _selectedClub!.imageAsset.startsWith('http')
                            ? Image.network(
                                _selectedClub!.imageAsset,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(Icons.groups_rounded, color: isDark ? Colors.white : AppTheme.blue),
                              )
                            : Image.asset(
                                _selectedClub!.imageAsset.startsWith('/')
                                    ? 'assets/images${_selectedClub!.imageAsset}'
                                    : _selectedClub!.imageAsset,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(Icons.groups_rounded, color: isDark ? Colors.white : AppTheme.blue),
                              ),
                      )
                    : Icon(Icons.groups_rounded, color: isDark ? Colors.white : AppTheme.blue, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Advisor Dashboard',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage event posts, budgets, and team members for ${_selectedClub!.name}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.mutedColor(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? AppTheme.accent(context).withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppTheme.accent(context).withValues(alpha: 0.3) : const Color(0xFFBFDBFE), width: 1),
                      ),
                      child: Text(
                        'ADVISOR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.blue,
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
                        color: isActive ? Theme.of(context).cardColor : AppTheme.navyColor(context).withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(tab),
                    ],
                  ),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isActive ? Theme.of(context).cardColor : AppTheme.navyColor(context),
                  ),
                  selected: isActive,
                  selectedColor: AppTheme.blue,
                  backgroundColor: Theme.of(context).dividerColor,
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
              leading: Icon(Icons.file_copy_rounded, color: AppTheme.blue),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Teacher Dashboard',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyColor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Monitor club event reports and activities',
                      style: TextStyle(fontSize: 12, color: AppTheme.mutedColor(context)),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _showAddMonitoredClubDialog,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.blue,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: club.imageAsset.isNotEmpty
                                    ? (club.imageAsset.startsWith('http')
                                        ? Image.network(
                                            club.imageAsset,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => Icon(Icons.groups_rounded, color: isDark ? Colors.white : AppTheme.blue, size: 16),
                                          )
                                        : Image.asset(
                                            club.imageAsset.startsWith('/')
                                                ? 'assets/images${club.imageAsset}'
                                                : club.imageAsset,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => Icon(Icons.groups_rounded, color: isDark ? Colors.white : AppTheme.blue, size: 16),
                                          ))
                                    : Icon(Icons.groups_rounded, color: isDark ? Colors.white : AppTheme.blue, size: 16),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    club.name,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navyColor(context)),
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
                                    backgroundColor: AppTheme.surfaceBg(context),
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
                                  color: Theme.of(context).brightness == Brightness.dark ? AppTheme.accent(context).withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(Icons.download_rounded, size: 14, color: AppTheme.blue),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clubReportCount = _allReports.where((r) => r['clubId'] == _selectedClub!.id).length;

    // If a tab is selected (not on overview), show that tab content directly
    if (_teacherActiveTab != 'Overview') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _teacherActiveTab = 'Overview'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: AppTheme.blue),
                const SizedBox(width: 4),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: AppTheme.blue),
              const SizedBox(width: 4),
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
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
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
                  color: isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
                ),
                padding: const EdgeInsets.all(6),
                child: _selectedClub!.imageAsset.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _selectedClub!.imageAsset.startsWith('http')
                            ? Image.network(
                                _selectedClub!.imageAsset,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(Icons.groups_rounded, color: isDark ? Colors.white : AppTheme.blue),
                              )
                            : Image.asset(
                                _selectedClub!.imageAsset.startsWith('/')
                                    ? 'assets/images${_selectedClub!.imageAsset}'
                                    : _selectedClub!.imageAsset,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(Icons.groups_rounded, color: isDark ? Colors.white : AppTheme.blue),
                              ),
                      )
                    : Icon(Icons.groups_rounded, color: isDark ? Colors.white : AppTheme.blue, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedClub!.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedClub!.fullForm.isNotEmpty
                          ? _selectedClub!.fullForm
                          : 'Monitor club reports and activities',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.mutedColor(context),
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
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.navyColor(context),
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
                Text(
                  'Event Reports',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navyColor(context)),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _teacherReportYearFilter,
                          style: TextStyle(fontSize: 12, color: AppTheme.navyColor(context), fontWeight: FontWeight.bold),
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
                        backgroundColor: AppTheme.surfaceBg(context),
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
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
                ),
                child: Column(
                  children: [
                    Icon(Icons.file_copy_outlined, size: 44, color: Theme.of(context).dividerColor),
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
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
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
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navyColor(context)),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navyColor(context)),
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
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _teacherYearFilter,
                        isExpanded: true,
                        style: TextStyle(fontSize: 12, color: AppTheme.navyColor(context), fontWeight: FontWeight.bold),
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
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _teacherBoardFilter,
                        isExpanded: true,
                        style: TextStyle(fontSize: 12, color: AppTheme.navyColor(context), fontWeight: FontWeight.bold),
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
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
                ),
                child: Column(
                  children: [
                    Icon(Icons.groups_outlined, size: 44, color: Theme.of(context).dividerColor),
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
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navyColor(context)),
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
        Text(
          'Club Events',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navyColor(context)),
        ),
        const SizedBox(height: 12),
        if (clubEvents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
            ),
            child: Column(
              children: [
                Icon(Icons.event_busy_rounded, size: 48, color: Theme.of(context).dividerColor),
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
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navyColor(context)),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.calendar_month_rounded, size: 14, color: Theme.of(context).dividerColor),
                              const SizedBox(width: 4),
                              Text(
                                event.date != null ? event.date!.toLocal().toString().split(' ')[0] : 'N/A',
                                style: TextStyle(fontSize: 12, color: AppTheme.mutedColor(context)),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.people_alt_rounded, size: 14, color: Theme.of(context).dividerColor),
                              const SizedBox(width: 4),
                              Text(
                                '${event.rsvps ?? 0} RSVPs',
                                style: TextStyle(fontSize: 12, color: AppTheme.mutedColor(context)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.visibility_outlined, color: AppTheme.blue),
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
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
            ),
            child: Column(
              children: [
                Icon(Icons.file_copy_outlined, size: 48, color: Theme.of(context).dividerColor),
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
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
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
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navyColor(context)),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.copy_all_rounded, color: AppTheme.blue),
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
                            Text('Submitted By: ', style: TextStyle(fontSize: 12, color: AppTheme.mutedColor(context))),
                            Text(
                              report['reportSubmittedByName']?.toString() ?? 'Unknown',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.navyColor(context)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('Event Date: ', style: TextStyle(fontSize: 12, color: AppTheme.mutedColor(context))),
                            Text(
                              eventDate != null ? eventDate.toLocal().toString().split(' ')[0] : 'N/A',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.navyColor(context)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('Submitted: ', style: TextStyle(fontSize: 12, color: AppTheme.mutedColor(context))),
                            Text(
                              submittedAt != null ? submittedAt.toLocal().toString().split(' ')[0] : 'N/A',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.navyColor(context)),
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
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 48, color: Theme.of(context).dividerColor),
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
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navyColor(context)),
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
        Text(
          'Club Officers',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navyColor(context)),
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? AppTheme.accent(context).withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_rounded, color: AppTheme.blue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navyColor(context)),
                ),
                const SizedBox(height: 2),
                Text(
                  isAssigned ? email : 'Not Assigned',
                  style: TextStyle(fontSize: 12, color: isAssigned ? AppTheme.mutedColor(context) : Colors.red.shade400),
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
              icon: Icon(Icons.person_add_alt_1_rounded, color: AppTheme.blue),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
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
                    color: isDark ? AppTheme.darkElevated : AppTheme.surfaceBg(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : Theme.of(context).dividerColor),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: _isUploadingLogo
                      ? const Center(child: CircularProgressIndicator())
                      : _selectedClub!.imageAsset.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _selectedClub!.imageAsset.startsWith('http')
                                  ? Image.network(
                                      _selectedClub!.imageAsset,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(Icons.groups_rounded, color: isDark ? Colors.white : AppTheme.accent(context), size: 36),
                                    )
                                  : Image.asset(
                                      _selectedClub!.imageAsset.startsWith('/')
                                          ? 'assets/images${_selectedClub!.imageAsset}'
                                          : _selectedClub!.imageAsset,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(Icons.groups_rounded, color: isDark ? Colors.white : AppTheme.accent(context), size: 36),
                                    ),
                            )
                          : Icon(Icons.groups_rounded, size: 48, color: isDark ? Colors.white : Colors.grey),
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
                        backgroundColor: AppTheme.blue,
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
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
                style: TextStyle(color: AppTheme.blue, decoration: TextDecoration.underline),
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
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
                style: TextStyle(color: AppTheme.blue, decoration: TextDecoration.underline),
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
    final canEdit = activeRole == 'admin' || (_selectedClub != null && session.isClubOfficerOf(_selectedClub!.id, club: _selectedClub));
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
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeRole = widget.initialRole ?? session.role;
    final canEdit = activeRole == 'admin' || (_selectedClub != null && session.isClubOfficerOf(_selectedClub!.id, club: _selectedClub));
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
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: isDark ? AppTheme.darkElevated : const Color(0xFFEFF6FF),
                    child: Icon(
                      post.isEvent ? Icons.event : Icons.campaign_outlined,
                      color: isDark ? Colors.white : AppTheme.blue,
                    ),
                  ),
                  title: Text(post.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(_stripMarkdown(post.content), maxLines: 2, overflow: TextOverflow.ellipsis),
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
    final canEdit = activeRole == 'admin' || (_selectedClub != null && session.isClubOfficerOf(_selectedClub!.id, club: _selectedClub));
    final clubEvents = widget.appState.posts.where((p) => p.clubId == _selectedClub!.id && p.isEvent).toList();
    final now = DateTime.now();
    final upcoming = clubEvents.where((e) => e.date != null && e.date!.isAfter(now)).toList();
    final past = clubEvents.where((e) => e.date != null && !e.date!.isBefore(now)).toList();

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
          TabBar(
            tabs: const [
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
    final canEdit = activeRole == 'admin' || (_selectedClub != null && session.isClubOfficerOf(_selectedClub!.id, club: _selectedClub));
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
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor),
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
                color: AppTheme.surfaceBg(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
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
                                  "${msg['senderName'] ?? 'Officer'}${msg['senderRole'] != null && msg['senderRole'].toString().isNotEmpty ? ' (${msg['senderRole']})' : ''}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    color: isMe ? Colors.white70 : AppTheme.blue,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  msg['body']?.toString() ?? '',
                                  style: TextStyle(color: isMe ? Theme.of(context).cardColor : Colors.black87),
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
    final canEdit = activeRole == 'admin' || (_selectedClub != null && session.isClubOfficerOf(_selectedClub!.id, club: _selectedClub));
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
                  color: n.isRead ? Theme.of(context).cardColor : AppTheme.blue.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: ListTile(
                  title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    n.plainMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                              color: (verified ? Colors.green : AppTheme.blue).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(verified ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded, size: 14, color: verified ? Colors.green : AppTheme.blue),
                                const SizedBox(width: 4),
                                Text(verified ? 'Verified' : 'Awaiting', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: verified ? Colors.green : AppTheme.blue)),
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
                            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
    final type = widget.appState.session?.role == 'admin' ? 'system' : 'club';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateNotificationSheet(
        appState: widget.appState,
        initialType: type,
        clubId: _selectedClub?.id,
        onSuccess: (String message) {
          _showSuccessSnackBar(message);
          _reloadSectionData();
        },
      ),
    );
  }

  Future<void> _showCreatePostDialog(Club club, {required bool isEvent}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePostSheet(
        appState: widget.appState,
        club: club,
        isEvent: isEvent,
        onSuccess: (String message) {
          _showSuccessSnackBar(message);
          _reloadSectionData();
        },
      ),
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

    Future<void> pickDate(TextEditingController controller) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        controller.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      }
    }

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
                      readOnly: true,
                      onTap: () => pickDate(deadlineController),
                      decoration: const InputDecoration(labelText: 'Deadline', hintText: 'YYYY-MM-DD'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: '',
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(value: '', child: Text('No Related Event')),
                        ...posts.where((post) => post.isEvent).map(
                              (post) => DropdownMenuItem(value: post.id, child: Text(post.title, overflow: TextOverflow.ellipsis)),
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateClubSheet(
        appState: widget.appState,
        onSuccess: (String message) {
          _showSuccessSnackBar(message);
          _reloadSectionData();
        },
      ),
    );
  }

  Future<void> _showAssignTeacherDialog() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssignTeacherSheet(
        appState: widget.appState,
        onSuccess: (String message) {
          _showSuccessSnackBar(message);
          setState(() {
            _teachersFuture = widget.appState.fetchTeachers();
          });
        },
      ),
    );
  }

  void _showAddMemberDialog({Map<String, dynamic>? member}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MemberFormSheet(
        appState: widget.appState,
        clubId: _selectedClub!.id,
        member: member,
        onSuccess: (String message) {
          _showSuccessSnackBar(message);
          _reloadSectionData();
        },
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Create Post / Event Bottom Sheet Wizard
// ─────────────────────────────────────────────────────────────────────────────

class _CreatePostSheet extends StatefulWidget {
  const _CreatePostSheet({
    required this.appState,
    required this.club,
    required this.isEvent,
    required this.onSuccess,
  });

  final AppState appState;
  final Club club;
  final bool isEvent;
  final void Function(String message) onSuccess;

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  // ── Navigation
  int _step = 0;
  final PageController _pageController = PageController();

  // ── Step 1: Content
  String? coverImageUrl;
  bool isUploadingCover = false;
  List<String> descriptionImageUrls = [];
  bool isUploadingDesc = false;
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  String? _titleError;

  // ── Step 2: Details
  DateTime? eventDate;
  String timeFromHour = '9';
  String timeFromMin = '00';
  String timeFromPeriod = 'AM';
  String timeToHour = '5';
  String timeToMin = '00';
  String timeToPeriod = 'PM';
  int totalSessions = 1;
  String locationType = 'campus';
  final locationController = TextEditingController();
  final locationUrlController = TextEditingController();
  String relatedEventId = '';

  // ── Step 3 (Event): Registration
  DateTime? regOpenDateTime;
  DateTime? regCloseDateTime;
  final regLinkController = TextEditingController();
  final sheetUrlController = TextEditingController();
  final whatsappController = TextEditingController();

  bool _isSubmitting = false;

  int get _totalSteps => widget.isEvent ? 3 : 2;

  @override
  void dispose() {
    _pageController.dispose();
    titleController.dispose();
    contentController.dispose();
    locationController.dispose();
    locationUrlController.dispose();
    regLinkController.dispose();
    sheetUrlController.dispose();
    whatsappController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.day} ${_monthName(d.month)} ${d.year}';

  String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  String _dateToApi(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _timeStr(String h, String m, String p) => '$h:$m $p';

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final min = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  String _formatDateTime(DateTime dt) =>
      "${dt.day} ${_monthName(dt.month)} ${dt.year}, ${_formatTimeOfDay(TimeOfDay.fromDateTime(dt))}";

  Future<void> _pickDate(void Function(DateTime) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _pickDateTime(DateTime? initial, void Function(DateTime) onPicked) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: initial != null ? TimeOfDay.fromDateTime(initial) : TimeOfDay.now(),
    );
    if (time == null) return;
    onPicked(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }


  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => isUploadingCover = true);
    final url = await CloudinaryService.uploadImage(File(picked.path));
    if (mounted) setState(() { coverImageUrl = url; isUploadingCover = false; });
  }

  Future<void> _pickDescImages() async {
    final remaining = 10 - descriptionImageUrls.length;
    if (remaining <= 0) return;
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(limit: remaining);
    if (picked.isEmpty) return;
    setState(() => isUploadingDesc = true);
    for (final f in picked) {
      final url = await CloudinaryService.uploadImage(File(f.path));
      if (url != null && mounted) setState(() => descriptionImageUrls.add(url));
    }
    if (mounted) setState(() => isUploadingDesc = false);
  }

  bool _validateStep1() {
    if (titleController.text.trim().isEmpty) {
      setState(() => _titleError = 'Title is required');
      // Scroll to title by doing nothing else — error text shows inline
      return false;
    }
    setState(() => _titleError = null);
    return true;
  }

  void _nextStep() {
    if (_step == 0 && !_validateStep1()) return;
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      _pageController.animateToPage(_step,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOutCubic);
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.animateToPage(_step,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOutCubic);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      String? relTitle;
      if (!widget.isEvent && relatedEventId.isNotEmpty) {
        relTitle = widget.appState.posts.where((p) => p.id == relatedEventId).firstOrNull?.title;
      }
      await widget.appState.createPost(
        clubId: widget.club.id,
        clubName: widget.club.name,
        title: titleController.text.trim(),
        content: contentController.text.trim(),
        type: widget.isEvent ? 'event' : 'announcement',
        status: 'published',
        coverImage: coverImageUrl,
        descriptionImages: descriptionImageUrls,
        date: eventDate != null ? _dateToApi(eventDate!) : null,
        timeFrom: _timeStr(timeFromHour, timeFromMin, timeFromPeriod),
        timeTo: _timeStr(timeToHour, timeToMin, timeToPeriod),
        location: locationController.text.trim().isNotEmpty ? locationController.text.trim() : null,
        locationType: locationType,
        locationUrl: locationUrlController.text.trim().isNotEmpty ? locationUrlController.text.trim() : null,
        totalSessions: widget.isEvent ? totalSessions : null,
        registrationStart: widget.isEvent && regOpenDateTime != null ? _dateToApi(regOpenDateTime!) : null,
        registrationStartTime: widget.isEvent && regOpenDateTime != null ? _formatTimeOfDay(TimeOfDay.fromDateTime(regOpenDateTime!)) : null,
        registrationEnd: widget.isEvent && regCloseDateTime != null ? _dateToApi(regCloseDateTime!) : null,
        registrationEndTime: widget.isEvent && regCloseDateTime != null ? _formatTimeOfDay(TimeOfDay.fromDateTime(regCloseDateTime!)) : null,
        registrationLink: widget.isEvent && regLinkController.text.trim().isNotEmpty ? regLinkController.text.trim() : null,
        responseSpreadsheetUrl: widget.isEvent && sheetUrlController.text.trim().isNotEmpty ? sheetUrlController.text.trim() : null,
        eventWhatsappLink: widget.isEvent && whatsappController.text.trim().isNotEmpty ? whatsappController.text.trim() : null,
        relatedEventId: !widget.isEvent && relatedEventId.isNotEmpty ? relatedEventId : null,
        relatedEventTitle: relTitle,
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess(widget.isEvent ? 'Event created successfully!' : 'Announcement created successfully!');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.92,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : const Color(0xFFF6F8FB),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStepContent(isDark),
                _buildStepDetails(isDark),
                if (widget.isEvent) _buildStepRegistration(isDark),
              ],
            ),
          ),
          _buildStickyFooter(isDark, mq),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final labels = widget.isEvent ? ['Content', 'Details', 'Registration'] : ['Content', 'Details'];
    final titleColor = AppTheme.textColor(context);
    final subtitleColor = isDark ? AppTheme.darkMuted : AppTheme.mutedColor(context);
    final headerBg = isDark ? AppTheme.darkSurface : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.blueGrey.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isEvent ? 'Create Event' : 'New Post',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Step ${_step + 1} of $_totalSteps  \u00b7  ${labels[_step]}',
                        style: TextStyle(color: subtitleColor, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : AppTheme.text),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.05),
                    padding: const EdgeInsets.all(6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: (_step + 1) / _totalSteps),
              duration: const Duration(milliseconds: 300),
              builder: (_, v, __) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: v, minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.cyan),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  // ── Step 1: Content ───────────────────────────────────────────────────────

  Widget _buildStepContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCoverHero(isDark),
          const SizedBox(height: 20),
          _buildDescImagesSection(isDark),
          const SizedBox(height: 20),
          _fieldLabel('Title', required: true),
          const SizedBox(height: 8),
          TextField(
            controller: titleController,
            onChanged: (_) { if (_titleError != null) setState(() => _titleError = null); },
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: widget.isEvent ? 'e.g., TechSprint Hackathon 2026' : 'e.g., Upcoming Workshop Details',
              errorText: _titleError,
            ),
          ),
          const SizedBox(height: 20),
          _fieldLabel('Description', required: true),
          const SizedBox(height: 8),
          // Description + docked toolbar wrapped together
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.blueGrey.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                TextField(
                  controller: contentController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Write something engaging...',
                    alignLabelWithHint: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  ),
                ),
                _mdToolbar(isDark),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCoverHero(bool isDark) {
    return GestureDetector(
      onTap: isUploadingCover ? null : _pickCoverImage,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: coverImageUrl != null
            ? Stack(key: const ValueKey('filled'), children: [
                ClipRRect(borderRadius: BorderRadius.circular(16),
                    child: Image.network(coverImageUrl!, height: 200, width: double.infinity, fit: BoxFit.cover)),
                ClipRRect(borderRadius: BorderRadius.circular(16),
                    child: Container(height: 200, decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)], stops: const [0.55, 1.0])))),
                Positioned(bottom: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.edit_rounded, color: Colors.white, size: 13),
                        SizedBox(width: 4),
                        Text('Change', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    )),
              ])
            : Container(
                key: const ValueKey('empty'),
                height: 200, width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.blueGrey.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: isUploadingCover
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const CircularProgressIndicator(strokeWidth: 2),
                        const SizedBox(height: 10),
                        Text('Uploading...', style: TextStyle(color: AppTheme.mutedColor(context), fontSize: 13)),
                      ]))
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkElevated : const Color(0xFFE2E8F0),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppTheme.textColor(context),
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('Tap to add Cover Photo / Video',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textColor(context))),
                        const SizedBox(height: 4),
                        Text('Required \u00b7 Max 1', style: TextStyle(fontSize: 12, color: AppTheme.mutedColor(context))),
                      ]),
              ),
      ),
    );
  }

  Widget _buildDescImagesSection(bool isDark) {
    final canAdd = descriptionImageUrls.length < 10;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _fieldLabel('Description Media', required: false),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: AppTheme.mutedColor(context).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text('${descriptionImageUrls.length}/10', style: TextStyle(fontSize: 11, color: AppTheme.mutedColor(context), fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ...descriptionImageUrls.asMap().entries.map((e) => Container(
                margin: const EdgeInsets.only(right: 8),
                width: 80, height: 80,
                child: Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12),
                      child: Image.network(e.value, width: 80, height: 80, fit: BoxFit.cover)),
                  Positioned(top: 4, right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => descriptionImageUrls.removeAt(e.key)),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 12),
                        ),
                      )),
                ]),
              )),
              if (canAdd)
                GestureDetector(
                  onTap: isUploadingDesc ? null : _pickDescImages,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.blueGrey.withValues(alpha: 0.2), width: 1.5),
                    ),
                    child: isUploadingDesc
                        ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                        : Icon(Icons.add_rounded, color: AppTheme.mutedColor(context), size: 28),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 2: Details ───────────────────────────────────────────────────────

  Widget _buildStepDetails(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isEvent) ...[
            _buildRelatedEventPicker(isDark),
            const SizedBox(height: 20),
          ],
          _fieldLabel('Date', required: true),
          const SizedBox(height: 8),
          _dateTile(isDark: isDark, date: eventDate, hint: 'Select date', icon: Icons.calendar_today_rounded,
              onTap: () => _pickDate((d) => setState(() => eventDate = d))),
          const SizedBox(height: 20),
          _fieldLabel('Time', required: false),
          const SizedBox(height: 8),
          _timeFromTo(isDark),
          const SizedBox(height: 20),
          if (widget.isEvent) ...[
            _buildSessions(isDark),
            const SizedBox(height: 20),
          ],
          _fieldLabel('Location', required: false),
          const SizedBox(height: 8),
          _buildLocation(isDark),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRelatedEventPicker(bool isDark) {
    final events = widget.appState.posts.where((p) => p.isEvent).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _fieldLabel('Related to Event', required: false),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: AppTheme.mutedColor(context).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Text('Optional', style: TextStyle(fontSize: 10, color: AppTheme.mutedColor(context), fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.blueGrey.withValues(alpha: 0.12)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: relatedEventId.isEmpty ? '' : relatedEventId,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: '', child: Text('\u2014 Not linked to any event \u2014')),
                ...events.map((p) => DropdownMenuItem(
                  value: p.id,
                  child: Row(children: [
                    Icon(Icons.event_rounded, size: 16, color: AppTheme.blue),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p.title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
                  ]),
                )),
              ],
              onChanged: (v) => setState(() => relatedEventId = v ?? ''),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateTile({required bool isDark, required DateTime? date, required String hint, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.blueGrey.withValues(alpha: 0.12)),
        ),
        child: Row(children: [
          Icon(icon, color: AppTheme.blue, size: 20),
          const SizedBox(width: 12),
          Text(date != null ? _formatDate(date) : hint,
              style: TextStyle(fontSize: 15, fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
                  color: date != null ? null : AppTheme.mutedColor(context))),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, color: AppTheme.mutedColor(context), size: 18),
        ]),
      ),
    );
  }

  Widget _timeFromTo(bool isDark) {
    final hours = List.generate(12, (i) => '${i + 1}');
    final mins = ['00', '15', '30', '45'];
    final periods = ['AM', 'PM'];

    Widget pill(String v, List<String> items, void Function(String?) cb) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.blueGrey.withValues(alpha: 0.12)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: v, isDense: true,
          items: items.map((x) => DropdownMenuItem(value: x, child: Text(x, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
          onChanged: cb,
        ),
      ),
    );

    Widget row(String lbl, String h, String m, String p, void Function(String?) onH, void Function(String?) onM, void Function(String?) onP) => Row(
      children: [
        SizedBox(width: 40, child: Text(lbl, style: TextStyle(fontSize: 13, color: AppTheme.mutedColor(context), fontWeight: FontWeight.w600))),
        const SizedBox(width: 4),
        pill(h, hours, onH),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(':', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkText : AppTheme.text)),
        ),
        pill(m, mins, onM),
        const SizedBox(width: 8),
        pill(p, periods, onP),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.blueGrey.withValues(alpha: 0.12)),
      ),
      child: Column(children: [
        row('From', timeFromHour, timeFromMin, timeFromPeriod,
            (v) => setState(() => timeFromHour = v!),
            (v) => setState(() => timeFromMin = v!),
            (v) => setState(() => timeFromPeriod = v!)),
        Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.blueGrey.withValues(alpha: 0.1)),
        const SizedBox(height: 12),
        row('To', timeToHour, timeToMin, timeToPeriod,
            (v) => setState(() => timeToHour = v!),
            (v) => setState(() => timeToMin = v!),
            (v) => setState(() => timeToPeriod = v!)),
      ]),
    );
  }

  Widget _buildSessions(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _fieldLabel('Number of Sessions', required: false),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFECB3))),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFFE65100)),
          SizedBox(width: 8),
          Expanded(child: Text('Attendance is tracked per session. Certificates require presence in all sessions.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6D4C00), height: 1.4))),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.blueGrey.withValues(alpha: 0.12)),
        ),
        child: Row(children: [
          Icon(Icons.repeat_rounded, size: 18, color: AppTheme.blue),
          const SizedBox(width: 10),
          const Text('Sessions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const Spacer(),
          _ctr(Icons.remove_rounded, totalSessions > 1 ? () => setState(() => totalSessions--) : null),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('$totalSessions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.navyColor(context)))),
          _ctr(Icons.add_rounded, totalSessions < 20 ? () => setState(() => totalSessions++) : null),
        ]),
      ),
    ]);
  }

  Widget _ctr(IconData icon, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: onTap != null ? AppTheme.blue.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: onTap != null ? AppTheme.blue : AppTheme.mutedColor(context)),
    ),
  );

  Widget _buildLocation(bool isDark) {
    return Column(children: [
      Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.blueGrey.withValues(alpha: 0.12)),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(children: [
          _locChip('In Campus', Icons.school_rounded, locationType == 'campus', isDark, () => setState(() => locationType = 'campus')),
          const SizedBox(width: 4),
          _locChip('Outside Campus', Icons.location_on_rounded, locationType == 'external', isDark, () => setState(() => locationType = 'external')),
        ]),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: locationController,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.place_rounded, size: 20),
          hintText: locationType == 'campus' ? 'e.g., Seminar Hall 1, CSE Dept' : 'e.g., Venue Name, City',
        ),
      ),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: locationType == 'external'
            ? Padding(key: const ValueKey('ext'), padding: const EdgeInsets.only(top: 10),
                child: TextField(controller: locationUrlController,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.map_outlined, size: 20), hintText: 'Google Maps link (optional)')))
            : const SizedBox.shrink(key: ValueKey('no_ext')),
      ),
    ]);
  }

  Widget _locChip(String label, IconData icon, bool selected, bool isDark, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: selected ? AppTheme.blue : Colors.transparent, borderRadius: BorderRadius.circular(11)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: selected ? Theme.of(context).cardColor : AppTheme.mutedColor(context)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Theme.of(context).cardColor : AppTheme.mutedColor(context))),
        ]),
      ),
    ),
  );

  // ── Step 3: Registration ──────────────────────────────────────────────────

  Widget _buildStepRegistration(bool isDark) {
    try {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionCard(
              isDark: isDark, accentColor: AppTheme.purple,
              icon: Icons.calendar_month_rounded, title: 'Registration Window', subtitle: 'Optional',
              child: Column(children: [
                _fieldLabel('Opens', required: false),
                const SizedBox(height: 6),
                _dateTile(
                  isDark: isDark,
                  date: regOpenDateTime,
                  hint: 'Select start date & time',
                  icon: Icons.calendar_today_rounded,
                  onTap: () => _pickDateTime(regOpenDateTime, (dt) => setState(() => regOpenDateTime = dt)),
                ),
                const SizedBox(height: 14),
                _fieldLabel('Closes', required: false),
                const SizedBox(height: 6),
                _dateTile(
                  isDark: isDark,
                  date: regCloseDateTime,
                  hint: 'Select end date & time',
                  icon: Icons.calendar_today_rounded,
                  onTap: () => _pickDateTime(regCloseDateTime, (dt) => setState(() => regCloseDateTime = dt)),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              isDark: isDark, accentColor: AppTheme.blue,
              icon: Icons.link_rounded, title: 'Links', subtitle: 'Optional',
              child: Column(children: [
                _linkField(controller: regLinkController, icon: Icons.link_rounded, iconColor: AppTheme.blue,
                    hint: 'https://forms.google.com/...', label: 'Registration Link', isDark: isDark,
                    trailing: TextButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse('https://forms.google.com/create');
                        if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 13),
                      label: const Text('Create Google Form', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.blue, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                    )),
                const SizedBox(height: 14),
                _linkField(controller: sheetUrlController, icon: Icons.table_chart_outlined,
                    iconColor: const Color(0xFF0F9D58), hint: 'https://docs.google.com/spreadsheets/...',
                    label: 'Response Spreadsheet URL', isDark: isDark),
                const SizedBox(height: 14),
                _linkField(controller: whatsappController, icon: Icons.chat_bubble_outline_rounded,
                    iconColor: const Color(0xFF25D366), hint: 'https://chat.whatsapp.com/...',
                    label: 'WhatsApp Group Link', isDark: isDark),
              ]),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    } catch (e, stack) {
      debugPrint("Error building step 3: $e\n$stack");
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SelectableText('Error: $e', style: const TextStyle(color: Colors.red)),
        ),
      );
    }
  }

  Widget _sectionCard({required bool isDark, required Color accentColor, required IconData icon, required String title, required String subtitle, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.blueGrey.withValues(alpha: 0.12),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                // Clean visual vertical accent indicator
                Container(
                  width: 3.5,
                  height: 16,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, size: 16, color: accentColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: accentColor),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 16,
              color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.blueGrey.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }


  Widget _linkField({required TextEditingController controller, required IconData icon, required Color iconColor, required String hint, required String label, required bool isDark, Widget? trailing}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mutedColor(context))),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: TextInputType.url,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: iconColor),
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      if (trailing != null) ...[const SizedBox(height: 4), Align(alignment: Alignment.centerRight, child: trailing)],
    ]);
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildStickyFooter(bool isDark, MediaQueryData mq) {
    final isLast = _step == _totalSteps - 1;
    final footerBg = isDark ? AppTheme.darkSurface : Colors.white;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + mq.padding.bottom),
      decoration: BoxDecoration(
        color: footerBg,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.blueGrey.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(children: [
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: _prevStep,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.blueGrey.withValues(alpha: 0.2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (_step > 0) const Icon(Icons.arrow_back_rounded, size: 16),
              if (_step > 0) const SizedBox(width: 6),
              Text(_step == 0 ? 'Cancel' : 'Back', style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalSteps, (i) {
              final active = i == _step;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active ? AppTheme.blue : AppTheme.mutedColor(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),
        SizedBox(
          height: 48,
          child: isLast
              ? _publishBtn(isDark)
              : FilledButton(
                  onPressed: _nextStep,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Next', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ]),
                ),
        ),
      ]),
    );
  }

  Widget _publishBtn(bool isDark) => FilledButton(
        onPressed: _isSubmitting ? null : _submit,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: _isSubmitting
            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.black : Colors.white))
            : Text(
                widget.isEvent ? 'Publish Event' : 'Publish Post',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
      );



  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _fieldLabel(String label, {bool required = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textColor(context))),
    if (required) ...[const SizedBox(width: 4), const Text('*', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold))],
  ]);

  Widget _mdToolbar(bool isDark) {
    void ins(String tpl) {
      final text = contentController.text;
      final sel = contentController.selection;
      final start = sel.start < 0 ? text.length : sel.start;
      final end = sel.end < 0 ? text.length : sel.end;
      final selected = text.substring(start, end);
      final repl = tpl.replaceAll('text', selected.isEmpty ? 'text' : selected);
      setState(() {
        contentController.value = TextEditingValue(
          text: text.replaceRange(start, end, repl),
          selection: TextSelection.collapsed(offset: start + repl.length),
        );
      });
    }

    final items = [
      (Icons.format_bold,        '**text**', 'Bold'),
      (Icons.format_italic,      '_text_',   'Italic'),
      (Icons.format_size,        '# text',   'Heading'),
      (Icons.format_list_bulleted, '- text', 'List'),
      (Icons.link_rounded,       '[text](url)', 'Link'),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2A3A) : const Color(0xFFEEF2F8),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          left: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.blueGrey.withValues(alpha: 0.15)),
          right: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.blueGrey.withValues(alpha: 0.15)),
          bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.blueGrey.withValues(alpha: 0.15)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          ...items.asMap().entries.map((e) {
            final item = e.value;
            final isLast = e.key == items.length - 1;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: item.$3,
                  child: InkWell(
                    onTap: () => ins(item.$2),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 34,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        item.$1,
                        size: 18,
                        color: isDark ? Colors.white.withValues(alpha: 0.75) : AppTheme.navyColor(context).withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 1,
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.blueGrey.withValues(alpha: 0.2),
                  ),
              ],
            );
          }),
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? iconColor.withValues(alpha: 0.15)
                  : bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.textColor(context)
                  : AppTheme.navyColor(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppTheme.mutedColor(context),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
                  ),
                  child: Icon(icon, color: isDark ? Colors.white : const Color(0xFF475569), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navyColor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.mutedColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).dividerColor,
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

String _stripMarkdown(String markdown) {
  // 1. Link parsing: [text](url) -> text
  var text = markdown.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (match) => match[1] ?? '');
  // 2. Bold/Italic formatting: **text** or __text__ or *text* or _text_ -> text
  text = text.replaceAll(RegExp(r'\*\*|__|\*|_'), '');
  // 3. Headers: # Heading -> Heading
  text = text.replaceAll(RegExp(r'^#+\s+', multiLine: true), '');
  // 4. Bullet lists: - item -> item
  text = text.replaceAll(RegExp(r'^\s*-\s+', multiLine: true), '');
  return text.trim();
}

