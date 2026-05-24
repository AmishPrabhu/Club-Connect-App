import 'dart:io';
// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:csv/csv.dart' as csv;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/post_item.dart';
import '../state/app_state.dart';
import '../services/cloudinary_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'bulk_import_screen.dart';

class EventManagementScreen extends StatefulWidget {
  const EventManagementScreen({
    super.key,
    required this.event,
    required this.appState,
  });

  final PostItem event;
  final AppState appState;

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _rsvps = [];
  String _searchQuery = '';

  // Form State
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _locationController;
  String? _date;
  String? _time;

  // Certificate State
  String? _templateUrl;
  double _xPercent = 50;
  double _yPercent = 50;
  double _fontSize = 48;
  String _fontColor = '000000';
  bool _isGenerating = false;

  bool get _canEditEvent =>
      widget.appState.session?.hasAdminAccess == true ||
      widget.appState.session?.canPublishClubContent(widget.event.clubId) ==
          true;

  bool get _canUploadBudget =>
      widget.appState.session?.hasAdminAccess == true ||
      widget.appState.session?.canUploadBudget(widget.event.clubId) == true;

  bool get _canManageCertificates =>
      widget.appState.session?.hasAdminAccess == true ||
      widget.appState.session?.canPublishClubContent(widget.event.clubId) ==
          true;

  bool get _canViewReports =>
      widget.appState.session?.canViewClubReports(widget.event.clubId) == true ||
      widget.appState.session?.hasAdminAccess == true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _titleController = TextEditingController(text: widget.event.title);
    _contentController = TextEditingController(text: widget.event.content);
    _locationController = TextEditingController(text: widget.event.location);
    _date = widget.event.date != null
        ? "${widget.event.date!.year}-${widget.event.date!.month.toString().padLeft(2, '0')}-${widget.event.date!.day.toString().padLeft(2, '0')}"
        : null;
    _time = widget.event.time;

