import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';

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

  final Map<String, int> _clubTaskCounts = {};

  int _getClubMessagesCount(Club club) {
    return widget.appState.notifications.where((n) {
      if (n.isRead) return false;
      if (n.clubId != null && n.clubId!.isNotEmpty) {
        return n.clubId == club.id;
      }
      return n.title.toLowerCase().contains(club.name.toLowerCase());
    }).length;
  }

  int _getClubTasksCount(Club club) {
    return _clubTaskCounts[club.id] ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _loadUserRsvps();
    _loadTaskCounts();
    widget.appState.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  Future<void> _loadTaskCounts() async {
    final session = widget.appState.session;
    if (session == null) return;
    final clubIds = <String>{
      ...session.likedClubs,
      ...session.memberships.map((m) => m.clubId),
    };
    for (final clubId in clubIds) {
      if (clubId.isEmpty) continue;
      try {
        final tasks = await widget.appState.fetchClubTasks(clubId);
        final club = widget.appState.clubs.where((c) => c.id == clubId).firstOrNull;
        final isOfficer = session.isClubOfficerOf(clubId, club: club);
        final pending = tasks.where((t) {
          final isPending = (t['status']?.toString().toLowerCase() != 'completed' && t['status']?.toString().toLowerCase() != 'done');
          if (!isPending) return false;
          if (isOfficer) return true;
          final assignedTo = t['assignedTo'];
          if (assignedTo is List) {
            return assignedTo.contains(session.name);
          }
          return false;
        }).length;
        if (mounted) {
          setState(() {
            _clubTaskCounts[clubId] = pending;
          });
        }
      } catch (_) {}
    }
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
    // Use memberships to check if user is an officer of any club,
    // matching backend verifyClubOfficer middleware logic.
    return session.isAnyClubOfficer;
  }

  String _getUserRoleInClub(UserSession session, Club club) {
    // Check memberships first for the actual custom role
    final membership = session.membershipFor(club.id);
    if (membership != null) return membership.role;
    // Fallback to email-based check for legacy compatibility
    final email = session.email.toLowerCase();
    if (club.presidentEmail.toLowerCase() == email) return 'President';
    if (club.secretaryEmail.toLowerCase() == email) return 'Secretary';
    if (club.treasurerEmail.toLowerCase() == email) return 'Treasurer';
    if (club.advisorEmail.toLowerCase() == email) return 'Advisor';
    return 'Member';
  }

  int _getRolePriority(String role) {
    final r = role.toLowerCase().trim();
    if (r.contains('president') && !r.contains('vice')) return 1;
    if (r.contains('vice') || r.contains('vp')) return 2;
    if (r.contains('secretary')) return 3;
    if (r.contains('treasurer')) return 4;
    if (r.contains('advisor')) return 5;
    if (r != 'member') return 6; // Other officer/cabinet roles
    return 7; // Regular members
  }

  List<Map<String, dynamic>> _getAvailableManagementRoles(UserSession session) {
    final list = <Map<String, dynamic>>[];
    final addedClubIds = <String>{};
    
    // 1. Scan memberships for officer-level access (boardType main/executive or officer role)
    for (final membership in session.memberships) {
      if (membership.isOfficer && !addedClubIds.contains(membership.clubId)) {
        // Find the matching Club object from the loaded clubs list
        final matchingClubs = widget.appState.clubs.where((c) => c.id == membership.clubId).toList();
        if (matchingClubs.isNotEmpty) {
          list.add({'club': matchingClubs.first, 'role': membership.role, 'type': 'club'});
          addedClubIds.add(membership.clubId);
        }
      }
    }
    
    // 2. Fallback: also check email-based officer roles for legacy clubs not in memberships
    final email = session.email.toLowerCase();
    for (final club in widget.appState.clubs) {
      if (addedClubIds.contains(club.id)) continue;
      if (club.presidentEmail.toLowerCase() == email) {
        list.add({'club': club, 'role': 'President', 'type': 'club'});
        addedClubIds.add(club.id);
      } else if (club.secretaryEmail.toLowerCase() == email) {
        list.add({'club': club, 'role': 'Secretary', 'type': 'club'});
        addedClubIds.add(club.id);
      } else if (club.treasurerEmail.toLowerCase() == email) {
        list.add({'club': club, 'role': 'Treasurer', 'type': 'club'});
        addedClubIds.add(club.id);
      } else if (club.advisorEmail.toLowerCase() == email) {
        list.add({'club': club, 'role': 'Advisor', 'type': 'club'});
        addedClubIds.add(club.id);
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
      backgroundColor: Theme.of(context).cardColor,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
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
                    Text(
                      'Select Management Dashboard',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: roles.map((cr) {
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
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? AppTheme.darkBorder : Theme.of(context).dividerColor,
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkElevated : const Color(0xFFEFF6FF),
                                shape: BoxShape.circle,
                                border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
                              ),
                              child: Icon(icon, color: isDark ? Colors.white : AppTheme.accent(context), size: 20),
                            ),
                            title: Text(
                              title,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navyColor(context)),
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
                      }).toList(),
                    ),
                  ),
                ),
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
    } else if (roles.length == 1) {
      final single = roles.first;
      final type = single['type'] as String;
      final role = single['role'] as String;
      final Club? club = single['club'] as Club?;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            appState: widget.appState,
            initialClub: club ?? defaultClub,
            initialRole: type == 'club' ? role.toLowerCase() : type,
          ),
        ),
      );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (session == null) {
      return const Center(child: Text('Please sign in to view your dashboard.'));
    }

    if (_isLoadingRsvps && _userRsvps.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final isOfficer = _isClubOfficer(session);
    final isTeacher = session.role == 'teacher' || session.roles.contains('teacher');
    final isAdvisor = session.role == 'advisor' || session.roles.contains('advisor');
    final isStaff = isTeacher || isAdvisor;
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

    // Filter user's clubs into Memberships vs Followed/Liked
    final memberClubIds = session.memberships.map((m) => m.clubId).toSet();
    final membershipClubs = widget.appState.clubs.where((club) {
      final isMember = memberClubIds.contains(club.id);
      final email = session.email.toLowerCase();
      final isPresident = club.presidentEmail.toLowerCase() == email;
      final isSecretary = club.secretaryEmail.toLowerCase() == email;
      final isTreasurer = club.treasurerEmail.toLowerCase() == email;
      final isAdvisor = club.advisorEmail.toLowerCase() == email;
      return isMember || isPresident || isSecretary || isTreasurer || isAdvisor;
    }).toList();
    final membershipClubIds = membershipClubs.map((c) => c.id).toSet();

    // Sort membership clubs by role priority (President > Vice President > Secretary > Treasurer > Advisor > Officer > Member)
    membershipClubs.sort((a, b) {
      final roleA = _getUserRoleInClub(session, a);
      final roleB = _getUserRoleInClub(session, b);
      final priorityA = _getRolePriority(roleA);
      final priorityB = _getRolePriority(roleB);
      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }
      return a.name.compareTo(b.name);
    });

    final likedClubs = widget.appState.clubs.where((club) {
      return session.likedClubs.contains(club.id) && !membershipClubIds.contains(club.id);
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
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error loading activity: $_rsvpError',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _loadUserRsvps,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ],
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
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Theme.of(context).dividerColor,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.02),
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
                                          : 'A',
                                      style: const TextStyle(
                                        fontSize: 26,
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
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white.withValues(alpha: 0.08)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        session.role.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        session.email,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.mutedColor(context)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
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

                  // 2. Walkway to Club Management
                  if (hasManagementAccess) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Management',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () => _handleManagementTap(session, managedClub),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Theme.of(context).dividerColor,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.02),
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
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Theme.of(context).colorScheme.onSurface,
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
                                    color: Theme.of(context).brightness == Brightness.dark ? AppTheme.surfaceBg(context) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : Theme.of(context).dividerColor,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.015),
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
                                                errorBuilder: (_, _, _) => Icon(Icons.groups_rounded, color: AppTheme.accent(context)),
                                              ))
                                        : Icon(Icons.groups_rounded, color: AppTheme.accent(context), size: 28),
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
                                      color: isDark ? Colors.white : const Color(0xFF4F46E5),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isDark ? Colors.black.withValues(alpha: 0.1) : const Color(0xFF4F46E5).withValues(alpha: 0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Go to Club Management',
                                          style: TextStyle(
                                            color: isDark ? Colors.black : Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: isDark ? Colors.black : Colors.white,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Theme.of(context).dividerColor,
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // 3. My Clubs & Memberships Heading
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Clubs & Memberships',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${membershipClubs.length} ${membershipClubs.length == 1 ? 'Club' : 'Clubs'}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // My Clubs & Memberships List (Horizontal scroll with Tasks & Messages buttons)
                  if (membershipClubs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      alignment: Alignment.center,
                      child: const Text(
                        'You are not an official member of any clubs yet.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    )
                  else
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: membershipClubs.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final club = membershipClubs[index];
                          final role = _getUserRoleInClub(session, club);
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          
                          final tasksCount = _getClubTasksCount(club);
                          final messagesCount = _getClubMessagesCount(club);
                          
                          return Container(
                            width: 220,
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
                            child: Column(
                              children: [
                                // Top section - Navigates to Club Detail
                                InkWell(
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
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 8),
                                    child: Row(
                                      children: [
                                        // Dark navy container for logo
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: isDark ? AppTheme.surfaceBg(context) : const Color(0xFF002147),
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
                                                        errorBuilder: (_, _, _) => Center(
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
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context).colorScheme.onSurface,
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
                                                      : AppTheme.mutedColor(context),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                // Divider
                                Divider(
                                  height: 1, 
                                  thickness: 1, 
                                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Theme.of(context).dividerColor
                                ),
                                
                                // Bottom section - Interactive redirection for tasks and messages
                                Expanded(
                                  child: Row(
                                    children: [
                                      // Tasks Button -> Redirects to Tasks tab
                                      Expanded(
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => DashboardScreen(
                                                  appState: widget.appState,
                                                  initialClub: club,
                                                  initialSection: 'Tasks',
                                                ),
                                              ),
                                            );
                                          },
                                          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16)),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                '$tasksCount',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                ),
                                              ),
                                              Text(
                                                tasksCount == 1 ? 'Task' : 'Tasks',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.mutedColor(context),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      VerticalDivider(
                                        width: 1,
                                        thickness: 1,
                                        indent: 8,
                                        endIndent: 8,
                                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Theme.of(context).dividerColor,
                                      ),
                                      // Live Chat Button -> Redirects to Live Chat tab
                                      Expanded(
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => DashboardScreen(
                                                  appState: widget.appState,
                                                  initialClub: club,
                                                  initialSection: 'Live Chat',
                                                ),
                                              ),
                                            );
                                          },
                                          borderRadius: const BorderRadius.only(bottomRight: Radius.circular(16)),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.chat_bubble_rounded,
                                                size: 16,
                                                color: AppTheme.purple,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '$messagesCount New',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                  // 3b. Followed Clubs Heading
                  if (likedClubs.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Followed Clubs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${likedClubs.length} ${likedClubs.length == 1 ? 'Club' : 'Clubs'}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Followed Clubs List (Clean cards without Task/Message buttons)
                    SizedBox(
                      height: 74,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: likedClubs.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final club = likedClubs[index];
                          return _buildLikedClubCard(club);
                        },
                      ),
                    ),
                  ],
                    if (!isStaff) ...[
                  // 4. My Activity Heading
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showAllActivityBottomSheet(
                            rsvpsWithEvents, upcomingRsvps, attendedRsvps, certificateRsvps),
                        child: Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
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
                      Text(
                        'Upcoming Event',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (upcomingRsvps.isNotEmpty)
                        GestureDetector(
                          onTap: () => _showRsvpsListBottomSheet(
                            'Upcoming Events',
                            upcomingRsvps,
                          ),
                          child: Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
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
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : Theme.of(context).dividerColor,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy_rounded,
                              size: 40, color: AppTheme.mutedColor(context)),
                          const SizedBox(height: 8),
                          Text(
                            'No registered upcoming events.',
                            style: TextStyle(color: AppTheme.mutedColor(context), fontSize: 13),
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
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : Theme.of(context).dividerColor,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.015),
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
                                color: Theme.of(context).brightness == Brightness.dark ? AppTheme.surfaceBg(context) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _getMonthName(nextUpcomingEvent.date),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.accent(context),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${nextUpcomingEvent.date?.day ?? ""}',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Theme.of(context).colorScheme.onSurface,
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
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
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
                                color: isDark ? AppTheme.darkElevated : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(12),
                                border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
                              ),
                              child: Text(
                                'Going',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikedClubCard(Club club) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 200,
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceBg(context) : const Color(0xFF002147),
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
                              errorBuilder: (_, _, _) => Center(
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
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      club.fullForm.isNotEmpty ? club.fullForm : 'Followed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.mutedColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
      backgroundColor: Theme.of(context).cardColor,
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
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
                    separatorBuilder: (_, _) => const Divider(),
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
                                tooltip: 'Cancel Registration',
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
        title: const Text('Cancel Registration'),
        content: Text('Are you sure you want to cancel your registration for "${event.title}"?'),
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
                    const SnackBar(content: Text('Registration cancelled successfully.')),
                  );
                }
                _loadUserRsvps();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to cancel registration: $e')),
                  );
                }
              }
            },
            child: const Text('Cancel Registration'),
          ),
        ],
      ),
    );
  }

  void _showCertificatesBottomSheet(List<Map<String, dynamic>> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
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
                'My Certificates',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
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
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final ev = items[index]['event'] as PostItem;
                      final rsvp = items[index]['rsvp'] as Map<String, dynamic>;
                      final url = rsvp['certificateUrl']?.toString() ?? '';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: url.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  url,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppTheme.accent(context).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(Icons.workspace_premium_rounded, color: AppTheme.accent(context), size: 24),
                                  ),
                                ),
                              )
                            : Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppTheme.accent(context).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.workspace_premium_rounded, color: AppTheme.accent(context), size: 24),
                              ),
                        title: Text(
                          ev.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(ev.clubName,
                            style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // View in Browser
                            IconButton(
                              tooltip: 'View Certificate',
                              icon: const Icon(Icons.open_in_new_rounded, size: 20),
                              color: AppTheme.accent(context),
                              onPressed: url.isNotEmpty
                                  ? () async {
                                      final uri = Uri.parse(url);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      } else {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Could not open certificate URL.')),
                                          );
                                        }
                                      }
                                    }
                                  : null,
                            ),
                            // Download to device
                            IconButton(
                              tooltip: 'Download Certificate',
                              icon: const Icon(Icons.download_rounded, size: 20),
                              color: Colors.green,
                              onPressed: url.isNotEmpty
                                  ? () async {
                                      try {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Downloading certificate...')),
                                        );
                                        final response = await http.get(Uri.parse(url));
                                        if (response.statusCode == 200) {
                                          final dir = await getApplicationDocumentsDirectory();
                                          final safeTitle = ev.title.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
                                          final file = File('${dir.path}/certificate_$safeTitle.jpg');
                                          await file.writeAsBytes(response.bodyBytes);
                                          await OpenFilex.open(file.path);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Certificate saved to ${file.path}')),
                                            );
                                          }
                                        } else {
                                          throw Exception('Download failed: ${response.statusCode}');
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Download failed: $e')),
                                          );
                                        }
                                      }
                                    }
                                  : null,
                            ),
                          ],
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
      backgroundColor: Theme.of(context).cardColor,
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
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Full Activity Log',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navyColor(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: all.isEmpty
                        ? const Center(child: Text('No registered activities.'))
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: all.length,
                            separatorBuilder: (_, _) => const Divider(),
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
                                                : AppTheme.accent(context)))
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
                                              : AppTheme.accent(context)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevated : bgColor,
                shape: BoxShape.circle,
                border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
              ),
              child: Icon(
                icon,
                color: isDark ? Colors.white : iconColor,
                size: 20,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.navyColor(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.mutedColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
