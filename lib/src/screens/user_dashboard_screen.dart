import 'package:flutter/material.dart';

import '../models/club.dart';
import '../models/post_item.dart';
import '../models/user_session.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'club_detail_screen.dart';
import 'dashboard_screen.dart';
import 'post_detail_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({
    super.key,
    required this.appState,
    required this.onOpenProfileSettings,
  });

  final AppState appState;
  final VoidCallback onOpenProfileSettings;

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  List<Map<String, dynamic>> _userRsvps = [];
  bool _isLoadingRsvps = false;
  String? _rsvpError;

  @override
  void initState() {
    super.initState();
    _loadUserRsvps();
    widget.appState.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadUserRsvps() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRsvps = true;
      _rsvpError = null;
    });

    try {
      final rsvps = await widget.appState.fetchUserRsvps();
      if (mounted) {
        setState(() {
          _userRsvps = rsvps;
          _isLoadingRsvps = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _rsvpError = e.toString();
          _isLoadingRsvps = false;
        });
      }
    }
  }

  bool _isClubOfficer(UserSession session) {
    final role = session.role.toLowerCase();
    return role == 'president' ||
        role == 'club-secretary' ||
        role == 'treasurer' ||
        role == 'advisor';
  }

  String _getUserRoleInClub(UserSession session, Club club) {
    final email = session.email.toLowerCase();
    if (club.presidentEmail.toLowerCase() == email) return 'President';
    if (club.secretaryEmail.toLowerCase() == email) return 'Secretary';
    if (club.treasurerEmail.toLowerCase() == email) return 'Treasurer';
    if (club.advisorEmail.toLowerCase() == email) return 'Advisor';
    return 'Member';
  }

  List<Map<String, dynamic>> _getAvailableManagementRoles(UserSession session) {
    final email = session.email.toLowerCase();
    final list = <Map<String, dynamic>>[];
    
    for (final club in widget.appState.clubs) {
      if (club.presidentEmail.toLowerCase() == email) {
        list.add({'club': club, 'role': 'President', 'type': 'club'});
      }
      if (club.secretaryEmail.toLowerCase() == email) {
        list.add({'club': club, 'role': 'Secretary', 'type': 'club'});
      }
      if (club.treasurerEmail.toLowerCase() == email) {
        list.add({'club': club, 'role': 'Treasurer', 'type': 'club'});
      }
      if (club.advisorEmail.toLowerCase() == email) {
        list.add({'club': club, 'role': 'Advisor', 'type': 'club'});
      }
    }
    
    final hasTeacherRole = session.roles.contains('teacher') || session.role == 'teacher';
    if (hasTeacherRole) {
      list.add({'role': 'Teacher', 'type': 'teacher'});
    }
    
    final hasAdminRole = session.roles.contains('admin') || session.role == 'admin';
    if (hasAdminRole) {
      list.add({'role': 'Admin', 'type': 'admin'});
    }
    
    return list;
  }

  void _showRoleSelector(UserSession session, List<Map<String, dynamic>> roles) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Management Dashboard',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...roles.map((cr) {
                  final type = cr['type'] as String;
                  final role = cr['role'] as String;
                  final Club? club = cr['club'] as Club?;
                  
                  String title = '';
                  String subtitle = '';
                  IconData icon = Icons.groups_rounded;
                  
                  if (type == 'club' && club != null) {
                    title = '${club.name} ($role)';
                    subtitle = club.fullForm.isNotEmpty ? club.fullForm : 'Club Dashboard';
                    icon = Icons.dashboard_rounded;
                  } else if (type == 'teacher') {
                    title = 'Teacher Dashboard';
                    subtitle = 'Monitor and supervise assigned clubs';
                    icon = Icons.school_rounded;
                  } else if (type == 'admin') {
                    title = 'System Admin Dashboard';
                    subtitle = 'Manage all clubs, posts, and teachers';
                    icon = Icons.admin_panel_settings_rounded;
                  }
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100, width: 1.5),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navy),
                      ),
                      subtitle: Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DashboardScreen(
                              appState: widget.appState,
                              initialClub: club,
                              initialRole: type == 'club' ? role.toLowerCase() : type,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleManagementTap(UserSession session, Club? defaultClub) {
    final roles = _getAvailableManagementRoles(session);
    if (roles.length > 1) {
      _showRoleSelector(session, roles);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            appState: widget.appState,
            initialClub: defaultClub,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.appState.session;
    if (session == null) {
      return const Center(child: Text('Please sign in to view your dashboard.'));
    }

    if (_isLoadingRsvps && _userRsvps.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final isOfficer = _isClubOfficer(session);
    final isTeacher = session.role == 'teacher' || session.roles.contains('teacher');
    final hasManagementAccess = isOfficer || isTeacher;

    Club? managedClub;
    if (isOfficer) {
      final clubId = session.clubId;
      final clubNameLower = session.clubName?.toLowerCase() ?? '';
      
      if (clubId != null) {
        final byId = widget.appState.clubs.where((c) => c.id == clubId).toList();
        if (byId.isNotEmpty) {
          managedClub = byId.first;
        }
      }
      
      if (managedClub == null && clubNameLower.isNotEmpty) {
        final byName = widget.appState.clubs.where((c) {
          final cName = c.name.toLowerCase();
          final cFull = c.fullForm.toLowerCase();
          return cName == clubNameLower || cFull == clubNameLower;
        }).toList();
        if (byName.isNotEmpty) {
          managedClub = byName.first;
        }
      }

      if (managedClub == null && clubNameLower.isNotEmpty) {
        final byLoose = widget.appState.clubs.where((c) {
          final cName = c.name.toLowerCase();
          return clubNameLower.contains(cName) || cName.contains(clubNameLower);
        }).toList();
        if (byLoose.isNotEmpty) {
          managedClub = byLoose.first;
        }
      }
    }

    // Filter user's clubs (either liked or where they are an officer)
    final userClubs = widget.appState.clubs.where((club) {
      final isLiked = session.likedClubs.contains(club.id);
      final email = session.email.toLowerCase();
      final isPresident = club.presidentEmail.toLowerCase() == email;
      final isSecretary = club.secretaryEmail.toLowerCase() == email;
      final isTreasurer = club.treasurerEmail.toLowerCase() == email;
      final isAdvisor = club.advisorEmail.toLowerCase() == email;
      return isLiked || isPresident || isSecretary || isTreasurer || isAdvisor;
    }).toList();

    // Map RSVPs to actual PostItems
    final List<Map<String, dynamic>> rsvpsWithEvents = [];
    for (final rsvp in _userRsvps) {
      final eventId = rsvp['eventId']?.toString();
      final match = widget.appState.posts
          .where((p) => p.id == eventId && p.isEvent)
          .toList();
      if (match.isNotEmpty) {
        rsvpsWithEvents.add({
          'rsvp': rsvp,
          'event': match.first,
        });
      }
    }

    // Split RSVPs into Upcoming and Attended
    final now = DateTime.now();
    final upcomingRsvps = rsvpsWithEvents.where((item) {
      final event = item['event'] as PostItem;
      return event.date != null && event.date!.isAfter(now);
    }).toList();

    final attendedRsvps = rsvpsWithEvents.where((item) {
      final event = item['event'] as PostItem;
      final rsvp = item['rsvp'] as Map<String, dynamic>;
      final isPast = event.date != null && event.date!.isBefore(now);
      final isPresent = rsvp['attendance'] == 'present';
      return isPast || isPresent;
    }).toList();

    final certificateRsvps = rsvpsWithEvents.where((item) {
      final rsvp = item['rsvp'] as Map<String, dynamic>;
      final certUrl = rsvp['certificateUrl']?.toString();
      return certUrl != null && certUrl.isNotEmpty;
    }).toList();

    // Find the next upcoming event
    PostItem? nextUpcomingEvent;
    if (upcomingRsvps.isNotEmpty) {
      // Sort upcoming events by date ascending
      upcomingRsvps.sort((a, b) {
        final dateA = (a['event'] as PostItem).date ?? DateTime.now();
        final dateB = (b['event'] as PostItem).date ?? DateTime.now();
        return dateA.compareTo(dateB);
      });
      nextUpcomingEvent = upcomingRsvps.first['event'] as PostItem;
    }

    return RefreshIndicator(
      onRefresh: () async {
        await widget.appState.refreshAll();
        await _loadUserRsvps();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_rsvpError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  'Error loading activity: $_rsvpError',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Profile Block
                  GestureDetector(
                    onTap: widget.onOpenProfileSettings,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade100, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Circular avatar
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFC084FC),
                                  width: 2,
                                ),
                              image: session.profileImage != null &&
                                      session.profileImage!.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(session.profileImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: session.profileImage == null ||
                                    session.profileImage!.isEmpty
                                ? Center(
                                    child: Text(
                                      session.name.isNotEmpty
                                          ? session.name[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF6D28D9),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.navy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      isOfficer ? 'Core Member' : 'Member',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isOfficer
                                            ? AppTheme.purple
                                            : AppTheme.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  session.email,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Walkway to Club Management
                  if (hasManagementAccess) ...[
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => _handleManagementTap(session, managedClub),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade100, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isOfficer ? 'Core Member' : 'Faculty Monitor',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isOfficer 
                                            ? (managedClub?.name ?? session.clubName ?? 'Your Club')
                                            : 'Monitored Clubs',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: AppTheme.navy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Specific Club Logo Container
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.grey.shade100, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.015),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: (isOfficer && managedClub != null && managedClub.imageAsset.isNotEmpty)
                                        ? (managedClub.imageAsset.startsWith('http')
                                            ? Image.network(managedClub.imageAsset, fit: BoxFit.contain)
                                            : Image.asset(
                                                managedClub.imageAsset.startsWith('/')
                                                    ? 'assets/images${managedClub.imageAsset}'
                                                    : managedClub.imageAsset,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) => const Icon(Icons.groups_rounded, color: AppTheme.blue),
                                              ))
                                        : const Icon(Icons.groups_rounded, color: AppTheme.blue, size: 28),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                // Indigo/blue pill button
                                InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () => _handleManagementTap(session, managedClub),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F46E5),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF4F46E5).withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Go to Club Management',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.grey.shade400,
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // 3. My Clubs Heading
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Clubs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navy,
                        ),
                      ),
                      Text(
                        '${userClubs.length} ${userClubs.length == 1 ? 'Club' : 'Clubs'}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // My Clubs List (Horizontal scroll)
                  if (userClubs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      alignment: Alignment.center,
                      child: const Text(
                        'You haven\'t liked or joined any clubs yet.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    )
                  else
                    SizedBox(
                      height: 95,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: userClubs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final club = userClubs[index];
                          final role = _getUserRoleInClub(session, club);
                          return Container(
                            width: 190,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade100, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.015),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ClubDetailScreen(
                                      appState: widget.appState,
                                      club: club,
                                    ),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  // Dark navy container for logo
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF002147),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.all(6),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: club.imageAsset.isNotEmpty
                                          ? (club.imageAsset.startsWith('http')
                                              ? Image.network(club.imageAsset, fit: BoxFit.cover)
                                              : Image.asset(
                                                  club.imageAsset.startsWith('/')
                                                      ? 'assets/images${club.imageAsset}'
                                                      : club.imageAsset,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Center(
                                                    child: Text(
                                                      club.icon.isNotEmpty ? club.icon : '🏛️',
                                                      style: const TextStyle(fontSize: 16),
                                                    ),
                                                  ),
                                                ))
                                          : Center(
                                              child: Text(
                                                club.icon.isNotEmpty ? club.icon : '🏛️',
                                                style: const TextStyle(fontSize: 16),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          club.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.navy,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          role,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: role != 'Member'
                                                ? AppTheme.purple
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (role == 'Member')
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.grey.shade400,
                                      size: 16,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // 4. My Activity Heading
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navy,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showAllActivityBottomSheet(
                            rsvpsWithEvents, upcomingRsvps, attendedRsvps, certificateRsvps),
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // My Activity Stat Row
                  Row(
                    children: [
                      Expanded(
                        child: _ActivityStatCard(
                          icon: Icons.calendar_month_rounded,
                          iconColor: const Color(0xFF10B981), // Green
                          bgColor: const Color(0xFFE6FDF5),
                          value: '${upcomingRsvps.length}',
                          label: 'Upcoming',
                          onTap: () => _showRsvpsListBottomSheet(
                            'Upcoming Events',
                            upcomingRsvps,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActivityStatCard(
                          icon: Icons.check_circle_rounded,
                          iconColor: const Color(0xFF3B82F6), // Blue
                          bgColor: const Color(0xFFEFF6FF),
                          value: '${attendedRsvps.length}',
                          label: 'Attended',
                          onTap: () => _showRsvpsListBottomSheet(
                            'Attended Events',
                            attendedRsvps,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActivityStatCard(
                          icon: Icons.workspace_premium_rounded,
                          iconColor: const Color(0xFFF59E0B), // Orange
                          bgColor: const Color(0xFFFFFBEB),
                          value: '${certificateRsvps.length}',
                          label: 'Certificates',
                          onTap: () => _showCertificatesBottomSheet(
                            certificateRsvps,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 5. Upcoming Event Heading
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Upcoming Event',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navy,
                        ),
                      ),
                      if (upcomingRsvps.isNotEmpty)
                        GestureDetector(
                          onTap: () => _showRsvpsListBottomSheet(
                            'Upcoming Events',
                            upcomingRsvps,
                          ),
                          child: const Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.blue,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Upcoming Event Card
                  if (nextUpcomingEvent == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy_rounded,
                              size: 40, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          const Text(
                            'No registered upcoming events.',
                            style: TextStyle(color: AppTheme.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PostDetailScreen(
                              appState: widget.appState,
                              initialPost: nextUpcomingEvent!,
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
                              width: 60,
                              height: 68,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _getMonthName(nextUpcomingEvent.date),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${nextUpcomingEvent.date?.day ?? ""}',
                                    style: const TextStyle(
                                      fontSize: 22,
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
                                    nextUpcomingEvent.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule_rounded,
                                          size: 12, color: AppTheme.muted),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          nextUpcomingEvent.time ?? 'TBD',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.muted),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.place_outlined,
                                          size: 12, color: AppTheme.muted),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          nextUpcomingEvent.location ?? 'Campus',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.muted),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7), // Light green
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Going',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF15803D), // Dark green
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(DateTime? date) {
    if (date == null) return "MAY";
    const months = [
      "JAN",
      "FEB",
      "MAR",
      "APR",
      "MAY",
      "JUN",
      "JUL",
      "AUG",
      "SEP",
      "OCT",
      "NOV",
      "DEC"
    ];
    if (date.month >= 1 && date.month <= 12) {
      return months[date.month - 1];
    }
    return "MAY";
  }

  void _showRsvpsListBottomSheet(
      String title, List<Map<String, dynamic>> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 14),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No events to show.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final ev = items[index]['event'] as PostItem;
                      final rsvp = items[index]['rsvp'] as Map<String, dynamic>;
                      final rsvpId = (rsvp['id'] ?? rsvp['_id'])?.toString() ?? '';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          ev.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${ev.clubName} • ${ev.date != null ? "${ev.date!.day}/${ev.date!.month}/${ev.date!.year}" : "TBD"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (title.toLowerCase().contains('upcoming') && rsvpId.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
                                tooltip: 'Cancel RSVP',
                                onPressed: () {
                                  _confirmCancelRsvp(ev, rsvpId);
                                },
                              ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(
                                appState: widget.appState,
                                initialPost: ev,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _confirmCancelRsvp(PostItem event, String rsvpId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel RSVP'),
        content: Text('Are you sure you want to cancel your RSVP for "${event.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close bottom sheet to trigger fresh reload
              try {
                await widget.appState.cancelRsvp(event.id, rsvpId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('RSVP cancelled successfully.')),
                  );
                }
                _loadUserRsvps();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to cancel RSVP: $e')),
                  );
                }
              }
            },
            child: const Text('Cancel RSVP'),
          ),
        ],
      ),
    );
  }

  void _showCertificatesBottomSheet(List<Map<String, dynamic>> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Certificates',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 14),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No certificates earned yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final ev = items[index]['event'] as PostItem;
                      final rsvp = items[index]['rsvp'] as Map<String, dynamic>;
                      final url = rsvp['certificateUrl'].toString();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          ev.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(ev.clubName,
                            style: const TextStyle(fontSize: 12)),
                        trailing: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Opening certificate link: $url')),
                            );
                          },
                          icon: const Icon(Icons.download_rounded, size: 14),
                          label: const Text('View',
                              style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showAllActivityBottomSheet(
      List<Map<String, dynamic>> all,
      List<Map<String, dynamic>> upcoming,
      List<Map<String, dynamic>> attended,
      List<Map<String, dynamic>> certificates) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Full Activity Log',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: all.isEmpty
                        ? const Center(child: Text('No registered activities.'))
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: all.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final ev = all[index]['event'] as PostItem;
                              final rsvp = all[index]['rsvp'] as Map<String, dynamic>;
                              final isCert = rsvp['certificateUrl']?.toString().isNotEmpty ?? false;
                              final isUpcoming = ev.date != null && ev.date!.isAfter(DateTime.now());
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  ev.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                subtitle: Text(
                                  '${ev.clubName} • ${ev.date != null ? "${ev.date!.day}/${ev.date!.month}/${ev.date!.year}" : "TBD"}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isUpcoming
                                            ? Colors.green
                                            : (isCert
                                                ? Colors.orange
                                                : Colors.blue))
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isUpcoming
                                        ? 'Upcoming'
                                        : (isCert ? 'Certified' : 'Attended'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isUpcoming
                                          ? Colors.green.shade700
                                          : (isCert
                                              ? Colors.orange.shade700
                                              : Colors.blue.shade700),
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PostDetailScreen(
                                        appState: widget.appState,
                                        initialPost: ev,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
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
}

class _ActivityStatCard extends StatelessWidget {
  const _ActivityStatCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
