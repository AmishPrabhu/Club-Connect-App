import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/post_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'member_search_picker_sheet.dart';

class EditEventSheet extends StatefulWidget {
  const EditEventSheet({
    super.key,
    required this.event,
    required this.appState,
    this.onSuccess,
  });

  final PostItem event;
  final AppState appState;
  final VoidCallback? onSuccess;

  @override
  State<EditEventSheet> createState() => _EditEventSheetState();
}

class _EditEventSheetState extends State<EditEventSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _locationController;
  late final TextEditingController _locationUrlController;
  late final TextEditingController _totalSessionsController;

  // Link controllers
  late final TextEditingController _registrationLinkController;
  late final TextEditingController _responseSpreadsheetUrlController;
  late final TextEditingController _eventWhatsappLinkController;

  // Location Type
  late String _locationType;

  // Date & Time states
  DateTime? _eventDate;
  TimeOfDay? _timeFrom;
  TimeOfDay? _timeTo;

  // Registration Period states
  DateTime? _regStartDate;
  TimeOfDay? _regStartTime;
  DateTime? _regEndDate;
  TimeOfDay? _regEndTime;

  // Event Manager state
  String? _eventManagerId;
  String? _eventManagerName;
  String? _eventManagerEmail;

  bool _isSubmitting = false;
  String? _errorMessage;

  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    final event = widget.event;

    _titleController = TextEditingController(text: event.title);
    _contentController = TextEditingController(text: event.content);
    _locationController = TextEditingController(text: event.location ?? '');
    _locationUrlController = TextEditingController(text: event.locationUrl ?? '');
    _locationType = event.locationType ?? 'In-person';
    _totalSessionsController = TextEditingController(text: event.totalSessions.toString());

    _registrationLinkController = TextEditingController(text: event.registrationLink ?? '');
    _responseSpreadsheetUrlController = TextEditingController(text: event.responseSpreadsheetUrl ?? '');
    _eventWhatsappLinkController = TextEditingController(text: event.eventWhatsappLink ?? '');

    _eventDate = event.date;
    _timeFrom = _parseTimeString(event.timeFrom);
    _timeTo = _parseTimeString(event.timeTo);

    if (event.registrationStart != null && event.registrationStart!.isNotEmpty) {
      _regStartDate = DateTime.tryParse(event.registrationStart!);
    }
    _regStartTime = _parseTimeString(event.registrationStartTime);

    if (event.registrationEnd != null && event.registrationEnd!.isNotEmpty) {
      _regEndDate = DateTime.tryParse(event.registrationEnd!);
    }
    _regEndTime = _parseTimeString(event.registrationEndTime);

    _eventManagerId = event.eventManagerId;
    _eventManagerName = event.eventManagerName;
    _eventManagerEmail = event.eventManagerEmail;
  }

  TimeOfDay? _parseTimeString(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    final cleaned = timeStr.trim().toUpperCase();
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$').firstMatch(cleaned);
    if (match != null) {
      var hour = int.tryParse(match.group(1)!) ?? 0;
      final minute = int.tryParse(match.group(2)!) ?? 0;
      final ampm = match.group(3);
      if (ampm == 'PM' && hour < 12) hour += 12;
      if (ampm == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    }
    return null;
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _locationController.dispose();
    _locationUrlController.dispose();
    _totalSessionsController.dispose();
    _registrationLinkController.dispose();
    _responseSpreadsheetUrlController.dispose();
    _eventWhatsappLinkController.dispose();
    super.dispose();
  }

  Future<void> _selectDate({
    required DateTime? initial,
    required void Function(DateTime selected) onSelected,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => onSelected(picked));
    }
  }

  Future<void> _selectTime({
    required TimeOfDay? initial,
    required void Function(TimeOfDay selected) onSelected,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => onSelected(picked));
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Event Title is required.');
      return;
    }

    final totalSessions = int.tryParse(_totalSessionsController.text.trim()) ?? 1;

    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    final updates = <String, dynamic>{
      'title': title,
      'content': _contentController.text.trim(),
      'location': _locationController.text.trim(),
      'locationType': _locationType,
      'locationUrl': _locationUrlController.text.trim(),
      'totalSessions': totalSessions,
      'registrationLink': _registrationLinkController.text.trim(),
      'responseSpreadsheetUrl': _responseSpreadsheetUrlController.text.trim(),
      'eventWhatsappLink': _eventWhatsappLinkController.text.trim(),
      'eventManagerId': _eventManagerId ?? '',
      'eventManagerName': _eventManagerName ?? '',
      'eventManagerEmail': _eventManagerEmail ?? '',
    };

    if (_eventDate != null) {
      updates['date'] = _dateFormatter.format(_eventDate!);
    }
    if (_timeFrom != null) {
      updates['timeFrom'] = _formatTimeOfDay(_timeFrom);
    }
    if (_timeTo != null) {
      updates['timeTo'] = _formatTimeOfDay(_timeTo);
    }

    if (_regStartDate != null) {
      updates['registrationStart'] = _dateFormatter.format(_regStartDate!);
    }
    if (_regStartTime != null) {
      updates['registrationStartTime'] = _formatTimeOfDay(_regStartTime);
    }

    if (_regEndDate != null) {
      updates['registrationEnd'] = _dateFormatter.format(_regEndDate!);
    }
    if (_regEndTime != null) {
      updates['registrationEndTime'] = _formatTimeOfDay(_regEndTime);
    }

    try {
      await widget.appState.updatePost(widget.event.id, updates);
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event details updated successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to update event: $e';
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, Color titleColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.accent(context)),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
      height: mq.size.height * 0.9,
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : const Color(0xFFF6F8FB),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header & Close Button
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
                              'Edit Event Details',
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.event.title,
                              style: TextStyle(color: subtitleColor, fontSize: 13, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

          // Scrollable Form Content
          Expanded(
            child: SingleChildScrollView(
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
                      // 1. Basic Info
                      _buildSectionHeader('General Info', Icons.info_outline, titleColor),
                      TextFormField(
                        controller: _titleController,
                        style: TextStyle(color: titleColor),
                        decoration: const InputDecoration(
                          labelText: 'Event Title',
                          prefixIcon: Icon(Icons.event_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contentController,
                        maxLines: 4,
                        style: TextStyle(color: titleColor),
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          alignLabelWithHint: true,
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(bottom: 50),
                            child: Icon(Icons.description_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _totalSessionsController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: titleColor),
                        decoration: const InputDecoration(
                          labelText: 'Total Sessions Count',
                          hintText: 'e.g. 1, 2, 3...',
                          prefixIcon: Icon(Icons.format_list_numbered_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Event Manager Assignment Field
                      InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => MemberSearchPickerSheet(
                              clubId: widget.event.clubId,
                              appState: widget.appState,
                              selectedMemberEmail: _eventManagerEmail,
                              onMemberSelected: (m) {
                                setState(() {
                                  if (m != null) {
                                    _eventManagerId = (m['_id'] ?? m['id'] ?? m['userId'])?.toString();
                                    _eventManagerName = (m['name'] ?? m['userName'])?.toString();
                                    _eventManagerEmail = (m['email'] ?? m['userEmail'])?.toString();
                                  } else {
                                    _eventManagerId = null;
                                    _eventManagerName = null;
                                    _eventManagerEmail = null;
                                  }
                                });
                              },
                            ),
                          );
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Assigned Event Manager',
                            prefixIcon: Icon(Icons.person_pin_rounded),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _eventManagerName != null && _eventManagerName!.isNotEmpty
                                      ? '$_eventManagerName (${_eventManagerEmail ?? ""})'
                                      : 'Tap to search & assign a member',
                                  style: TextStyle(
                                    color: _eventManagerName != null ? titleColor : subtitleColor,
                                    fontWeight: _eventManagerName != null ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                              const Icon(Icons.search_rounded, size: 20),
                            ],
                          ),
                        ),
                      ),

                      // 2. Date & Time
                      _buildSectionHeader('Event Date & Time', Icons.calendar_month_outlined, titleColor),
                      InkWell(
                        onTap: () => _selectDate(
                          initial: _eventDate,
                          onSelected: (d) => _eventDate = d,
                        ),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Event Date',
                            prefixIcon: Icon(Icons.calendar_today_rounded),
                          ),
                          child: Text(
                            _eventDate != null ? _dateFormatter.format(_eventDate!) : 'Select Date',
                            style: TextStyle(color: _eventDate != null ? titleColor : subtitleColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectTime(
                                initial: _timeFrom,
                                onSelected: (t) => _timeFrom = t,
                              ),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Time From',
                                  prefixIcon: Icon(Icons.access_time_rounded),
                                ),
                                child: Text(
                                  _timeFrom != null ? _formatTimeOfDay(_timeFrom) : 'Select Time',
                                  style: TextStyle(color: _timeFrom != null ? titleColor : subtitleColor),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectTime(
                                initial: _timeTo,
                                onSelected: (t) => _timeTo = t,
                              ),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Time To',
                                  prefixIcon: Icon(Icons.access_time_filled_rounded),
                                ),
                                child: Text(
                                  _timeTo != null ? _formatTimeOfDay(_timeTo) : 'Select Time',
                                  style: TextStyle(color: _timeTo != null ? titleColor : subtitleColor),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // 3. Registration Window
                      _buildSectionHeader('Registration Window', Icons.how_to_reg_outlined, titleColor),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(
                                initial: _regStartDate,
                                onSelected: (d) => _regStartDate = d,
                              ),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Start Date',
                                  prefixIcon: Icon(Icons.date_range),
                                ),
                                child: Text(
                                  _regStartDate != null ? _dateFormatter.format(_regStartDate!) : 'Not Set',
                                  style: TextStyle(color: _regStartDate != null ? titleColor : subtitleColor, fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectTime(
                                initial: _regStartTime,
                                onSelected: (t) => _regStartTime = t,
                              ),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Start Time',
                                  prefixIcon: Icon(Icons.schedule),
                                ),
                                child: Text(
                                  _regStartTime != null ? _formatTimeOfDay(_regStartTime) : 'Not Set',
                                  style: TextStyle(color: _regStartTime != null ? titleColor : subtitleColor, fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(
                                initial: _regEndDate,
                                onSelected: (d) => _regEndDate = d,
                              ),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'End Date',
                                  prefixIcon: Icon(Icons.date_range_outlined),
                                ),
                                child: Text(
                                  _regEndDate != null ? _dateFormatter.format(_regEndDate!) : 'Not Set',
                                  style: TextStyle(color: _regEndDate != null ? titleColor : subtitleColor, fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectTime(
                                initial: _regEndTime,
                                onSelected: (t) => _regEndTime = t,
                              ),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'End Time',
                                  prefixIcon: Icon(Icons.schedule_outlined),
                                ),
                                child: Text(
                                  _regEndTime != null ? _formatTimeOfDay(_regEndTime) : 'Not Set',
                                  style: TextStyle(color: _regEndTime != null ? titleColor : subtitleColor, fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // 4. Location Details
                      _buildSectionHeader('Location Details', Icons.location_on_outlined, titleColor),
                      DropdownButtonFormField<String>(
                        initialValue: _locationType,
                        dropdownColor: cardBg,
                        style: TextStyle(color: titleColor),
                        decoration: const InputDecoration(
                          labelText: 'Location Type',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'In-person', child: Text('In-person')),
                          DropdownMenuItem(value: 'Online', child: Text('Online')),
                          DropdownMenuItem(value: 'Hybrid', child: Text('Hybrid')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _locationType = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _locationController,
                        style: TextStyle(color: titleColor),
                        decoration: const InputDecoration(
                          labelText: 'Venue / Location Name',
                          hintText: 'e.g. Main Auditorium, Lab 3',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _locationUrlController,
                        style: TextStyle(color: titleColor),
                        decoration: const InputDecoration(
                          labelText: 'Location / Meeting Link',
                          hintText: 'e.g. Google Maps or Meet link',
                          prefixIcon: Icon(Icons.map_outlined),
                        ),
                      ),

                      // 5. Links & Spreadsheets
                      _buildSectionHeader('Event Links & Resources', Icons.link_rounded, titleColor),
                      TextFormField(
                        controller: _registrationLinkController,
                        style: TextStyle(color: titleColor),
                        decoration: const InputDecoration(
                          labelText: 'Registration Form Link',
                          hintText: 'https://forms.google.com/...',
                          prefixIcon: Icon(Icons.app_registration_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _responseSpreadsheetUrlController,
                        style: TextStyle(color: titleColor),
                        decoration: const InputDecoration(
                          labelText: 'Response Spreadsheet URL',
                          hintText: 'https://docs.google.com/spreadsheets/...',
                          prefixIcon: Icon(Icons.table_chart_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _eventWhatsappLinkController,
                        style: TextStyle(color: titleColor),
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp Group Link',
                          hintText: 'https://chat.whatsapp.com/...',
                          prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                        : const Text('Save Changes'),
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
