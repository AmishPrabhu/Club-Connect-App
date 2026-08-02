import 'package:flutter/material.dart';

import '../models/post_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/event_card.dart';
import '../widgets/glass_card.dart';
import 'post_detail_screen.dart';

class MonthlyCalendarScreen extends StatefulWidget {
  const MonthlyCalendarScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<MonthlyCalendarScreen> createState() => _MonthlyCalendarScreenState();
}

class _MonthlyCalendarScreenState extends State<MonthlyCalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  // Month navigation helpers
  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
      _selectedDate = null; // Clear stale selection from previous month
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
      _selectedDate = null; // Clear stale selection from previous month
    });
  }

  void _showMonthYearPicker(BuildContext context) {
    int tempYear = _focusedMonth.year;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final months = [
              'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
            ];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Year Selection Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, size: 28),
                        onPressed: () {
                          setModalState(() => tempYear--);
                        },
                      ),
                      Row(
                        children: [
                          Text(
                            '$tempYear',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Year',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.mutedColor(context),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 28),
                        onPressed: () {
                          setModalState(() => tempYear++);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Month Grid Selection
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.0,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthNum = index + 1;
                      final isSelected = (monthNum == _focusedMonth.month && tempYear == _focusedMonth.year);
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _focusedMonth = DateTime(tempYear, monthNum, 1);
                            _selectedDate = null;
                          });
                          Navigator.of(context).pop();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.purple
                                : (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            months[index],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Get total days in the focused month
  int _getDaysInMonth(int year, int month) {
    if (month == 12) {
      return DateTime(year + 1, 1, 0).day;
    }
    return DateTime(year, month + 1, 0).day;
  }

  // Get the start weekday index (0 = Sunday, ..., 6 = Saturday)
  int _getStartWeekdayOfMonth(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    return firstDay.weekday % 7;
  }

  // Check if a date has events
  bool _dateHasEvents(DateTime date) {
    return widget.appState.posts.any((post) =>
        post.isEvent &&
        post.date != null &&
        post.date!.year == date.year &&
        post.date!.month == date.month &&
        post.date!.day == date.day);
  }

  // Format month and year (e.g. "March 2026")
  String _formatMonthYear(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  // Format full date (e.g. "Fri, Mar 20")
  String _formatFullDate(DateTime date) {
    final weekdays = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun'
    ];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  // Get start of the current week (Monday)
  DateTime _startOfCurrentWeek() {
    final now = DateTime.now();
    final daysToSubtract = now.weekday - 1;
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysToSubtract));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = _getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final startOffset =
        _getStartWeekdayOfMonth(_focusedMonth.year, _focusedMonth.month);

    // Total cells in the grid (offset padding + days)
    final totalCells = startOffset + daysInMonth;

    // Days of the week headers (Starting with Sunday as in typical monthly calendar)
    final weekHeaders = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];

    // Determine current week days for default view
    final startOfWeek = _startOfCurrentWeek();
    final currentWeekDays = List.generate(
      7,
      (index) => startOfWeek.add(Duration(days: index)),
    );

    // Filter events based on selection
    final List<PostItem> displayedEvents;
    final String eventsHeader;

    if (_selectedDate == null) {
      eventsHeader = 'Events this week';
      displayedEvents = widget.appState.posts.where((post) {
        if (!post.isEvent || post.date == null) return false;
        return currentWeekDays.any((day) =>
            post.date!.year == day.year &&
            post.date!.month == day.month &&
            post.date!.day == day.day);
      }).toList();
    } else {
      eventsHeader = 'Events on ${_formatFullDate(_selectedDate!)}';
      displayedEvents = widget.appState.posts.where((post) {
        if (!post.isEvent || post.date == null) return false;
        return post.date!.year == _selectedDate!.year &&
            post.date!.month == _selectedDate!.month &&
            post.date!.day == _selectedDate!.day;
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Calendar'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          // Background Decor (matches RootScreen background)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: Theme.of(context).brightness == Brightness.dark
                    ? [
                        AppTheme.surfaceBg(context),
                        AppTheme.surfaceBg(context),
                      ]
                    : const [
                        Color(0xFFF8FAFC),
                        Color(0xFFF1F5F9),
                      ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Calendar Card
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Month Year header & Navigation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () => _showMonthYearPicker(context),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatMonthYear(_focusedMonth),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 22,
                                          ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      size: 28,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.chevron_left_rounded,
                                    size: 28,
                                  ),
                                  onPressed: _prevMonth,
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 28,
                                  ),
                                  onPressed: _nextMonth,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Days of week header row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: weekHeaders.map((header) {
                            return Expanded(
                              child: Text(
                                header,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppTheme.mutedColor(context),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        // Calendar Grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: totalCells,
                          itemBuilder: (context, index) {
                            // If index is less than first day offset, draw empty space
                            if (index < startOffset) {
                              return const SizedBox.shrink();
                            }

                            final dayNumber = index - startOffset + 1;
                            final cellDate = DateTime(
                              _focusedMonth.year,
                              _focusedMonth.month,
                              dayNumber,
                            );

                            final isSelected = _selectedDate != null &&
                                _selectedDate!.year == cellDate.year &&
                                _selectedDate!.month == cellDate.month &&
                                _selectedDate!.day == cellDate.day;

                            final isToday = now.year == cellDate.year &&
                                now.month == cellDate.month &&
                                now.day == cellDate.day;

                            final hasEvent = _dateHasEvents(cellDate);

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    // Deselect to reset to current week events
                                    _selectedDate = null;
                                  } else {
                                    _selectedDate = cellDate;
                                  }
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white
                                          : AppTheme.accent(context))
                                      : isToday
                                          ? AppTheme.accent(context).withValues(alpha: 0.1)
                                          : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 6.0,
                                      ),
                                      child: Text(
                                        '$dayNumber',
                                        style: TextStyle(
                                          fontWeight: isSelected || isToday
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          fontSize: 15,
                                          color: isSelected
                                              ? (Theme.of(context).brightness == Brightness.dark
                                                  ? Colors.black
                                                  : Theme.of(context).cardColor)
                                              : isToday
                                                  ? AppTheme.accent(context)
                                                  : AppTheme.textColor(context),
                                        ),
                                      ),
                                    ),
                                    if (hasEvent)
                                      Positioned(
                                        bottom: 6,
                                        child: Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? (Theme.of(context).brightness == Brightness.dark
                                                    ? Colors.black
                                                    : Theme.of(context).cardColor)
                                                : const Color(0xFF22C55E), // Green dot
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Divider(color: AppTheme.borderColor(context)),
                        const SizedBox(height: 8),
                        // Legend
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 10,
                              color: Color(0xFF22C55E),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Events are marked with green',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.mutedColor(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Events Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          eventsHeader,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedDate != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedDate = null;
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF94A3B8)
                                : AppTheme.accent(context),
                          ),
                          child: const Text('Clear Filter'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Filtered Event List
                  if (displayedEvents.isEmpty)
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                        horizontal: 20,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy_rounded,
                            size: 48,
                            color: AppTheme.mutedColor(context).withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedDate == null
                                ? 'No events scheduled for this week.'
                                : 'No events scheduled for this day.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.mutedColor(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedEvents.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final event = displayedEvents[index];
                        return EventCard(
                          appState: widget.appState,
                          post: event,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(
                                appState: widget.appState,
                                initialPost: event,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
