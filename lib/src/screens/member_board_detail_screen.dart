import 'dart:async';
import 'package:flutter/material.dart';

import '../models/club.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/start_new_year_sheet.dart';
import '../widgets/promote_members_sheet.dart';

class MemberBoardDetailScreen extends StatefulWidget {
  const MemberBoardDetailScreen({
    super.key,
    required this.appState,
    required this.club,
  });

  final AppState appState;
  final Club club;

  @override
  State<MemberBoardDetailScreen> createState() => _MemberBoardDetailScreenState();
}

class _MemberBoardDetailScreenState extends State<MemberBoardDetailScreen> {
  // Initialized eagerly so FutureBuilder never hits LateInitializationError
  // on the first build (before the async _loadData() callbacks fire).
  Future<List<Map<String, dynamic>>> _membersFuture = Future.value([]);
  Future<Map<String, dynamic>> _termsFuture = Future.value({});

  String _boardFilter = '';
  String _selectedTermYear = '';
  String _currentActiveTerm = '';
  List<String> _availableTerms = [];
  List<Map<String, dynamic>> _rawMembers = [];
  late StreamSubscription<String> _refreshSub;

  static const _boardOrder = ['main', 'executive', 'member'];
  static const _boardLabels = {
    'main': 'Main Board (TY)',
    'executive': 'Executive Board (SY)',
    'member': 'Member Board (FY)',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshSub = widget.appState.refreshEvents.listen((event) {
      if (event == 'members_${widget.club.id}') {
        _fetchMembersForTerm(_selectedTermYear.isEmpty ? _currentActiveTerm : _selectedTermYear);
      }
    });
  }

  @override
  void dispose() {
    _refreshSub.cancel();
    super.dispose();
  }

  void _loadData() {
    _termsFuture = widget.appState.fetchClubTerms(widget.club.id);
    _termsFuture.then((data) {
      if (mounted) {
        setState(() {
          _currentActiveTerm = data['currentTerm']?.toString() ?? '2025-2026';
          _availableTerms = List<String>.from(data['terms'] ?? [_currentActiveTerm]);
          if (_selectedTermYear.isEmpty) {
            _selectedTermYear = _currentActiveTerm;
          }
        });
        _fetchMembersForTerm(_selectedTermYear);
      }
    }).catchError((_) {
      _fetchMembersForTerm('');
    });
  }

  void _fetchMembersForTerm(String termYear) {
    setState(() {
      _membersFuture = widget.appState.fetchClubMembers(
        widget.club.id,
        termYear: termYear == 'all' ? null : termYear,
      );
    });
  }

  bool _canPerformHandover() {
    final session = widget.appState.session;
    if (session == null) return false;
    return session.canManageMembersOf(widget.club.id, club: widget.club);
  }

