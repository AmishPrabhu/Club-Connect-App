import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post_item.dart';
import '../state/app_state.dart';
import '../services/cloudinary_service.dart';
import '../theme/app_theme.dart';

class EventParticipantsScreen extends StatefulWidget {
  const EventParticipantsScreen({
    super.key,
    required this.appState,
    required this.event,
  });

  final AppState appState;
  final PostItem event;

  @override
  State<EventParticipantsScreen> createState() => _EventParticipantsScreenState();
}

class _EventParticipantsScreenState extends State<EventParticipantsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _rsvps = [];
  bool _isLoadingRsvps = true;
  int _selectedSession = 1;

  // Certificate settings
  String? _templateUrl;
  double _nameX = 50.0;
  double _nameY = 50.0;
  double _fontSize = 48.0;
  String _fontFamily = 'Arial';
  String _fontColor = '#000000';

  bool _isSavingTemplate = false;
  bool _isGenerating = false;
  int _generationProgress = 0;
  int _generationTotal = 0;
  Size? _templateImageSize; // FI-16: actual pixel dimensions of the loaded template

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Load current template settings if they exist
    if (widget.event.certificateTemplate != null) {
      final template = widget.event.certificateTemplate!;
      _templateUrl = template['templateUrl']?.toString();
      final pos = template['namePosition'] as Map<String, dynamic>?;
      if (pos != null) {
        _nameX = (pos['x'] as num?)?.toDouble() ?? 50.0;
        _nameY = (pos['y'] as num?)?.toDouble() ?? 50.0;
        _fontSize = (pos['fontSize'] as num?)?.toDouble() ?? 48.0;
        _fontFamily = pos['fontFamily']?.toString() ?? 'Arial';
        _fontColor = pos['color']?.toString() ?? '#000000';
      }
    }
    
    _loadRsvps();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRsvps() async {
    setState(() => _isLoadingRsvps = true);
    try {
      final data = await widget.appState.fetchEventRsvps(widget.event.id);
      setState(() {
        _rsvps = data;
        _isLoadingRsvps = false;
      });
    } catch (e) {
      setState(() => _isLoadingRsvps = false);
      _showSnackBar('Failed to load participants: $e', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Future<void> _toggleAttendance(Map<String, dynamic> rsvp, String currentStatus) async {
    final newStatus = currentStatus == 'present' ? 'absent' : 'present';
    final rsvpId = rsvp['_id']?.toString() ?? rsvp['id']?.toString() ?? '';
    
    try {
      await widget.appState.updateRsvpAttendance(
        widget.event.id,
        rsvpId,
        newStatus,
        _selectedSession,
      );
      
      // Update local state
      setState(() {
        final index = _rsvps.indexWhere((r) => (r['_id'] ?? r['id']) == rsvpId);
        if (index != -1) {
          final sessionKey = _selectedSession.toString();
          final attendanceMap = Map<String, dynamic>.from(_rsvps[index]['sessionAttendance'] ?? {});
          attendanceMap[sessionKey] = newStatus;
          _rsvps[index]['sessionAttendance'] = attendanceMap;

          // Check if present across all sessions
          final allValues = attendanceMap.values.toList();
          if (allValues.every((val) => val == 'present')) {
            _rsvps[index]['attendance'] = 'present';
          } else if (allValues.any((val) => val == 'absent')) {
            _rsvps[index]['attendance'] = 'absent';
          } else {
            _rsvps[index]['attendance'] = 'pending';
          }
        }
      });
    } catch (e) {
      _showSnackBar('Failed to update attendance: $e', isError: true);
    }
  }

  Future<void> _addParticipant() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Participant'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 12),
                Text(
                  dialogError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                if (name.isEmpty || email.isEmpty) {
                  setDialogState(() {
                    dialogError = 'Please enter both Name and Email.';
                  });
                  return;
                }
                if (!email.contains('@') || !email.contains('.')) {
                  setDialogState(() {
                    dialogError = 'Please enter a valid Email.';
                  });
                  return;
                }

                try {
                  await widget.appState.addEventParticipant(widget.event.id, name, email);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showSnackBar('Participant added.');
                  _loadRsvps();
                } catch (e) {
                  setDialogState(() {
                    dialogError = 'Failed to add: $e';
                  });
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteParticipant(String rsvpId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Participant'),
        content: const Text('Are you sure you want to remove this participant?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.appState.deleteEventParticipant(widget.event.id, rsvpId);
        _showSnackBar('Participant removed.');
        _loadRsvps();
      } catch (e) {
        _showSnackBar('Failed to remove participant: $e', isError: true);
      }
    }
  }

  Future<void> _pickTemplateImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    _showSnackBar('Uploading template to Cloudinary...');
    final url = await CloudinaryService.uploadImage(File(picked.path));
    if (url != null) {
      setState(() => _templateUrl = url);
      // FI-16: load actual image dimensions for accurate preview positioning
      _getNetworkImageSize(url).then((img) {
        if (mounted) {
          setState(() => _templateImageSize = Size(img.width.toDouble(), img.height.toDouble()));
        }
      });
      _showSnackBar('Template uploaded successfully.');
      _saveTemplateSettings();
    } else {
      _showSnackBar('Failed to upload template.', isError: true);
    }
  }

  Future<void> _saveTemplateSettings() async {
    if (_templateUrl == null) return;
    setState(() => _isSavingTemplate = true);
    try {
      final namePosition = {
        'x': _nameX,
        'y': _nameY,
        'fontSize': _fontSize,
        'fontFamily': _fontFamily,
        'color': _fontColor,
      };
      await widget.appState.saveCertificateTemplate(widget.event.id, _templateUrl!, namePosition);
      _showSnackBar('Certificate template saved.');
    } catch (e) {
      _showSnackBar('Failed to save settings: $e', isError: true);
    } finally {
      setState(() => _isSavingTemplate = false);
    }
  }

  Future<ui.Image> _getNetworkImageSize(String url) {
    final Completer<ui.Image> completer = Completer();
    final ImageStream stream = NetworkImage(url).resolve(ImageConfiguration.empty);
    stream.addListener(ImageStreamListener((ImageInfo info, bool _) {
      if (!completer.isCompleted) {
        completer.complete(info.image);
      }
    }));
    return completer.future;
  }

  Future<void> _generateCertificates() async {
    final presentParticipants = _rsvps.where((r) => r['attendance'] == 'present').toList();
    if (presentParticipants.isEmpty) {
      _showSnackBar('No participants are marked as present.', isError: true);
      return;
    }
    if (_templateUrl == null) {
      _showSnackBar('Please upload a template background image first.', isError: true);
      return;
    }

    setState(() {
      _isGenerating = true;
      _generationTotal = presentParticipants.length;
      _generationProgress = 0;
    });

    try {
      // Resolve image dimensions
      final img = await _getNetworkImageSize(_templateUrl!);
      final imgWidth = img.width;
      final imgHeight = img.height;

      final textCenterX = (_nameX / 100) * imgWidth;
      final textCenterY = (_nameY / 100) * imgHeight;

      final offsetX = (textCenterX - (imgWidth / 2)).round();
      final offsetY = (textCenterY - (imgHeight / 2)).round();

      final uploadIndex = _templateUrl!.indexOf('/upload/');
      if (uploadIndex == -1) {
        throw Exception('Invalid template URL format.');
      }
      final baseUrl = _templateUrl!.substring(0, uploadIndex + 8);
      final restUrl = _templateUrl!.substring(uploadIndex + 8);

      final colorHex = _fontColor.replaceAll('#', '');
      final fontMap = {
        'Arial': 'Arial',
        'Times New Roman': 'Times',
        'Georgia': 'Georgia',
        'Verdana': 'Verdana'
      };
      final resolvedFont = fontMap[_fontFamily] ?? 'Arial';

      int successCount = 0;
      for (int i = 0; i < presentParticipants.length; i++) {
        final p = presentParticipants[i];
        final pName = p['name']?.toString() ?? 'Participant';
        final pId = p['_id']?.toString() ?? p['id']?.toString() ?? '';

        final transformOverlay = 'co_rgb:$colorHex,l_text:${resolvedFont}_${_fontSize.toInt()}_bold:${Uri.encodeComponent(pName)}/fl_layer_apply,g_center,x_$offsetX,y_$offsetY/';
        final dynamicUrl = '$baseUrl$transformOverlay$restUrl';

        if (pId.isNotEmpty) {
          await widget.appState.updateParticipantCertificate(widget.event.id, pId, dynamicUrl);
          successCount++;
        }

        setState(() {
          _generationProgress = i + 1;
        });
      }

      _showSnackBar('Successfully generated $successCount certificates!');
      _loadRsvps();
    } catch (e) {
      _showSnackBar('Generation failed: $e', isError: true);
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Participants'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Colors.white,
        foregroundColor: AppTheme.navyColor(context),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people_outline), text: 'Attendance'),
            Tab(icon: Icon(Icons.badge_outlined), text: 'Certificates'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAttendanceTab(),
          _buildCertificatesTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: _addParticipant,
              backgroundColor: AppTheme.accent(context),
              child: const Icon(Icons.person_add_alt_1_rounded),
            )
          : null,
    );
  }

  Widget _buildAttendanceTab() {
    if (_isLoadingRsvps) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalSessions = widget.event.totalSessions;
    final sessionList = List.generate(totalSessions, (i) => i + 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Session Picker Row
          if (totalSessions > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: sessionList.map((s) {
                  final active = _selectedSession == s;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text('Session $s'),
                      selected: active,
                      selectedColor: AppTheme.accent(context),
                      labelStyle: TextStyle(
                        color: active ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedSession = s);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Expanded(
            child: _rsvps.isEmpty
                ? const Center(
                    child: Text('No participants registered for this event.'),
                  )
                : ListView.separated(
                    itemCount: _rsvps.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final rsvp = _rsvps[index];
                      final sessionKey = _selectedSession.toString();
                      final sessionAttendance = rsvp['sessionAttendance'] as Map<String, dynamic>? ?? {};
                      final status = sessionAttendance[sessionKey]?.toString() ?? 'absent';
                      final isPresent = status == 'present';
                      final rsvpId = rsvp['_id']?.toString() ?? rsvp['id']?.toString() ?? '';

                      return ListTile(
                        title: Text(
                          rsvp['name']?.toString() ?? 'No Name',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(rsvp['email']?.toString() ?? 'No Email'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: () => _toggleAttendance(rsvp, status),
                              icon: Icon(
                                isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                color: isPresent ? Colors.green : Colors.red,
                              ),
                              label: Text(
                                isPresent ? 'Present' : 'Absent',
                                style: TextStyle(
                                  color: isPresent ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
                              onPressed: () => _deleteParticipant(rsvpId),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificatesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview Canvas
          if (_templateUrl != null) ...[
            Text(
              'Certificate Live Preview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navyColor(context)),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // FI-16: use real image aspect ratio; fall back to 0.7 only if dimensions not yet loaded
                  final imgAspect = (_templateImageSize != null && _templateImageSize!.height > 0)
                      ? (_templateImageSize!.width / _templateImageSize!.height)
                      : (1.0 / 0.7); // portrait fallback ~1.43
                  final previewHeight = constraints.maxWidth / imgAspect;

                  return Stack(
                    children: [
                      Image.network(
                        _templateUrl!,
                        fit: BoxFit.contain,
                        width: constraints.maxWidth,
                      ),
                      Positioned(
                        left: constraints.maxWidth * (_nameX / 100),
                        top: previewHeight * (_nameY / 100),
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, -0.5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red, style: BorderStyle.solid, width: 1.5),
                              color: Colors.red.withValues(alpha: 0.15),
                            ),
                            child: Text(
                              '[Participant Name]',
                              style: TextStyle(
                                fontSize: _fontSize * (constraints.maxWidth / 700), // scale dynamically
                                color: Color(int.parse(_fontColor.replaceAll('#', '0xff'))),
                                fontWeight: FontWeight.bold,
                                fontFamily: _fontFamily,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'Red dashed box represents name stamp bounds',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: AppTheme.surfaceBg(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.badge_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text('No template background image uploaded yet.', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _pickTemplateImage,
                      icon: const Icon(Icons.upload_rounded),
                      label: const Text('Upload Template'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_templateUrl != null) ...[
            // Settings controls
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Position & Styling Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ElevatedButton.icon(
                          onPressed: _pickTemplateImage,
                          icon: const Icon(Icons.sync_rounded, size: 16),
                          label: const Text('Replace', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const Divider(),
                    
                    // Name X coordinates
                    Text('Horizontal Position (X: ${_nameX.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12)),
                    Slider(
                      value: _nameX,
                      min: 0,
                      max: 100,
                      onChanged: (val) => setState(() => _nameX = val),
                    ),

                    // Name Y coordinates
                    Text('Vertical Position (Y: ${_nameY.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12)),
                    Slider(
                      value: _nameY,
                      min: 0,
                      max: 100,
                      onChanged: (val) => setState(() => _nameY = val),
                    ),

                    // Font Size
                    Text('Font Size: ${_fontSize.toInt()} px', style: const TextStyle(fontSize: 12)),
                    Slider(
                      value: _fontSize,
                      min: 12,
                      max: 100,
                      onChanged: (val) => setState(() => _fontSize = val),
                    ),

                    // Font Family dropdown
                    const Text('Font Family', style: TextStyle(fontSize: 12)),
                    DropdownButton<String>(
                      value: _fontFamily,
                      isExpanded: true,
                      items: ['Arial', 'Times New Roman', 'Georgia', 'Verdana'].map((f) {
                        return DropdownMenuItem(value: f, child: Text(f));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _fontFamily = val);
                      },
                    ),
                    const SizedBox(height: 8),

                    // Font color options
                    const Text('Font Color', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildColorDot('#000000', 'Black'),
                        const SizedBox(width: 8),
                        _buildColorDot('#002147', 'Navy'),
                        const SizedBox(width: 8),
                        _buildColorDot('#d32f2f', 'Red'),
                        const SizedBox(width: 8),
                        _buildColorDot('#1976d2', 'Blue'),
                        const SizedBox(width: 8),
                        _buildColorDot('#388e3c', 'Green'),
                      ],
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSavingTemplate ? null : _saveTemplateSettings,
                         style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent(context), foregroundColor: Colors.white),
                        child: _isSavingTemplate
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Save Template Configuration'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bulk actions card
            Card(
              elevation: 0,
              color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Batch Certificate Generation',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This will generate Cloudinary stamp templates and update certificates for all participants marked as present.',
                      style: TextStyle(fontSize: 12, color: AppTheme.mutedColor(context)),
                    ),
                    const SizedBox(height: 14),

                    if (_isGenerating) ...[
                      LinearProgressIndicator(
                        value: _generationTotal > 0 ? _generationProgress / _generationTotal : 0,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12,
                        color: AppTheme.textColor(context),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Generating $_generationProgress of $_generationTotal...',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textColor(context)),
                      ),
                      const SizedBox(height: 12),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isGenerating ? null : _generateCertificates,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent(context),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.offline_pin_rounded),
                        label: const Text('Generate & Update Certificates'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColorDot(String hexColor, String name) {
    final isSelected = _fontColor == hexColor;
    return GestureDetector(
      onTap: () => setState(() => _fontColor = hexColor),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? AppTheme.accent(context) : Colors.transparent, width: 2),
        ),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Color(int.parse(hexColor.replaceAll('#', '0xff'))),
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
        ),
      ),
    );
  }
}
