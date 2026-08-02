import 'package:flutter/material.dart';
import '../models/club.dart';
import '../state/app_state.dart';

class PromoteMembersSheet extends StatefulWidget {
  const PromoteMembersSheet({
    super.key,
    required this.club,
    required this.appState,
    required this.previousMembers,
    required this.onSuccess,
  });

  final Club club;
  final AppState appState;
  final List<Map<String, dynamic>> previousMembers;
  final ValueChanged<String> onSuccess;

  @override
  State<PromoteMembersSheet> createState() => _PromoteMembersSheetState();
}

class _PromoteMembersSheetState extends State<PromoteMembersSheet> {
  final Map<String, bool> _selectedMembers = {};
  final Map<String, String> _assignedRoles = {};
  final Map<String, String> _assignedBoards = {};
  final Map<String, String> _assignedYears = {};

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    for (final m in widget.previousMembers) {
      final email = m['email']?.toString() ?? '';
      if (email.isEmpty) continue;
      _selectedMembers[email] = true;

      // Auto promote academic year (FY -> SY, SY -> TY, etc.)
      final currentYear = m['academicYear']?.toString() ?? '';
      String nextYear = 'TY';
      if (currentYear == 'FY') nextYear = 'SY';
      else if (currentYear == 'SY') nextYear = 'TY';
      else if (currentYear == 'TY') nextYear = 'Final Year';

      // Auto promote board type
      String nextBoard = 'executive';
      if (nextYear == 'TY' || nextYear == 'Final Year') nextBoard = 'main';

      _assignedRoles[email] = m['role']?.toString() ?? 'Executive Officer';
      _assignedBoards[email] = m['boardType']?.toString() ?? nextBoard;
      _assignedYears[email] = nextYear;
    }
  }

  Future<void> _submitPromotions() async {
    final toPromote = <Map<String, dynamic>>[];

    for (final m in widget.previousMembers) {
      final email = m['email']?.toString() ?? '';
      if (email.isEmpty || _selectedMembers[email] != true) continue;

      toPromote.add({
        'email': email,
        'name': m['name']?.toString() ?? 'Member',
        'newRole': _assignedRoles[email] ?? 'Member',
        'newBoardType': _assignedBoards[email] ?? 'executive',
        'newAcademicYear': _assignedYears[email] ?? 'TY',
      });
    }

    if (toPromote.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one member to promote.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    try {
      await widget.appState.promoteClubMembers(
        clubId: widget.club.id,
        members: toPromote,
      );

      widget.onSuccess('Successfully imported and promoted ${toPromote.length} members!');
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Failed to promote members: ${e.toString().replaceAll('ApiException: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    final backgroundColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.grey.shade50;
    final textColor = isDark ? Colors.white : Colors.blueGrey.shade900;
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.group_add_outlined, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Promote / Import Members',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Import members from previous board & assign new roles',
                      style: TextStyle(fontSize: 12, color: subtextColor),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: subtextColor),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade400.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade400, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade300, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Member list
          Expanded(
            child: widget.previousMembers.isEmpty
                ? Center(
                    child: Text(
                      'No members found from previous term to import.',
                      style: TextStyle(color: subtextColor),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.previousMembers.length,
                    itemBuilder: (context, index) {
                      final m = widget.previousMembers[index];
                      final email = m['email']?.toString() ?? '';
                      final name = m['name']?.toString() ?? 'Member';
                      final isSelected = _selectedMembers[email] ?? false;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected
                                ? primaryColor.withValues(alpha: 0.5)
                                : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                value: isSelected,
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                subtitle: Text(email, style: TextStyle(color: subtextColor, fontSize: 12)),
                                activeColor: primaryColor,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (val) {
                                  setState(() {
                                    _selectedMembers[email] = val ?? false;
                                  });
                                },
                              ),
                              if (isSelected) ...[
                                const Divider(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: _assignedRoles[email],
                                        style: TextStyle(color: textColor, fontSize: 13),
                                        decoration: const InputDecoration(
                                          labelText: 'New Role Title',
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        ),
                                        onChanged: (val) => _assignedRoles[email] = val.trim(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: _assignedBoards[email],
                                        style: TextStyle(color: textColor, fontSize: 13),
                                        decoration: const InputDecoration(
                                          labelText: 'Board Tier',
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 'main', child: Text('Main (TY)')),
                                          DropdownMenuItem(value: 'executive', child: Text('Exec (SY)')),
                                          DropdownMenuItem(value: 'member', child: Text('Member (FY)')),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => _assignedBoards[email] = val);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitPromotions,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text('Import Selected Members'),
            ),
          ),
        ],
      ),
    );
  }
}
