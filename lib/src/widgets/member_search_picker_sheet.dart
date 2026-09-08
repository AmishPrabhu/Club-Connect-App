import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class MemberSearchPickerSheet extends StatefulWidget {
  const MemberSearchPickerSheet({
    super.key,
    required this.clubId,
    required this.appState,
    this.selectedMemberEmail,
    required this.onMemberSelected,
  });

  final String clubId;
  final AppState appState;
  final String? selectedMemberEmail;
  final void Function(Map<String, dynamic>? member) onMemberSelected;

  @override
  State<MemberSearchPickerSheet> createState() => _MemberSearchPickerSheetState();
}

class _MemberSearchPickerSheetState extends State<MemberSearchPickerSheet> {
  late Future<List<Map<String, dynamic>>> _membersFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _membersFuture = widget.appState.fetchClubMembers(widget.clubId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final mq = MediaQuery.of(context);
    final titleColor = AppTheme.textColor(context);
    final subtitleColor = isDark ? AppTheme.darkMuted : AppTheme.mutedColor(context);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;

    return Container(
      height: mq.size.height * 0.75,
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : const Color(0xFFF6F8FB),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle & Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: cardBg,
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
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Event Manager',
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Assign any member of the club as manager',
                            style: TextStyle(color: subtitleColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search Input Box
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  style: TextStyle(color: titleColor),
                  decoration: InputDecoration(
                    hintText: 'Search member by name or email...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Clear / No Manager option
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.grey,
              child: Icon(Icons.person_off_outlined, color: Colors.white, size: 20),
            ),
            title: Text('No Event Manager', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
            subtitle: Text('Remove assigned event manager', style: TextStyle(color: subtitleColor, fontSize: 12)),
            trailing: widget.selectedMemberEmail == null || widget.selectedMemberEmail!.isEmpty
                ? Icon(Icons.check_circle_rounded, color: AppTheme.accent(context))
                : null,
            onTap: () {
              widget.onMemberSelected(null);
              Navigator.of(context).pop();
            },
          ),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),

          // Filtered Members List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _membersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final members = snapshot.data ?? [];
                final filtered = members.where((m) {
                  final name = (m['name'] ?? m['userName'] ?? '').toString().toLowerCase();
                  final email = (m['email'] ?? m['userEmail'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || email.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _searchQuery.isEmpty ? 'No members found in this club.' : 'No members matching "$_searchQuery".',
                        style: TextStyle(color: subtitleColor),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => Divider(height: 1, indent: 64, color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                  itemBuilder: (context, index) {
                    final m = filtered[index];
                    final name = m['name'] ?? m['userName'] ?? 'Member';
                    final email = m['email'] ?? m['userEmail'] ?? '';
                    final role = m['role'] ?? 'Member';
                    final isSelected = widget.selectedMemberEmail != null &&
                        widget.selectedMemberEmail!.isNotEmpty &&
                        widget.selectedMemberEmail!.toLowerCase() == email.toString().toLowerCase();

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isDark ? AppTheme.darkElevated : const Color(0xFFE2E8F0),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'M',
                          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(name.toString(), style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('$email  \u00b7  $role', style: TextStyle(color: subtitleColor, fontSize: 12)),
                      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: AppTheme.accent(context)) : null,
                      onTap: () {
                        widget.onMemberSelected(m);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
