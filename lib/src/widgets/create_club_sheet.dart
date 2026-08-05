import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../services/cloudinary_service.dart';

class CreateClubSheet extends StatefulWidget {
  const CreateClubSheet({
    super.key,
    required this.appState,
    required this.onSuccess,
  });

  final AppState appState;
  final void Function(String message) onSuccess;

  @override
  State<CreateClubSheet> createState() => _CreateClubSheetState();
}

class _CreateClubSheetState extends State<CreateClubSheet> {
  int _step = 0;
  final _pageController = PageController();

  // Step 1 Controllers
  final _nameController = TextEditingController();
  final _fullFormController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'technical';

  // Step 2 Controllers
  String? _uploadedImageUrl;
  bool _isUploadingLogo = false;
  final _selectedDepartments = <String>{};

  bool _isSubmitting = false;
  String? _errorMessage;

  static const _departmentsList = [
    'Computer Science(CSE)',
    'Electronics',
    'Mechanical',
    'Civil',
    'Artificial Intelligence and Machine Learning(AIML)',
    'Information Technology(IT)',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _fullFormController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _nextStep() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Club Name is required.');
      return;
    }
    setState(() {
      _errorMessage = null;
      _step = 1;
    });
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  void _prevStep() {
    setState(() {
      _errorMessage = null;
      _step = 0;
    });
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _pickLogo() async {
    if (_isUploadingLogo) return;
    
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _isUploadingLogo = true;
      _errorMessage = null;
    });

    try {
      final url = await CloudinaryService.uploadImage(File(picked.path));
      if (mounted) {
        setState(() {
          _uploadedImageUrl = url;
          _isUploadingLogo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Logo upload failed: $e';
          _isUploadingLogo = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Club Name is required.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    try {
      await widget.appState.createClub(
        name: name,
        description: _descriptionController.text.trim(),
        fullForm: _fullFormController.text.trim(),
        category: _category,
        image: _uploadedImageUrl ?? '',
        departments: _selectedDepartments.toList(),
      );
      widget.onSuccess('Club "$name" created successfully!');
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create club: $e';
        _isSubmitting = false;
      });
    }
  }

  Widget _buildStep1(Color titleColor, Color cardBg) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppTheme.isDark(context) ? Colors.white.withValues(alpha: 0.05) : Colors.blueGrey.withValues(alpha: 0.08),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Club Name
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: titleColor),
                decoration: const InputDecoration(
                  labelText: 'Club Name',
                  hintText: 'e.g. GDG, PACE, MLSC',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Full Form
              TextFormField(
                controller: _fullFormController,
                style: TextStyle(color: titleColor),
                decoration: const InputDecoration(
                  labelText: 'Full Form',
                  hintText: 'e.g. Google Developers Group',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                style: TextStyle(color: titleColor),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter a short description about the club...',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.info_outline),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<String>(
                initialValue: _category,
                dropdownColor: cardBg,
                style: TextStyle(color: titleColor),
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'technical', child: Text('Technical')),
                  DropdownMenuItem(value: 'academic', child: Text('Academic')),
                  DropdownMenuItem(value: 'cultural', child: Text('Cultural')),
                  DropdownMenuItem(value: 'sports', child: Text('Sports')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _category = val);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep2(Color titleColor, Color cardBg) {
    final isDark = AppTheme.isDark(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
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
              // Logo Header
              Text(
                'Branding & Logo',
                style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Logo Box
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkElevated : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                      image: _uploadedImageUrl != null
                          ? DecorationImage(image: NetworkImage(_uploadedImageUrl!), fit: BoxFit.contain)
                          : null,
                    ),
                    child: _uploadedImageUrl == null
                        ? Icon(Icons.image_outlined, size: 28, color: Colors.grey[400])
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickLogo,
                      icon: _isUploadingLogo
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_rounded),
                      label: Text(_isUploadingLogo ? 'Uploading...' : 'Choose Logo Image'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Departments Header
              Text(
                'Target Departments',
                style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Departments check list
              ..._departmentsList.map((dept) {
                final isSelected = _selectedDepartments.contains(dept);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isSelected,
                  title: Text(dept, style: TextStyle(color: titleColor, fontSize: 14)),
                  controlAffinity: ListTileControlAffinity.trailing,
                  activeColor: AppTheme.accent(context),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedDepartments.add(dept);
                      } else {
                        _selectedDepartments.remove(dept);
                      }
                    });
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final mq = MediaQuery.of(context);
    final titleColor = AppTheme.textColor(context);
    final subtitleColor = isDark ? AppTheme.darkMuted : AppTheme.mutedColor(context);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;

    return Container(
      height: mq.size.height * 0.85,
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : const Color(0xFFF6F8FB),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle & Header
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
                              'Create Club',
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Step ${_step + 1} of 2  \u00b7  ${_step == 0 ? "General Details" : "Branding & Departments"}',
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
              ],
            ),
          ),

          // Step Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: (_step + 1) / 2),
              duration: const Duration(milliseconds: 300),
              builder: (_, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 4,
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.blueGrey.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent(context)),
                ),
              ),
            ),
          ),

          // Page Body
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(titleColor, cardBg),
                _buildStep2(titleColor, cardBg),
              ],
            ),
          ),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
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
            ),

          // Footer Action Buttons
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
                if (_step == 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
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
                      onPressed: _nextStep,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accent(context),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Next'),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : _prevStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Back'),
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
                          : const Text('Create Club'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
