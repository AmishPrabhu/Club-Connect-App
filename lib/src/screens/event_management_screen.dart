import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event details updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
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

    await Share.shareXFiles([XFile(path)], subject: 'Attendance: ${widget.event.title}');
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
                _buildFilesTab(),
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
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BulkImportScreen(club: club, appState: widget.appState),
            ));
          },
          trailing: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildEditTab() {
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
                    setState(() => _date = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}");
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Certificate Design', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        const Text('Upload a template and position the name placeholder.'),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
            if (picked != null) {
              setState(() => _isLoading = true);
              final url = await CloudinaryService.uploadImage(File(picked.path));
              setState(() {
                _templateUrl = url;
                _isLoading = false;
              });
            }
          },
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload Template'),
        ),
        if (_templateUrl != null) ...[
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 1.414,
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
              child: Stack(
                children: [
                  Image.network(_templateUrl!, fit: BoxFit.contain),
                  Positioned(
                    left: (_xPercent / 100) * 300, // Dummy width for preview
                    top: (_yPercent / 100) * 212,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      color: Colors.blue.withOpacity(0.3),
                      child: const Text('Participant Name', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {}, // Save Cert Logic
            child: const Text('Save Certificate Layout'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () {}, // Generate All Logic
            child: const Text('Generate All Certificates'),
          ),
        ],
      ],
    );
  }

  Widget _buildFilesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionCard(
          title: 'Budget Proposal',
          child: Column(
            children: [
              if (widget.event.budgetImageUrl != null)
                Image.network(widget.event.budgetImageUrl!, height: 100),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {}, // Upload Budget
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Budget Screenshot'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionCard(
          title: 'Event Report',
          child: Column(
            children: [
              OutlinedButton.icon(
                onPressed: () {}, // Upload Report
                icon: const Icon(Icons.description_outlined),
                label: const Text('Upload Final Report'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.title, required this.value, required this.icon, this.color});
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
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
