import 'package:flutter/material.dart';

import '../models/club.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

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
  late Future<List<Map<String, dynamic>>> _membersFuture;
  String _boardFilter = '';
  String _yearFilter = DateTime.now().year.toString();

  static const _boardOrder = ['main', 'executive', 'member'];
  static const _boardLabels = {
    'main': 'Main Board (TY)',
    'executive': 'Executive Board (SY)',
    'member': 'Member Board (FY)',
  };

  @override
  void initState() {
    super.initState();
    _membersFuture = widget.appState.fetchClubMembers(widget.club.id);
  }

  List<Map<String, dynamic>> _filterMembers(List<Map<String, dynamic>> all) {
    if (_yearFilter.isEmpty) return all;
    final selectedYear = int.tryParse(_yearFilter) ?? DateTime.now().year;
    return all.where((m) {
      final joinedAt = m['joinedAt'];
      if (joinedAt == null) return true;
      final joinYear = DateTime.tryParse(joinedAt.toString())?.year ?? 0;
      if (joinYear > selectedYear) return false;
      final leftAt = m['leftAt'];
      if (leftAt != null) {
        final leftYear = DateTime.tryParse(leftAt.toString())?.year ?? 9999;
        if (leftYear < selectedYear) return false;
      }
      return true;
    }).toList();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.club.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                // Board filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _boardFilter,
                    decoration: const InputDecoration(
                      labelText: 'Board',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All Boards')),
                      DropdownMenuItem(value: 'main', child: Text('Main (TY)')),
                      DropdownMenuItem(value: 'executive', child: Text('Executive (SY)')),
                      DropdownMenuItem(value: 'member', child: Text('Member (FY)')),
                    ],
                    onChanged: (v) => setState(() => _boardFilter = v ?? ''),
                  ),
                ),
                const SizedBox(width: 12),
                // Year filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _yearFilter,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All Years')),
                      DropdownMenuItem(value: '2024', child: Text('2024')),
                      DropdownMenuItem(value: '2025', child: Text('2025')),
                      DropdownMenuItem(value: '2026', child: Text('2026')),
                      DropdownMenuItem(value: '2027', child: Text('2027')),
                    ],
                    onChanged: (v) => setState(() => _yearFilter = v ?? ''),
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
          final filtered = _filterMembers(allMembers);
          final grouped = _groupByBoard(filtered);

          final displayBoards = _boardFilter.isEmpty
              ? _boardOrder
              : [_boardFilter];

          if (allMembers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('No members found', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            );
          }

          return CustomScrollView(
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
                              Container(width: 4, height: 20, decoration: BoxDecoration(color: AppTheme.blue, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 10),
                              Text(
                                _boardLabels[boardType] ?? boardType,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.blue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('${boardMembers.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.blue)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...boardMembers.map((member) => _MemberCard(member: member)),
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
                      'Total: ${filtered.length} member${filtered.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});
  final Map<String, dynamic> member;

  @override
  Widget build(BuildContext context) {
    final name = member['name']?.toString() ?? 'Unknown';
    final role = member['role']?.toString() ?? 'Member';
    final email = member['email']?.toString() ?? '';
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
            backgroundColor: AppTheme.blue.withValues(alpha: 0.15),
            child: (profileImage == null || profileImage.isEmpty)
                ? Text(initial, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.blue))
                : null,
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role, style: const TextStyle(color: AppTheme.blue, fontWeight: FontWeight.w500, fontSize: 12)),
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
