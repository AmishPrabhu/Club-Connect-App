import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class MemberFormSheet extends StatefulWidget {
  const MemberFormSheet({
    super.key,
    required this.appState,
    required this.clubId,
    this.member,
    required this.onSuccess,
  });

  final AppState appState;
  final String clubId;
  final Map<String, dynamic>? member;
  final void Function(String message) onSuccess;

  @override
  State<MemberFormSheet> createState() => _MemberFormSheetState();
}

class _MemberFormSheetState extends State<MemberFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _roleController;
  late final TextEditingController _yearController;
  
  late String _boardType;
  late String _academicYear;
  
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final member = widget.member;
    final isEditing = member != null;

    _nameController = TextEditingController(text: member?['name']?.toString() ?? '');
    _emailController = TextEditingController(text: member?['email']?.toString() ?? '');
    _roleController = TextEditingController(
      text: member?['role']?.toString() ?? (isEditing ? '' : 'Member'),
    );

    _boardType = member?['boardType']?.toString() ?? 'member';
    _academicYear = member?['academicYear']?.toString() ?? 'FY';

    // Retrieve year from joinedAt, default to current year
    String initialYear = DateTime.now().year.toString();
    if (isEditing && member['joinedAt'] != null) {
      final joinedDate = DateTime.tryParse(member['joinedAt'].toString());
      if (joinedDate != null) {
        initialYear = joinedDate.year.toString();
      }
    }
    _yearController = TextEditingController(text: initialYear);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _roleController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final role = _roleController.text.trim();
    final yearText = _yearController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Name cannot be empty.');
      return;
    }
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Email cannot be empty.');
      return;
    }
    if (!email.toLowerCase().endsWith('@walchandsangli.ac.in')) {
      setState(() => _errorMessage = 'Email must end with @walchandsangli.ac.in');
      return;
    }

    final yearVal = int.tryParse(yearText);
    if (yearVal == null || yearVal < 2000 || yearVal > 2100) {
      setState(() => _errorMessage = 'Please enter a valid 4-digit year (e.g. 2026).');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    try {
      final isEditing = widget.member != null;
      // Construct joinedAt date from the specified year
      final joinedDate = DateTime(yearVal, DateTime.now().month, DateTime.now().day);

      if (isEditing) {
        final mId = widget.member!['_id']?.toString() ?? widget.member!['id']?.toString() ?? '';
        await widget.appState.updateClubMember(widget.clubId, mId, {
          'name': name,
          'email': email,
          'role': _boardType == 'member' ? 'Member' : (role.isEmpty ? 'Member' : role),
          'boardType': _boardType,
          'academicYear': _academicYear,
          'joinedAt': joinedDate.toIso8601String(),
        });
        widget.onSuccess('Member "$name" updated successfully!');
      } else {
        await widget.appState.addClubMember(
          widget.clubId,
          name: name,
          email: email,
          role: _boardType == 'member' ? 'Member' : (role.isEmpty ? 'Member' : role),
          boardType: _boardType,
          academicYear: _academicYear,
          joinedAt: joinedDate,
        );
        widget.onSuccess('Member "$name" added successfully!');
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save member: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final mq = MediaQuery.of(context);
    final isEditing = widget.member != null;

    final titleColor = AppTheme.textColor(context);
    final subtitleColor = isDark ? AppTheme.darkMuted : AppTheme.mutedColor(context);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;

    return Container(
      height: mq.size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : const Color(0xFFF6F8FB),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header Widget mirroring _CreatePostSheet
          Container(
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
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Edit Member' : 'Add New Member',
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEditing ? 'Update member details' : 'Add a new member to the club roster',
                              style: TextStyle(color: subtitleColor, fontSize: 12),
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
              ],
            ),
          ),
          
          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + mq.viewInsets.bottom),
              child: Card(
                color: cardBg,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.blueGrey.withValues(alpha: 0.08),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: titleColor),
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          hintText: 'Enter full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: titleColor),
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'email@walchandsangli.ac.in',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Board Type
                      DropdownButtonFormField<String>(
                        value: _boardType,
                        dropdownColor: cardBg,
                        style: TextStyle(color: titleColor),
                        decoration: const InputDecoration(
                          labelText: 'Board Type',
                          prefixIcon: Icon(Icons.dashboard_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'main', child: Text('Main Board (TY)')),
                          DropdownMenuItem(value: 'executive', child: Text('Executive Board (SY)')),
                          DropdownMenuItem(value: 'member', child: Text('Member Board (FY)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _boardType = val;
                              if (val == 'member') {
                                _roleController.text = 'Member';
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Custom Role (only if not member)
                      if (_boardType != 'member') ...[
                        TextFormField(
                          controller: _roleController,
                          style: TextStyle(color: titleColor),
                          decoration: const InputDecoration(
                            labelText: 'Custom Role',
                            hintText: 'e.g. Coordinator, Treasurer',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Academic Year
                      DropdownButtonFormField<String>(
                        value: _academicYear,
                        dropdownColor: cardBg,
                        style: TextStyle(color: titleColor),
                        decoration: const InputDecoration(
                          labelText: 'Academic Year',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'FY', child: Text('FY')),
                          DropdownMenuItem(value: 'SY', child: Text('SY')),
                          DropdownMenuItem(value: 'TY', child: Text('TY')),
                          DropdownMenuItem(value: 'Final Year', child: Text('Final Year')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _academicYear = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Joining Year
                      TextFormField(
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: titleColor),
                        decoration: const InputDecoration(
                          labelText: 'Joining Year',
                          hintText: 'e.g. 2024',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Sticky Footer Action
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.blueGrey.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent(context),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isEditing ? 'Save Changes' : 'Add Member'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