  void _openStartNewYearSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StartNewYearSheet(
        club: widget.club,
        appState: widget.appState,
        onSuccess: (msg) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          _loadData();
        },
      ),
    );
  }

  void _openPromoteMembersSheet() async {
    // Fetch previous term members if possible
    final terms = _availableTerms.where((t) => t != _currentActiveTerm).toList();
    final prevTerm = terms.isNotEmpty ? terms.first : null;
    
    final prevMembers = await widget.appState.fetchClubMembers(
      widget.club.id,
      termYear: prevTerm,
    );

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PromoteMembersSheet(
        club: widget.club,
        appState: widget.appState,
        previousMembers: prevMembers,
        onSuccess: (msg) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          _loadData();
        },
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupByBoard(List<Map<String, dynamic>> members) {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final bt in _boardOrder) {
      result[bt] = members.where((m) => (m['boardType']?.toString() ?? 'member') == bt).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isPastBoard = _selectedTermYear.isNotEmpty &&
        _selectedTermYear != 'all' &&
        _selectedTermYear != _currentActiveTerm;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.club.name),
        actions: [
          if (_canPerformHandover())
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (val) {
                if (val == 'handover') _openStartNewYearSheet();
                if (val == 'promote') _openPromoteMembersSheet();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'handover',
                  child: Row(
                    children: [
                      Icon(Icons.autorenew, size: 20),
                      SizedBox(width: 8),
                      Text('Start New Academic Year'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'promote',
                  child: Row(
                    children: [
                      Icon(Icons.group_add, size: 20),
                      SizedBox(width: 8),
                      Text('Promote / Import Roster'),
                    ],
                  ),
                ),
              ],
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                // Board filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _boardFilter,
                    decoration: const InputDecoration(
                      labelText: 'Board Tier',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All Tiers')),
                      DropdownMenuItem(value: 'main', child: Text('Main (TY)')),
                      DropdownMenuItem(value: 'executive', child: Text('Executive (SY)')),
                      DropdownMenuItem(value: 'member', child: Text('Member (FY)')),
                    ],
                    onChanged: (v) => setState(() => _boardFilter = v ?? ''),
                  ),
                ),
                const SizedBox(width: 12),
                // Academic Term Year filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    // Guard against '' value when terms haven't loaded yet —
                    // avoids the "exactly one item" assertion crash on first build.
                    value: _availableTerms.isEmpty
                        ? null
                        : (_selectedTermYear.isEmpty
                            ? _currentActiveTerm
                            : _selectedTermYear),
                    isExpanded: true, // Prevents right-overflow of selected text
                    decoration: const InputDecoration(
                      labelText: 'Term Year',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('All Terms')),
                      ..._availableTerms.map((term) {
                        final isActive = term == _currentActiveTerm;
                        return DropdownMenuItem(
                          value: term,
                          child: Text(
                            isActive ? '$term ✓' : term,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedTermYear = v);
                        _fetchMembersForTerm(v);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allMembers = snapshot.data ?? [];
          _rawMembers = allMembers;

          final displayBoards = _boardFilter.isEmpty
              ? _boardOrder
              : [_boardFilter];

          final grouped = _groupByBoard(allMembers);

          return Column(
            children: [
              // Past Board Banner indicator
              if (isPastBoard)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.amber.shade900.withValues(alpha: 0.15),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Viewing $_selectedTermYear Past Board Archive (Read-Only)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.amber.shade300
                                : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: allMembers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.groups_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              isPastBoard
                                  ? 'No archived members found for $_selectedTermYear'
                                  : 'No active members found',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      )
                    : CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final boardType = displayBoards[index];
                                  final boardMembers = grouped[boardType] ?? [];
                                  if (boardMembers.isEmpty) return const SizedBox.shrink();

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (index > 0) const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: AppTheme.accent(context),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            _boardLabels[boardType] ?? boardType,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accent(context).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '${boardMembers.length}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.accent(context),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ...boardMembers.map(
                                        (member) => _MemberCard(
                                          member: member,
                                          termYear: _selectedTermYear.isEmpty
                                              ? _currentActiveTerm
                                              : _selectedTermYear,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                                childCount: displayBoards.length,
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 32),
                              child: Center(
                                child: Text(
                                  'Total: ${allMembers.length} member${allMembers.length == 1 ? '' : 's'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
      // FAB removed — 'Start New Year' is now at the top of the member list
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.termYear});
  final Map<String, dynamic> member;
  final String termYear;

  @override
  Widget build(BuildContext context) {
    String name = member['name']?.toString().trim() ?? '';
    final role = member['role']?.toString().trim() ?? 'Member';
    final email = member['email']?.toString().trim() ?? '';
    final academicYear = member['academicYear']?.toString() ?? '';

    final rolesList = ['president', 'secretary', 'treasurer', 'advisor', 'member', 'club-member', 'club-secretary', 'user', 'unknown', ''];
    final isRolePlaceholder = rolesList.contains(name.toLowerCase()) || name.toLowerCase() == role.toLowerCase();

    if (isRolePlaceholder || name.isEmpty) {
      if (email.isNotEmpty) {
        final handle = email.split('@')[0].replaceAll('.', ' ').replaceAll('_', ' ');
        final words = handle.split(' ').where((w) => w.isNotEmpty);
        if (words.isNotEmpty) {
          name = words.map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
        } else {
          name = email;
        }
      } else {
        name = 'Unregistered Member';
      }
    }

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final profileImage = member['profileImage']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundImage: (profileImage != null && profileImage.isNotEmpty)
                ? NetworkImage(profileImage)
                : null,
            backgroundColor: AppTheme.accent(context).withValues(alpha: 0.15),
            child: (profileImage == null || profileImage.isEmpty)
                ? Text(initial, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent(context)))
                : null,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (academicYear.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    academicYear,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role, style: TextStyle(color: AppTheme.accent(context), fontWeight: FontWeight.w500, fontSize: 12)),
              if (email.isNotEmpty)
                Text(email, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          isThreeLine: email.isNotEmpty,
        ),
      ),
    );
  }
}

