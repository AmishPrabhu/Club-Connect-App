import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models/club.dart';
import '../state/app_state.dart';

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
  File? _selectedFile;
  bool _isImporting = false;
  Map<String, dynamic>? _importResult;
  String? _error;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _error = null;
        _importResult = null;
      });
    }
  }

  Future<void> _performImport() async {
    if (_selectedFile == null) return;

    setState(() {
      _isImporting = true;
      _error = null;
      _importResult = null;
    });

    try {
      final result = await widget.appState.bulkImportMembers(
        widget.club.id,
        _selectedFile!.path,
      );
      setState(() {
        _importResult = result;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Import Members'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Club Members',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload a CSV or Excel file containing the members you want to add to the club. '
              'The file must include headers for "Name", "Email", and "Role". '
              'Optional headers: "Board Type", "Academic Year", "Year Joined".',
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surface,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.upload_file,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFile != null
                        ? _selectedFile!.path.split('/').last
                        : 'No file selected',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _isImporting ? null : _pickFile,
                    child: const Text('Select File'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _selectedFile == null || _isImporting
                    ? null
                    : _performImport,
                icon: _isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_isImporting ? 'Importing...' : 'Start Import'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            if (_importResult != null) ...[
              const SizedBox(height: 24),
              Text(
                'Import Summary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SummaryRow(
                        label: 'Total Processed',
                        value: _importResult!['summary']['total'].toString(),
                      ),
                      const Divider(),
                      _SummaryRow(
                        label: 'Successfully Added',
                        value: _importResult!['summary']['added'].toString(),
                        color: Colors.green,
                      ),
                      const Divider(),
                      _SummaryRow(
                        label: 'Updated',
                        value: _importResult!['summary']['updated'].toString(),
                        color: Colors.blue,
                      ),
                      const Divider(),
                      _SummaryRow(
                        label: 'Failed',
                        value: _importResult!['summary']['failed'].toString(),
                        color: Colors.red,
                      ),
                      const Divider(),
                      _SummaryRow(
                        label: 'Emails Sent',
                        value:
                            _importResult!['summary']['emailsSent'].toString(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