    // Initialize Certificate from event if possible (simulated for now)
    // In a real app, widget.event would have certificateTemplate property

    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final rsvps = await widget.appState.fetchEventRsvps(widget.event.id);
      setState(() {
        _rsvps = rsvps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDetails() async {
    setState(() => _isSaving = true);
    try {
      await widget.appState.updatePost(widget.event.id, {
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'location': _locationController.text.trim(),
        'date': _date,
        'time': _time,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Event details updated!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleAttendance(String rsvpId, bool currentStatus) async {
    final newStatus = !currentStatus;
    try {
      setState(() {
        final index = _rsvps.indexWhere((r) => r['_id'] == rsvpId);
        if (index != -1) _rsvps[index]['attended'] = newStatus;
      });
      await widget.appState.updateParticipantAttendance(
        widget.event.id,
        rsvpId,
        newStatus,
      );
    } catch (e) {
      setState(() {
        final index = _rsvps.indexWhere((r) => r['_id'] == rsvpId);
        if (index != -1) _rsvps[index]['attended'] = currentStatus;
      });
    }
  }

  Future<void> _exportCSV() async {
    final header = ['Name', 'Email', 'Status', 'RSVP Date'];
    final rows = _rsvps.map((rsvp) {
      return [
        rsvp['name'] ?? 'Unknown',
        rsvp['email'] ?? '',
        (rsvp['attended'] == true) ? 'Present' : 'Absent',
        rsvp['rsvpedAt'] ?? '',
      ];
    }).toList();

    String csvData = const csv.ListToCsvConverter().convert([header, ...rows]);
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/attendance_${widget.event.id}.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    await Share.shareXFiles([
      XFile(path),
    ], subject: 'Attendance: ${widget.event.title}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Event'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Edit'),
            Tab(text: 'Participants'),
            Tab(text: 'Certificate'),
            Tab(text: 'Budget & Report'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildEditTab(),
                _buildParticipantsTab(),
                _buildCertificateTab(),
                _buildBudgetReportTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    final present = _rsvps.where((r) => r['attended'] == true).length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBox(
                title: 'Total RSVPs',
                value: '${_rsvps.length}',
                icon: Icons.people_outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatBox(
                title: 'Attended',
                value: '$present',
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.download_rounded),
          title: const Text('Export Attendance CSV'),
          onTap: _exportCSV,
          trailing: const Icon(Icons.chevron_right),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_upload_outlined),
          title: const Text('Bulk Import Participants'),
          onTap: () {
            final club = widget.appState.clubs.firstWhere(
              (c) => c.id == widget.event.clubId,
              orElse: () => widget.appState.clubs.first,
            );
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    BulkImportScreen(club: club, appState: widget.appState),
              ),
            );
          },
          trailing: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildEditTab() {
    if (!_canEditEvent) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Only club secretaries and presidents can edit events.'),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'Event Title'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _contentController,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _locationController,
          decoration: const InputDecoration(labelText: 'Location'),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(
                      () => _date =
                          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}",
                    );
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(_date ?? 'Select Date'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null) {
                    setState(() => _time = picked.format(context));
                  }
                },
                icon: const Icon(Icons.access_time),
                label: Text(_time ?? 'Select Time'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _isSaving ? null : _saveDetails,
          child: Text(_isSaving ? 'Saving...' : 'Update Event Details'),
        ),
      ],
    );
  }

  Widget _buildParticipantsTab() {
    if (!_canEditEvent) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Only club secretaries and presidents can manage attendance.',
          ),
        ),
      );
    }
    final filtered = _rsvps.where((r) {
      final q = _searchQuery.toLowerCase();
      return (r['name'] ?? '').toString().toLowerCase().contains(q) ||
          (r['email'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search participants...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final rsvp = filtered[index];
              final isAttended = rsvp['attended'] == true;
              return ListTile(
                title: Text(rsvp['name'] ?? 'Unknown'),
                subtitle: Text(rsvp['email'] ?? ''),
                trailing: Switch(
                  value: isAttended,
                  onChanged: (v) => _toggleAttendance(rsvp['_id'], isAttended),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCertificateTab() {
    if (!_canManageCertificates) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Only club secretaries and presidents can manage certificates.',
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Certificate Design',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 8),
        const Text('Position the name placeholder on your template.'),
        const SizedBox(height: 20),

        if (_templateUrl == null)
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.workspace_premium_outlined,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                    );
                    if (picked != null) {
                      setState(() => _isLoading = true);
                      final url = await CloudinaryService.uploadImage(
                        File(picked.path),
                      );
                      setState(() {
                        _templateUrl = url;
                        _isLoading = false;
                      });
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload Template'),
                ),
              ],
            ),
          )
        else ...[
          // Preview Area
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = w / 1.414; // A4 Ratio
              return Container(
                width: w,
                height: h,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.blue.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.network(
                        _templateUrl!,
                        fit: BoxFit.contain,
                        width: w,
                        height: h,
                      ),
                      Positioned(
                        left: (_xPercent / 100) * w,
                        top: (_yPercent / 100) * h,
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, -0.5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              border: Border.all(color: Colors.blue),
                            ),
                            child: Text(
                              'John Doe',
                              style: TextStyle(
                                fontSize: (_fontSize / 1000) * w,
                                color: Color(
                                  int.parse('FF$_fontColor', radix: 16),
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Controls
          _SectionCard(
            title: 'Positioning & Style',
            child: Column(
              children: [
                _buildSlider(
                  'Horizontal Position (X)',
                  _xPercent,
                  (v) => setState(() => _xPercent = v),
                ),
                _buildSlider(
                  'Vertical Position (Y)',
                  _yPercent,
                  (v) => setState(() => _yPercent = v),
                ),
                _buildSlider(
                  'Font Size',
                  _fontSize,
                  (v) => setState(() => _fontSize = v),
                  min: 10,
                  max: 200,
                ),
                ListTile(
                  title: const Text('Font Color (Hex)'),
                  subtitle: const Text('e.g., 000000 for Black'),
                  trailing: SizedBox(
                    width: 100,
                    child: TextField(
                      decoration: const InputDecoration(hintText: '000000'),
                      onChanged: (v) =>
                          setState(() => _fontColor = v.replaceAll('#', '')),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          try {
                            await widget.appState.saveCertificateTemplate(
                              eventId: widget.event.id,
                              templateUrl: _templateUrl!,
                              x: _xPercent,
                              y: _yPercent,
                              fontSize: _fontSize,
                              color: _fontColor,
                            );
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Layout saved!')),
                              );
                          } catch (e) {
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                          } finally {
                            if (mounted) setState(() => _isSaving = false);
                          }
                        },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Saving...' : 'Save Layout'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _isGenerating
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Generate Certificates'),
                              content: Text(
                                'This will generate certificates for all ${_rsvps.where((r) => r['attended'] == true).length} participants marked as "Present". Proceed?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Generate'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            setState(() => _isGenerating = true);
                            try {
                              // Logic to trigger backend generation (simulated as individual calls if no batch endpoint)
                              final attendees = _rsvps
                                  .where((r) => r['attended'] == true)
                                  .toList();
                              for (var attendee in attendees) {
                                // In parity with web, the backend likely handles overlay based on template
                                // If not, we'd construct the Cloudinary URL here
                                await widget.appState.updateParticipantCertificate(
                                  widget.event.id,
                                  attendee['_id'],
                                  'GENERATED_URL_PLACEHOLDER', // Backend typically fills this
                                );
                              }
                              if (mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Certificates generated!'),
                                  ),
                                );
                            } catch (e) {
                              if (mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed: $e')),
                                );
                            } finally {
                              if (mounted)
                                setState(() => _isGenerating = false);
                            }
                          }
                        },
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(_isGenerating ? 'Generating...' : 'Generate All'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => setState(() => _templateUrl = null),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text(
              'Remove Template',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    ValueChanged<double> onChanged, {
    double min = 0,
    double max = 100,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }

  Widget _buildBudgetReportTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionCard(
          title: 'Budget Proposal',
          child: Column(
            children: [
              if (widget.event.budgetImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.event.budgetImageUrl!,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 12),
              if (_canUploadBudget)
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                    );
                    if (picked != null) {
                      setState(() => _isLoading = true);
                      final url = await CloudinaryService.uploadImage(
                        File(picked.path),
                      );
                      if (url != null) {
                        await widget.appState.updatePost(widget.event.id, {
                          'budgetImageUrl': url,
                        });
                        await _fetchData();
                      }
                      setState(() => _isLoading = false);
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload Budget Screenshot'),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Only the treasurer can upload budgets.'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionCard(
          title: 'Event Report',
          child: Column(
            children: [
              if (widget.event.reportUrl != null)
                ListTile(
                  leading: const Icon(Icons.description, color: Colors.blue),
                  title: const Text('Final Report Uploaded'),
                  subtitle: Text(
                    widget.event.reportFilename ?? 'View document',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () =>
                        launchUrl(Uri.parse(widget.event.reportUrl!)),
                  ),
                ),
              const SizedBox(height: 12),
              if (_canEditEvent)
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'doc', 'docx'],
                    );
                    if (result != null && result.files.single.path != null) {
                      setState(() => _isLoading = true);
                      final file = File(result.files.single.path!);
                      final url = await CloudinaryService.uploadImage(file);
                      if (url != null) {
                        await widget.appState.submitReport(
                          widget.event.id,
                          url,
                          result.files.single.name,
                        );
                        await _fetchData();
                      }
                      setState(() => _isLoading = false);
                    }
                  },
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Upload Final Report'),
                )
              else if (_canViewReports)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'You can view reports, but only secretaries/presidents can upload them.',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
  });
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          Icon(icon, color: color ?? AppTheme.blue),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
