import 'package:flutter/material.dart';
import '../models/post_item.dart';
 import '../state/app_state.dart';
import 'package:csv/csv.dart' as csv;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AttendanceManagementScreen extends StatefulWidget {
  const AttendanceManagementScreen({
    super.key,
    required this.event,
    required this.appState,
  });

  final PostItem event;
  final AppState appState;

  @override
  State<AttendanceManagementScreen> createState() =>
      _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState
    extends State<AttendanceManagementScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _rsvps = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchRsvps();
  }

  Future<void> _fetchRsvps() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final rsvps = await widget.appState.fetchEventRsvps(widget.event.id);
      setState(() {
        _rsvps = rsvps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAttendance(String rsvpId, bool currentStatus) async {
    final newStatus = !currentStatus;
    try {
      // Optimistic update
      setState(() {
        final index = _rsvps.indexWhere((r) => r['_id'] == rsvpId);
        if (index != -1) {
          _rsvps[index]['attended'] = newStatus;
        }
      });
      await widget.appState.updateParticipantAttendance(
        widget.event.id,
        rsvpId,
        newStatus,
      );
    } catch (e) {
      // Revert on error
      setState(() {
        final index = _rsvps.indexWhere((r) => r['_id'] == rsvpId);
        if (index != -1) {
          _rsvps[index]['attended'] = currentStatus;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update attendance: $e')),
        );
      }
    }
  }

  Future<void> _exportAttendance() async {
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

    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/attendance_${widget.event.id}.csv';
      final file = File(path);
      await file.writeAsString(csvData);

      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Attendance for ${widget.event.title}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRsvps = _rsvps.where((r) {
      final name = (r['name'] ?? '').toString().toLowerCase();
      final email = (r['email'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export CSV',
            onPressed: _rsvps.isEmpty ? null : _exportAttendance,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Failed to load RSVPs',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchRsvps,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : filteredRsvps.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isEmpty
                                  ? 'No RSVPs for this event yet.'
                                  : 'No matches found.',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredRsvps.length,
                            itemBuilder: (context, index) {
                              final rsvp = filteredRsvps[index];
                              final isAttended = rsvp['attended'] == true;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isAttended
                                      ? Colors.green.withOpacity(0.2)
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                  child: isAttended
                                      ? const Icon(Icons.check, color: Colors.green)
                                      : Text(
                                          (rsvp['name'] ?? '?')[0].toUpperCase(),
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                ),
                                title: Text(rsvp['name'] ?? 'Unknown'),
                                subtitle: Text(rsvp['email'] ?? ''),
                                trailing: Switch(
                                  value: isAttended,
                                  onChanged: (_) => _toggleAttendance(
                                      rsvp['_id'].toString(), isAttended),
                                ),
                                onTap: () => _toggleAttendance(
                                    rsvp['_id'].toString(), isAttended),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
