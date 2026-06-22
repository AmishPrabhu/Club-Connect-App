// ignore_for_file: use_build_context_synchronously
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/club.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({
    super.key,
    required this.club,
    required this.appState,
  });

  final Club club;
  final AppState appState;

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  List<_MemberRow> _rows = [];
  bool _isImporting = false;
  bool _importDone = false;
  int _successCount = 0;
  int _failCount = 0;
  String? _fileName;
  String? _parseError;

  static const _roleOptions = [
    'member',
    'secretary',
    'president',
    'treasurer',
  ];
  static const _boardOptions = ['main', 'executive', 'sub'];

  Future<void> _pickFile() async {
    setState(() {
      _rows = [];
      _parseError = null;
      _importDone = false;
      _fileName = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      _fileName = file.name;

      String content;
      if (file.bytes != null) {
        content = String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        setState(() => _parseError = 'Unable to read file.');
        return;
      }

      _parseCSV(content);
    } catch (e) {
      setState(() => _parseError = 'Error reading file: $e');
    }
  }

  void _parseCSV(String content) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      setState(() => _parseError = 'File is empty.');
      return;
    }

    // Skip header if it looks like one
    final start = lines[0].toLowerCase().contains('name') ? 1 : 0;
    final rows = <_MemberRow>[];

    for (int i = start; i < lines.length; i++) {
      final cols = lines[i].split(',').map((c) => c.trim()).toList();
      if (cols.isEmpty || cols[0].isEmpty) continue;

      rows.add(
        _MemberRow(
          name: cols.isNotEmpty ? cols[0] : '',
          email: cols.length > 1 ? cols[1] : '',
          role: cols.length > 2 && _roleOptions.contains(cols[2].toLowerCase())
              ? cols[2].toLowerCase()
              : 'member',
          boardType: cols.length > 3 && _boardOptions.contains(cols[3].toLowerCase())
              ? cols[3].toLowerCase()
              : 'sub',
          academicYear: cols.length > 4 ? cols[4] : '',
        ),
      );
    }

    if (rows.isEmpty) {
      setState(() => _parseError = 'No valid rows found in the file.');
      return;
    }

    setState(() {
      _rows = rows;
      _parseError = null;
    });
  }

  Future<void> _importAll() async {
    if (_rows.isEmpty) return;

    setState(() {
      _isImporting = true;
      _successCount = 0;
      _failCount = 0;
    });

    for (final row in _rows) {
      try {
        await widget.appState.addClubMember(
          widget.club.id,
          name: row.name,
          email: row.email,
          role: row.role,
          boardType: row.boardType,
          academicYear: row.academicYear,
          joinedAt: DateTime.now(),
        );
        setState(() => _successCount++);
      } catch (_) {
        setState(() => _failCount++);
      }
    }

    setState(() {
      _isImporting = false;
      _importDone = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_successCount imported, $_failCount failed.',
          ),
          backgroundColor: _failCount == 0 ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bulk Import — ${widget.club.name}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Import Members from CSV',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload a CSV file with columns:\nName, Email, Role, BoardType, AcademicYear\n\nRole options: member, secretary, president, treasurer\nBoardType options: main, executive, sub',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isImporting ? null : _pickFile,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(
                      _fileName != null ? _fileName! : 'Choose CSV File',
                    ),
                  ),
                ),
                if (_parseError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _parseError!,
                    style: const TextStyle(color: Color(0xFFB91C1C)),
                  ),
                ],
              ],
            ),
          ),
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 20),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_rows.length} Members Found',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppTheme.navy),
                      ),
                      if (!_importDone)
                        FilledButton.icon(
                          onPressed: _isImporting ? null : _importAll,
                          icon: _isImporting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.cloud_upload_rounded),
                          label: Text(
                            _isImporting ? 'Importing...' : 'Import All',
                          ),
                        ),
                    ],
                  ),
                  if (_isImporting) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Imported: $_successCount | Failed: $_failCount',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                  if (_importDone) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Import complete — $_successCount added, $_failCount failed.',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(),
                  ...(_rows.take(30).map((row) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.navy.withValues(alpha: 0.08),
                          child: Text(
                            row.name.isNotEmpty ? row.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppTheme.navy,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(row.name),
                        subtitle: Text(row.email),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _RoleBadge(role: row.role),
                            Text(
                              row.boardType,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ))),
                  if (_rows.length > 30)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '… and ${_rows.length - 30} more rows',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberRow {
  const _MemberRow({
    required this.name,
    required this.email,
    required this.role,
    required this.boardType,
    required this.academicYear,
  });

  final String name;
  final String email;
  final String role;
  final String boardType;
  final String academicYear;
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.blue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        role,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.blue,
        ),
      ),
    );
  }
}
