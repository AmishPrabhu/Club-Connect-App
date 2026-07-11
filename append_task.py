import sys

dart_code = '''
class _CreateTaskSheet extends StatefulWidget {
  const _CreateTaskSheet({
    required this.appState,
    required this.club,
    required this.members,
    required this.posts,
    required this.onSuccess,
  });

  final AppState appState;
  final Club club;
  final List<dynamic> members;
  final List<PostItem> posts;
  final void Function(String message) onSuccess;

  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final deadlineController = TextEditingController();
  final selectedNames = <String>{};
  String relatedEventId = '';
  bool _isSubmitting = false;

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        deadlineController.text = "\-\-\";
      });
    }
  }

  Future<void> _submit() async {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a task title.')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final chosenMembers = widget.members.where((m) => selectedNames.contains(m['name']?.toString() ?? ''));
      await widget.appState.createTask(
        clubId: widget.club.id,
        title: title,
        description: descController.text.trim(),
        assignedTo: chosenMembers.map((m) => m['name'].toString()).toList(),
        assignedToEmails: chosenMembers.map((m) => m['email'].toString()).toList(),
        deadline: deadlineController.text.trim(),
        relatedEventId: relatedEventId.isNotEmpty ? relatedEventId : null,
        relatedEventTitle: widget.posts.where((p) => p.id == relatedEventId).firstOrNull?.title,
      );
      widget.onSuccess('Task created successfully!');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final events = widget.posts.where((post) => post.isEvent).toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Create Task', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Task Title',
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: deadlineController,
                      readOnly: true,
                      onTap: pickDate,
                      decoration: InputDecoration(
                        labelText: 'Deadline',
                        hintText: 'Select Date',
                        prefixIcon: const Icon(Icons.calendar_today_rounded),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (events.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: relatedEventId.isEmpty ? null : relatedEventId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Related Event',
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('No Related Event')),
                          ...events.map(
                            (post) => DropdownMenuItem(value: post.id, child: Text(post.title, overflow: TextOverflow.ellipsis)),
                          ),
                        ],
                        onChanged: (value) => setState(() => relatedEventId = value ?? ''),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    const Text('Assign To', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (widget.members.isEmpty)
                      const Text('No members in this club.', style: TextStyle(color: Colors.grey))
                    else
                      ...widget.members.map((member) {
                        final name = member['name']?.toString() ?? 'Member';
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: selectedNames.contains(name),
                          title: Text(name),
                          subtitle: Text(member['role']?.toString() ?? ''),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                selectedNames.add(name);
                              } else {
                                selectedNames.remove(name);
                              }
                            });
                          },
                        );
                      }),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            
            // Footer
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
'''

with open('e:/Club Connect Flutter/lib/src/screens/dashboard_screen.dart', 'a', encoding='utf-8') as f:
    f.write('\\n' + dart_code)
print('Appended _CreateTaskSheet to dashboard_screen.dart')
