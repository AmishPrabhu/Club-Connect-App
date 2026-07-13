import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class CreateNotificationSheet extends StatefulWidget {
  const CreateNotificationSheet({
    super.key,
    required this.appState,
    required this.initialType,
    this.clubId,
    required this.onSuccess,
  });

  final AppState appState;
  final String initialType;
  final String? clubId;
  final void Function(String message) onSuccess;

  @override
  State<CreateNotificationSheet> createState() => _CreateNotificationSheetState();
}

class _CreateNotificationSheetState extends State<CreateNotificationSheet> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  late String _type;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _insertText(String template) {
    final controller = _messageController;
    final text = controller.text;
    final selection = controller.selection;

    int start = selection.start;
    int end = selection.end;

    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    final selectedText = text.substring(start, end);
    final newText = text.replaceRange(start, end, template.replaceAll('text', selectedText));

    setState(() {
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: start + template.indexOf('text') + selectedText.length,
        ),
      );
    });
  }

  Widget _buildMarkdownToolbar() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildToolbarBtn('B', () => _insertText('**text**')),
          const SizedBox(width: 8),
          _buildToolbarBtn('I', () => _insertText('_text_')),
          const SizedBox(width: 8),
          _buildToolbarBtn('H1', () => _insertText('# text')),
          const SizedBox(width: 8),
          _buildToolbarBtn('List', () => _insertText('- text')),
        ],
      ),
    );
  }

  Widget _buildToolbarBtn(String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppTheme.accent(context),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty) {
      setState(() => _errorMessage = 'Title is required');
      return;
    }
    if (message.isEmpty) {
      setState(() => _errorMessage = 'Message is required');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    try {
      await widget.appState.createNotification(
        title: title,
        message: message,
        type: _type,
        clubId: _type == 'club' ? widget.clubId : null,
      );
      widget.onSuccess('Broadcast notification sent successfully!');
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send notification: $e';
        _isSubmitting = false;
      });
    }
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
                              'Create Notification',
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Broadcast a new notification message',
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

          // Scrollable Content
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
                      // Title
                      TextFormField(
                        controller: _titleController,
                        style: TextStyle(color: titleColor),
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'Enter notification title',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Message
                      TextFormField(
                        controller: _messageController,
                        maxLines: 4,
                        style: TextStyle(color: titleColor),
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          hintText: 'Enter notification description',
                          alignLabelWithHint: true,
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(bottom: 54),
                            child: Icon(Icons.message_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Rich Text Toolbar
                      _buildMarkdownToolbar(),
                      const SizedBox(height: 16),

                      // Type Dropdown
                      DropdownButtonFormField<String>(
                        value: _type,
                        dropdownColor: cardBg,
                        style: TextStyle(color: titleColor),
                        decoration: const InputDecoration(
                          labelText: 'Notification Type',
                          prefixIcon: Icon(Icons.notification_important_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'system', child: Text('System')),
                          DropdownMenuItem(value: 'club', child: Text('Club')),
                          DropdownMenuItem(value: 'announcement', child: Text('Announcement')),
                          DropdownMenuItem(value: 'event', child: Text('Event')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _type = val);
                          }
                        },
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

          // Sticky Footer
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
                        : const Text('Send Notification'),
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
