import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post_item.dart';
import '../services/cloudinary_service.dart';
import '../state/app_state.dart';

class CertificateSetupScreen extends StatefulWidget {
  const CertificateSetupScreen({
    super.key,
    required this.event,
    required this.appState,
  });

  final PostItem event;
  final AppState appState;

  @override
  State<CertificateSetupScreen> createState() => _CertificateSetupScreenState();
}

class _CertificateSetupScreenState extends State<CertificateSetupScreen> {
  String? _templateUrl;
  double _xPercent = 50;
  double _yPercent = 50;
  double _fontSize = 48;
  String _colorHex = '#000000';
  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Assuming the API might return certificateTemplate in the post item,
    // though the current PostItem model might not have it yet.
    // If we had it, we would initialize here. For now, we start fresh or allow setting up.
  }

  Future<void> _uploadTemplate() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _isUploading = true);
      final url = await CloudinaryService.uploadImage(File(picked.path));
      setState(() {
        if (url != null) {
          _templateUrl = url;
        }
        _isUploading = false;
      });
      if (url == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload template.')),
        );
      }
    }
  }

  Future<void> _saveTemplate() async {
    if (_templateUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a template first.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.appState.saveCertificateTemplate(
        eventId: widget.event.id,
        templateUrl: _templateUrl!,
        x: _xPercent,
        y: _yPercent,
        fontSize: _fontSize,
        color: _colorHex,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificate template saved!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save template: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    setState(() {
      _xPercent += (details.delta.dx / constraints.maxWidth) * 100;
      _yPercent += (details.delta.dy / constraints.maxHeight) * 100;

      // Clamp between 0 and 100
      _xPercent = _xPercent.clamp(0.0, 100.0);
      _yPercent = _yPercent.clamp(0.0, 100.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Certificate'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload Template',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload an image (PNG/JPG) to use as the certificate background. Then drag the placeholder text to position where the participant\'s name should appear.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isUploading ? null : _uploadTemplate,
                icon: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate),
                label: Text(_templateUrl != null
                    ? 'Change Template'
                    : 'Upload Template'),
              ),
            ),
            if (_templateUrl != null) ...[
              const SizedBox(height: 24),
              Text(
                'Position Name',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Use AspectRatio or specific height, here we'll use a specific height 
                    // and infer width to allow dragging.
                    return AspectRatio(
                      aspectRatio: 1.414, // Typical A4 landscape
                      child: Stack(
                        children: [
                          Image.network(
                            _templateUrl!,
                            width: constraints.maxWidth,
                            fit: BoxFit.contain,
                          ),
                          Positioned(
                            left: (_xPercent / 100) * constraints.maxWidth - 50, // rough center offset
                            top: (_yPercent / 100) * (constraints.maxWidth / 1.414) - 20,
                            child: GestureDetector(
                              onPanUpdate: (details) =>
                                  _onPanUpdate(details, constraints),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.3),
                                  border: Border.all(color: Colors.blue),
                                ),
                                child: Text(
                                  '[Participant Name]',
                                  style: TextStyle(
                                    fontSize: _fontSize * 0.4, // scaled for preview
                                    color: Colors.black, // use colorHex logic later if needed
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Font Size: '),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 12,
                      max: 120,
                      onChanged: (val) => setState(() => _fontSize = val),
                    ),
                  ),
                  Text(_fontSize.toInt().toString()),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveTemplate,
                  child: Text(_isSaving ? 'Saving...' : 'Save Configuration'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
