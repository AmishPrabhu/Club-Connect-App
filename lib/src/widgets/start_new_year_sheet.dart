import 'package:flutter/material.dart';
import '../models/club.dart';
import '../state/app_state.dart';

class StartNewYearSheet extends StatefulWidget {
  const StartNewYearSheet({
    super.key,
    required this.club,
    required this.appState,
    required this.onSuccess,
  });

  final Club club;
  final AppState appState;
  final ValueChanged<String> onSuccess;

  @override
  State<StartNewYearSheet> createState() => _StartNewYearSheetState();
}

class _StartNewYearSheetState extends State<StartNewYearSheet> {
  int _currentStep = 0;
  bool _isSubmitting = false;
  String? _errorMessage;

  late TextEditingController _newTermController;
  late TextEditingController _presidentEmailController;
  late TextEditingController _secretaryEmailController;
  late TextEditingController _treasurerEmailController;
  late TextEditingController _presidentTitleController;

  @override
  void initState() {
    super.initState();
    // Auto-calculate default next term year (e.g. 2025-2026 -> 2026-2027)
    final currentYear = DateTime.now().year;
    final defaultNextTerm = '$currentYear-${currentYear + 1}';

    _newTermController = TextEditingController(text: defaultNextTerm);
    _presidentEmailController = TextEditingController();
    _secretaryEmailController = TextEditingController();
    _treasurerEmailController = TextEditingController();
    _presidentTitleController = TextEditingController(
      text: widget.club.name.toLowerCase().contains('gdg') ? 'GDG Lead' : 'President',
    );
  }

  @override
  void dispose() {
    _newTermController.dispose();
    _presidentEmailController.dispose();
    _secretaryEmailController.dispose();
    _treasurerEmailController.dispose();
    _presidentTitleController.dispose();
    super.dispose();
  }

  void _nextStep() {
    setState(() => _errorMessage = null);

    if (_currentStep == 0) {
      if (_newTermController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please enter the new academic term (e.g. 2026-2027)');
        return;
      }
    } else if (_currentStep == 1) {
      final email = _presidentEmailController.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        setState(() => _errorMessage = 'Please enter a valid President/Lead email');
        return;
      }
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _errorMessage = null;
        _currentStep--;
      });
    }
  }

  Future<void> _submitHandover() async {
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    try {
      final newTerm = _newTermController.text.trim();
      final presEmail = _presidentEmailController.text.trim();
      final secEmail = _secretaryEmailController.text.trim();
      final treasEmail = _treasurerEmailController.text.trim();
      final presTitle = _presidentTitleController.text.trim();

      await widget.appState.handoverClubTerm(
        clubId: widget.club.id,
        newTermYear: newTerm,
        newPresidentEmail: presEmail,
        newSecretaryEmail: secEmail.isNotEmpty ? secEmail : null,
        newTreasurerEmail: treasEmail.isNotEmpty ? treasEmail : null,
        newPresidentRoleTitle: presTitle.isNotEmpty ? presTitle : null,
      );

      widget.onSuccess('Academic year $newTerm started successfully! Handover complete.');
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Handover failed: ${e.toString().replaceAll('ApiException: ', '')}';
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
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.autorenew_rounded, color: primaryColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start New Academic Year',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Step ${_currentStep + 1} of 3 • ${widget.club.name}',
                        style: TextStyle(fontSize: 13, color: subtextColor),
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
            const SizedBox(height: 20),

            // Progress Bar
            Row(
              children: List.generate(3, (index) {
                final isActive = index <= _currentStep;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                    decoration: BoxDecoration(
                      color: isActive ? primaryColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Error Banner
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade400.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade400, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade300, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Step 1: New Term Year
            if (_currentStep == 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Enter New Academic Session',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This will archive the current board list into read-only history.',
                      style: TextStyle(fontSize: 13, color: subtextColor),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newTermController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Academic Term (e.g. 2026-2027)',
                        hintText: '2026-2027',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Step 2: Nominate New Officers
            if (_currentStep == 1) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2. Assign New Leadership',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Assign the new President / Lead. Full management access will transfer to this email.',
                      style: TextStyle(fontSize: 13, color: subtextColor),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _presidentTitleController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'President / Lead Role Title',
                        hintText: 'President or GDG Lead',
                        prefixIcon: const Icon(Icons.stars_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _presidentEmailController,
                      style: TextStyle(color: textColor),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'New President / Lead Email *',
                        hintText: 'student@walchandsangli.ac.in',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _secretaryEmailController,
                      style: TextStyle(color: textColor),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'New Secretary Email (Optional)',
                        hintText: 'secretary@walchandsangli.ac.in',
                        prefixIcon: const Icon(Icons.description_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _treasurerEmailController,
                      style: TextStyle(color: textColor),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'New Treasurer Email (Optional)',
                        hintText: 'treasurer@walchandsangli.ac.in',
                        prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Step 3: Confirmation Summary
            if (_currentStep == 2) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade600.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber.shade400, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Confirm Academic Year Handover',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Is the current academic session over? Confirming will:',
                      style: TextStyle(fontSize: 13, color: textColor),
                    ),
                    const SizedBox(height: 10),
                    _bulletPoint(context, 'Archive the current board under Past Boards History.'),
                    _bulletPoint(context, 'Transfer active President rights to: ${_presidentEmailController.text.trim()}'),
                    _bulletPoint(context, 'Initialize the ${_newTermController.text.trim()} active board roster.'),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Navigation Buttons
            Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : _prevStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : (_currentStep == 2 ? _submitHandover : _nextStep),
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
                        : Text(_currentStep == 2 ? 'Confirm & Handover' : 'Next Step'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bulletPoint(BuildContext context, String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.blueGrey.shade800;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
