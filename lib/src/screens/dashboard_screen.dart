import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';
import 'dart:io';

import '../models/club.dart';
import '../models/post_item.dart';
import '../models/notification_item.dart';
import '../models/user_session.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'club_detail_screen.dart';
import 'post_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedSection = 'Overview';
  bool _isMenuExpanded = false;
  Club? _selectedClub;
  List<Club> _monitoredClubs = [];
  bool _isLoadingMonitored = false;
  bool _isUploadingLogo = false;
  String _clubSearchQuery = '';

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
    _initializeDashboard();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _initializeDashboard() async {
    final session = widget.appState.session!;
    
    // Resolve managed club for officers
    if (session.role == 'president' ||
        session.role == 'club-secretary' ||
        session.role == 'treasurer' ||
        session.role == 'advisor') {
      _selectedClub = _resolveManagedClub(session);
    } else if (session.role == 'teacher') {
      setState(() => _isLoadingMonitored = true);
      try {
        final monitored = await widget.appState.fetchTeacherClubs();
        final List<Club> loaded = [];
        for (final m in monitored) {
          final id = m['_id']?.toString() ?? m['id']?.toString() ?? '';
          final match = widget.appState.clubs.where((c) => c.id == id).toList();
          if (match.isNotEmpty) loaded.add(match.first);
        }
        setState(() {
          _monitoredClubs = loaded;
          if (_monitoredClubs.isNotEmpty) {
            _selectedClub = _monitoredClubs.first;
          }
        });
      } catch (e) {
        print('Error loading teacher clubs: $e');
      } finally {
        setState(() => _isLoadingMonitored = false);
      }
    } else if (session.role == 'admin') {
      if (widget.appState.clubs.isNotEmpty) {
        _selectedClub = widget.appState.clubs.first;
      }
      _teachersFuture = widget.appState.fetchTeachers();
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

  IconData _iconForSection(String section) {
    switch (section) {
      case 'Overview':
        return Icons.trending_up_rounded;
      case 'Manage Clubs':
      case 'Members':
        return Icons.groups_rounded;
      case 'Manage Posts':
      case 'Posts & Announcements':
        return Icons.edit_note_rounded;
      case 'Events':
        return Icons.calendar_month_outlined;
      case 'Tasks':
        return Icons.playlist_add_check_rounded;
      case 'Live Chat':
        return Icons.chat_bubble_outline_rounded;
      case 'Notifications':
        return Icons.notifications_active_outlined;
      case 'Teachers':
        return Icons.person_outline_rounded;
      case 'Budgets':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  String _dropdownHeaderLabel(String section) {
    if (section == 'Manage Clubs') return 'Clubs';
    if (section == 'Manage Posts') return 'Posts';
    return section;
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.appState.session!;
    final isAdmin = session.role == 'admin';
    final isTeacher = session.role == 'teacher';
    final isOfficer = session.role == 'president' ||
        session.role == 'club-secretary' ||
        session.role == 'treasurer' ||
        session.role == 'advisor';

    final List<String> availableSections = isAdmin
        ? ['Overview', 'Manage Clubs', 'Manage Posts', 'Notifications', 'Teachers']
        : [
            'Overview',
            'Members',
            'Posts & Announcements',
            'Events',
            'Tasks',
            'Live Chat',
            'Notifications',
            if (session.role == 'advisor' || session.role == 'president' || session.role == 'treasurer')
              'Budgets',
          ];

    return Scaffold(
      appBar: isAdmin
          ? null
          : AppBar(
              title: Text(isOfficer ? 'Club Dashboard' : 'Campus Dashboard'),
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.navy,
              elevation: 0,
            ),
      body: _isLoadingMonitored
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Top Club Selector for Admin / Teacher
                  if (!isAdmin && isTeacher)
                    _buildClubSelectorHeader(_monitoredClubs, onAddMonitored: _showAddMonitoredClubDialog),

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
                            children: [
                              if (_selectedSection == 'Overview') ...[
                                _buildAdminHeaderCard(session),
                                _buildAdminStatsGrid(),
                              ],
                              _buildDropdownNavigation(availableSections, isAdmin),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                                child: _buildActiveSectionView(session),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else ...[
                    if (_selectedClub == null)
                      Expanded(
                        child: Center(
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
                      // Dropdown Navigation Selector
                      _buildDropdownNavigation(availableSections, isAdmin),

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
                            child: _buildActiveSectionView(session),
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

  Widget _buildClubSelectorHeader(List<Club> clubs, {VoidCallback? onAddMonitored}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.hub_outlined, color: AppTheme.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Club>(
                value: _selectedClub,
                hint: const Text('Select Club to Manage'),
                isExpanded: true,
                items: clubs.map((c) {
                  return DropdownMenuItem<Club>(
                    value: c,
                    child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  );
                }).toList(),
                onChanged: (club) {
                  setState(() {
                    _selectedClub = club;
                  });
                  _reloadSectionData();
                },
              ),
            ),
          ),
          if (onAddMonitored != null)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppTheme.blue, size: 20),
              onPressed: onAddMonitored,
            ),
        ],
      ),
    );
  }

  Widget _buildDropdownNavigation(List<String> availableSections, bool isAdmin) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isMenuExpanded = !_isMenuExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.menu_rounded, color: AppTheme.blue),
                  const SizedBox(width: 12),
                  Text(
                    isAdmin ? _dropdownHeaderLabel(_selectedSection) : _selectedSection,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.blue,
                        ),
                  ),
                  const Spacer(),
                  Icon(
                    _isMenuExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (_isMenuExpanded) ...[
            const Divider(height: 1),
            Column(
              children: availableSections.map((section) {
                final isSelected = _selectedSection == section;
                return Container(
                  color: isSelected ? Colors.blue.shade50.withValues(alpha: 0.5) : null,
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      _iconForSection(section),
                      color: isSelected ? AppTheme.blue : Colors.grey.shade600,
                      size: 20,
                    ),
                    title: Text(
                      section,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppTheme.blue : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedSection = section;
                        _isMenuExpanded = false;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveSectionView(UserSession session) {
    if (session.role != 'admin' && _selectedClub == null) return const SizedBox.shrink();

    switch (_selectedSection) {
      case 'Overview':
        return session.role == 'admin' ? _buildAdminOverviewSection() : _buildOverviewView(session);
      case 'Manage Clubs':
        return _buildManageClubsSection();
      case 'Manage Posts':
        return _buildManagePostsSection();
      case 'Notifications':
        return session.role == 'admin' ? _buildAdminNotificationsSection() : _buildNotificationsView(session);
      case 'Teachers':
        return session.role == 'admin' ? _buildAdminTeachersSection() : const SizedBox.shrink();
      case 'Members':
        return _buildMembersView(session);
      case 'Posts & Announcements':
        return _buildPostsView(session);
      case 'Events':
        return _buildEventsView(session);
      case 'Tasks':
        return _buildTasksView(session);
      case 'Live Chat':
        return _buildMessagesView(session);
      case 'Budgets':
        return _buildBudgetView(session);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── ADMIN DASHBOARD HELPER METHODS ────────────────────────────────────────

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
                await widget.appState.removeClubOfficer(club.id, roleKey);
                _reloadSectionData();
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
                if (email.isEmpty || name.isEmpty) return;

                await widget.appState.assignOfficer(
                  clubId: club.id,
                  email: email,
                  name: name,
                  role: roleKey,
                );
                navigator.pop();
                _reloadSectionData();
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
      final file = File(pickedFile.path);
      final imageUrl = await CloudinaryService.uploadImage(file);
      if (imageUrl != null) {
        await widget.appState.updateClub(club.id, {'image': imageUrl});
        await widget.appState.refreshAll();
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
                await widget.appState.updateClub(club.id, {
                  'name': nameController.text.trim(),
                  'fullForm': fullFormController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'category': category,
                });
                navigator.pop();
                await widget.appState.refreshAll();
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
      await widget.appState.deleteClub(club.id);
      await widget.appState.refreshAll();
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
                          await widget.appState.deletePost(post.id);
                          _reloadSectionData();
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
                          await widget.appState.deleteNotification(n.id);
                          _reloadSectionData();
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
                  await widget.appState.deleteTeacher(tId);
                  setState(() {
                    _teachersFuture = widget.appState.fetchTeachers();
                  });
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
    final clubPosts = widget.appState.posts.where((p) => p.clubId == _selectedClub!.id).toList();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _membersFuture,
      builder: (context, snapshot) {
        final members = snapshot.data ?? [];
        final canEdit = session.role == 'admin' || session.role == 'advisor' || session.role == 'president' || session.role == 'club-secretary';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Blue left strip overview card
            Container(
              margin: const EdgeInsets.only(bottom: 20),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    Container(width: 6, height: 120, color: Colors.blue.shade700),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Club Name', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                                Text(_selectedClub!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Members', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('${members.length}', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Posts', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                                Text('${clubPosts.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navy)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Profile Picture Card
            _buildProfilePictureCard(canEdit),

            // WhatsApp Card
            _buildWhatsAppCard(canEdit),

            // Instagram Card
            _buildInstagramCard(canEdit),

            if (session.role == 'admin') ...[
              const SizedBox(height: 24),
              const Text('Admin Global Operations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navy)),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.add_business_outlined)),
                      title: const Text('Create New Club', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Add a new club profile to Campus Connect'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showCreateClubDialog,
                    ),
                    const Divider(),
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_add_alt_1_rounded)),
                      title: const Text('Assign Teacher Role', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Assign teacher/monitor privileges'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showAssignTeacherDialog,
                    ),
                    const Divider(),
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.campaign_outlined)),
                      title: const Text('Broadcast System Notice', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Send notification to all campus users'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showNotificationDialog,
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
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
    final canEdit = session.role == 'admin' || session.role == 'advisor' || session.role == 'president' || session.role == 'club-secretary';
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
                                          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Remove')),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await widget.appState.removeClubMember(_selectedClub!.id, mId);
                                      _reloadSectionData();
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

  // ─── DRAFTS & POSTS TAB ────────────────────────────────────────────────────
  Widget _buildPostsView(UserSession session) {
    final canEdit = session.role == 'admin' || session.role == 'advisor' || session.role == 'president' || session.role == 'club-secretary';
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
                              await widget.appState.deletePost(post.id);
                              _reloadSectionData();
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
    final canEdit = session.role == 'admin' || session.role == 'advisor' || session.role == 'president' || session.role == 'club-secretary';
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
    final canEdit = session.role == 'admin' || session.role == 'advisor' || session.role == 'president' || session.role == 'club-secretary';
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
                                if (val == 'delete') {
                                  await widget.appState.deleteTask(taskId);
                                } else {
                                  await widget.appState.updateTask(taskId, {'status': val});
                                }
                                _reloadSectionData();
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
                                  msg['senderName']?.toString() ?? 'Officer',
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
                      await widget.appState.sendClubMessage(
                        clubId: _selectedClub!.id,
                        title: 'Board Message',
                        body: text,
                      );
                      _chatController.clear();
                      _reloadSectionData();
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
    final canEdit = session.role == 'admin' || session.role == 'advisor' || session.role == 'president' || session.role == 'club-secretary';
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
    final events = widget.appState.posts
        .where((p) => p.clubId == _selectedClub!.id && p.isEvent && (p.budgetImageUrl?.isNotEmpty ?? false))
        .toList();

    final isVerifier = session.role == 'admin' || session.role == 'advisor';

    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Budget Approvals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                                final ok = await widget.appState.verifyEventBudget(ev.id);
                                if (ok && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Budget verified!')));
                                  _reloadSectionData();
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
                await widget.appState.createNotification(
                  title: titleController.text.trim(),
                  message: messageController.text.trim(),
                  type: type,
                  clubId: type == 'club' ? _selectedClub?.id : null,
                );
                navigator.pop();
                _reloadSectionData();
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
                await widget.appState.createClub(
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  fullForm: fullFormController.text.trim(),
                  category: category,
                  image: uploadedImageUrl ?? '',
                  departments: selectedDepartments.toList(),
                );
                navigator.pop();
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
                await widget.appState.assignTeacher(
                  name: nameController.text.trim(),
                  email: emailController.text.trim(),
                );
                navigator.pop();
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
                if (nameController.text.isEmpty || emailController.text.isEmpty) return;
                if (isEditing) {
                  final mId = member['_id']?.toString() ?? member['id']?.toString() ?? '';
                  await widget.appState.updateClubMember(_selectedClub!.id, mId, {
                    'name': nameController.text.trim(),
                    'email': emailController.text.trim(),
                    'role': roleController.text.trim(),
                    'boardType': boardType,
                    'academicYear': academicYear,
                  });
                } else {
                  await widget.appState.addClubMember(
                    _selectedClub!.id,
                    name: nameController.text.trim(),
                    email: emailController.text.trim(),
                    role: roleController.text.trim(),
                    boardType: boardType,
                    academicYear: academicYear,
                    joinedAt: DateTime.now(),
                  );
                }
                if (mounted) {
                  Navigator.of(ctx).pop();
                  _reloadSectionData();
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
        title: const Text('Add Club to Monitor'),
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
                  await widget.appState.addTeacherClub(club.id);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _initializeDashboard(); // Reload monitored clubs list
                },
              );
            },
          ),
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
