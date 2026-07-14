import 'package:flutter/material.dart';

import '../models/post_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/event_card.dart';
import 'club_detail_screen.dart';
import 'post_detail_screen.dart';
import 'monthly_calendar_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.appState,
    required this.onOpenClubs,
    required this.onOpenEvents,
    required this.onOpenProfile,
  });

  final AppState appState;
  final VoidCallback onOpenClubs;
  final VoidCallback onOpenEvents;
  final VoidCallback onOpenProfile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';
  DateTime? _selectedDate;
  final ScrollController _calendarScrollController = ScrollController();

  // VL-01: GlobalKey to measure the actual hero column height at runtime
  final GlobalKey _heroKey = GlobalKey();
  double _heroHeight = 415.0;    // fallback until first frame
  double _textHeight = 208.0;    // fallback until first frame

  // Persistent map of date keys to global keys for scrolling
  final Map<String, GlobalKey> _dateKeys = {};

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatHeaderDate(String dateKey) {
    final date = DateTime.parse(dateKey);
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final tomorrowMidnight = todayMidnight.add(const Duration(days: 1));
    final dateMidnight = DateTime(date.year, date.month, date.day);
    
    if (dateMidnight.year == todayMidnight.year &&
        dateMidnight.month == todayMidnight.month &&
        dateMidnight.day == todayMidnight.day) {
      return 'Today - ${_formatFullDate(date)}';
    } else if (dateMidnight.year == tomorrowMidnight.year &&
               dateMidnight.month == tomorrowMidnight.month &&
               dateMidnight.day == tomorrowMidnight.day) {
      return 'Tomorrow - ${_formatFullDate(date)}';
    }
    return _formatFullDate(date);
  }

  void _scrollToDate(DateTime date, ScrollController controller, List<String> sortedKeys) {
    final dateKey = _formatDateKey(date);
    
    // Find the first date key that is >= target date key
    String? targetKey;
    for (final key in sortedKeys) {
      if (key.compareTo(dateKey) >= 0) {
        targetKey = key;
        break;
      }
    }
    
    targetKey ??= sortedKeys.isNotEmpty ? sortedKeys.last : null;
    
    if (targetKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _dateKeys[targetKey];
        if (key != null && key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Measure hero height from its render box so snap sizes are device-accurate
      final heroBox = _heroKey.currentContext?.findRenderObject() as RenderBox?;
      if (heroBox != null && mounted) {
        setState(() {
          _heroHeight = heroBox.size.height;
          // textHeight = topBar (66) + heading (~80) + subtext (~36) + gaps (~26)
          _textHeight = 208.0; // kept as a proportional constant; hero drives the critical min size
        });
      }

      // Calendar scroll offset
      if (_calendarScrollController.hasClients) {
        const todayIndex = 15; // middle of 31 days
        const itemWidth = 44.0;
        const separatorWidth = 8.0;
        const itemSpace = itemWidth + separatorWidth;

        // Offset so today's item aligns with the left side of the screen
        final targetOffset = todayIndex * itemSpace;
        _calendarScrollController.jumpTo(targetOffset.clamp(0.0, double.infinity));
      }
    });
  }

  @override
  void dispose() {
    _calendarScrollController.dispose();
    super.dispose();
  }



  bool _dateHasEvents(DateTime date) {
    return widget.appState.posts.any((post) =>
        post.isEvent &&
        post.date != null &&
        post.isUpcoming &&
        post.date!.year == date.year &&
        post.date!.month == date.month &&
        post.date!.day == date.day);
  }

  String _formatFullDate(DateTime date) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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

  @override
  Widget build(BuildContext context) {
    final clubs = widget.appState.clubs;
    final upcomingEvents = widget.appState.posts
        .where((post) => post.isUpcoming)
        .toList();
    final matches = clubs.where((club) {
      final text = '${club.name} ${club.description}'.toLowerCase();
      return text.contains(_query.toLowerCase());
    }).toList();


    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final calendarDays = List.generate(
      31,
      (index) => todayMidnight.add(Duration(days: index - 15)),
    );

    final String eventsHeader = 'Events Schedule';
    final calendarEvents = widget.appState.posts.where((post) {
      if (!post.isEvent || post.date == null || !post.isUpcoming) return false;
      
      // Filter out events before the selected date if a filter is active
      if (_selectedDate != null) {
        final postDateMidnight = DateTime(post.date!.year, post.date!.month, post.date!.day);
        if (postDateMidnight.isBefore(_selectedDate!)) {
          return false;
        }
      }
      
      return post.date!.isAfter(calendarDays.first.subtract(const Duration(days: 1))) &&
             post.date!.isBefore(calendarDays.last.add(const Duration(days: 1)));
    }).toList();

    final Map<String, List<PostItem>> groupedEvents = {};
    for (final post in calendarEvents) {
      final dateKey = _formatDateKey(post.date!);
      groupedEvents.putIfAbsent(dateKey, () => []).add(post);
    }

    final sortedDateKeys = groupedEvents.keys.toList()..sort();

    final List<_FeedItem> feedItems = [];
    for (final dateKey in sortedDateKeys) {
      feedItems.add(_FeedItem(dateKey: dateKey));
      for (final post in groupedEvents[dateKey]!) {
        feedItems.add(_FeedItem(post: post));
      }
    }

    final weekdaysShort = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        
        // VL-01: Use measured hero height (updated after first frame via GlobalKey)
        const double headerBarHeight = 66.0;
        
        double minSize = 1.0 - (_heroHeight / screenHeight);
        double restingSize = 1.0 - (_textHeight / screenHeight);
        final double maxSize = 1.0 - (headerBarHeight / screenHeight);
        
        minSize = minSize.clamp(0.30, 0.55);
        restingSize = restingSize.clamp(0.50, 0.82);

        return Stack(
          children: [
            // 1. Fixed Hero Layer (Background)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _heroHeight,
              child: Container(
                color: Colors.transparent,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    key: _heroKey,
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HomeTopBar(
                      appState: widget.appState,
                      onProfileTap: widget.onOpenProfile,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Walchand College\nof Engineering',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 34,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Discover communities, track club activity, and join the next wave of campus events.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.mutedColor(context),
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          RepaintBoundary(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'assets/images/wce-campus.png',
                                width: double.infinity,
                                height: 175,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
            
            // 2. Interactive Sliding Panel (Foreground)
            DraggableScrollableSheet(
              initialChildSize: restingSize,
              minChildSize: minSize,
              maxChildSize: maxSize,
              snap: true,
              snapSizes: [minSize, restingSize, maxSize],
              builder: (context, scrollController) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, -8),
                      ),
                    ],
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? AppTheme.darkBorder
                            : Colors.blueGrey.withValues(alpha: 0.05),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Drag Handle Indicator
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      
                      // Panel Content List
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          children: [
                            // ── Stats Row (no card, pure type) ───────────
                            Row(
                              children: [
                                // Left stat
                                Expanded(
                                  child: GestureDetector(
                                    onTap: widget.onOpenClubs,
                                    behavior: HitTestBehavior.opaque,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${clubs.length}',
                                          style: TextStyle(
                                            fontSize: 44,
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                            height: 1.0,
                                            letterSpacing: -2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Active Clubs',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? AppTheme.darkMuted : AppTheme.mutedColor(context),
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Thin divider
                                Container(
                                  width: 1,
                                  height: 44,
                                  color: isDark ? AppTheme.darkBorder : Colors.blueGrey.withValues(alpha: 0.12),
                                ),
                                const SizedBox(width: 20),
                                // Right stat
                                Expanded(
                                  child: GestureDetector(
                                    onTap: widget.onOpenEvents,
                                    behavior: HitTestBehavior.opaque,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${upcomingEvents.length}',
                                          style: TextStyle(
                                            fontSize: 44,
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                            height: 1.0,
                                            letterSpacing: -2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Upcoming Events',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? AppTheme.darkMuted : AppTheme.mutedColor(context),
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Search Bar
                            TextField(
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.search_rounded, size: 24,
                                    color: isDark ? AppTheme.darkMuted : AppTheme.mutedColor(context)),
                                hintText: 'Search clubs or events...',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                fillColor: isDark ? AppTheme.darkElevated : const Color(0xFFF8FAFC),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: isDark ? AppTheme.darkBorder : Colors.blueGrey.withValues(alpha: 0.08),
                                    width: 1,
                                  ),
                                ),
                              ),
                              onChanged: (value) => setState(() => _query = value),
                            ),
                            
                            // Search Results Dropdown List
                            if (_query.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkSurface : Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? AppTheme.darkBorder : Theme.of(context).dividerColor,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: matches.isEmpty
                                      ? [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 20),
                                            child: Text(
                                              'No matches found',
                                              style: TextStyle(color: AppTheme.mutedColor(context), fontSize: 13),
                                            ),
                                          )
                                        ]
                                      : matches.map((club) {
                                          return ListTile(
                                            leading: Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? AppTheme.darkElevated
                                                    : const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  club.icon.isNotEmpty ? club.icon : '🏛️',
                                                  style: const TextStyle(fontSize: 18),
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              club.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            subtitle: Text(
                                              club.description,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 11, color: AppTheme.mutedColor(context)),
                                            ),
                                            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                                            onTap: () => Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => ClubDetailScreen(
                                                  appState: widget.appState,
                                                  club: club,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),
                            


                                                    // Calendar Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Calendar',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatMonthYear(_selectedDate ?? todayMidnight).toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.mutedColor(context),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => MonthlyCalendarScreen(
                                          appState: widget.appState,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'View Month',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : AppTheme.accent(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Horizontal scroll date list
                            SizedBox(
                              height: 80,
                              child: ShaderMask(
                                shaderCallback: (Rect bounds) {
                                  return const LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black,
                                      Colors.black,
                                      Colors.transparent,
                                    ],
                                    stops: [0.0, 0.05, 0.95, 1.0],
                                  ).createShader(bounds);
                                },
                                blendMode: BlendMode.dstIn,
                                child: ListView.separated(
                                  controller: _calendarScrollController,
                                  scrollDirection: Axis.horizontal,
                                  itemCount: 31,
                                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final cellDate = calendarDays[index];
                                    final isSelected = _selectedDate != null &&
                                        _selectedDate!.year == cellDate.year &&
                                        _selectedDate!.month == cellDate.month &&
                                        _selectedDate!.day == cellDate.day;
                                    final hasEvent = _dateHasEvents(cellDate);
                                    
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedDate = null;
                                            _scrollToDate(todayMidnight, scrollController, sortedDateKeys);
                                          } else {
                                            _selectedDate = cellDate;
                                            _scrollToDate(cellDate, scrollController, sortedDateKeys);
                                          }
                                        });
                                      },
                                      child: SizedBox(
                                        width: 44,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            // Day abbreviation
                                            Text(
                                              weekdaysShort[cellDate.weekday - 1],
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                                color: isSelected
                                                    ? (isDark ? Colors.white : Theme.of(context).colorScheme.primary)
                                                    : (isDark ? AppTheme.darkMuted : AppTheme.mutedColor(context)),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            // Number — white circle only when selected
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? (isDark ? Colors.white : Theme.of(context).colorScheme.primary)
                                                    : Colors.transparent,
                                                shape: BoxShape.circle,
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                '${cellDate.day}',
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w800,
                                                  color: isSelected
                                                      ? (isDark ? AppTheme.darkBackground : Colors.white)
                                                      : (isDark ? Colors.white : AppTheme.textColor(context)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            // Event dot
                                            Container(
                                              width: 4,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: hasEvent
                                                    ? (isDark ? Colors.white.withValues(alpha: isSelected ? 0.3 : 0.7) : const Color(0xFF22C55E))
                                                    : Colors.transparent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 18),
                            
                            // Day Events Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    eventsHeader,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
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
                                        _scrollToDate(todayMidnight, scrollController, sortedDateKeys);
                                      });
                                    },
                                    child: const Text('Clear Filter'),
                                  ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            
                            if (feedItems.isEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? AppTheme.darkBorder : Theme.of(context).dividerColor,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.event_busy_rounded,
                                      size: 40,
                                      color: AppTheme.mutedColor(context).withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No events scheduled in this period.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppTheme.mutedColor(context),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              for (int index = 0; index < feedItems.length; index++) ...[
                                if (feedItems[index].dateKey != null) ...[
                                  Container(
                                    key: _dateKeys.putIfAbsent(
                                      feedItems[index].dateKey!,
                                      () => GlobalKey(),
                                    ),
                                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                                    child: Row(
                                      children: [
                                        Text(
                                          _formatHeaderDate(feedItems[index].dateKey!),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white70 : AppTheme.navyColor(context).withValues(alpha: 0.8),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Divider(
                                            color: isDark ? AppTheme.darkBorder : Colors.blueGrey.withValues(alpha: 0.12),
                                            thickness: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  EventCard(
                                    post: feedItems[index].post!,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PostDetailScreen(
                                          appState: widget.appState,
                                          initialPost: feedItems[index].post!,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (index + 1 < feedItems.length && feedItems[index + 1].dateKey == null)
                                    const SizedBox(height: 12),
                                ],
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

}


// Redesigned Carousel Card Widget matching visual mockups
// Premium Announcement Card for home updates carousel

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.appState,
    required this.onProfileTap,
  });

  final AppState appState;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final session = appState.session;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Image.asset('assets/images/wce-logo.png', width: 42, height: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Club Connect',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                if (session != null)
                  Text(
                    'Signed in as ${session.name}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.mutedColor(context),
                        ),
                  ),
              ],
            ),
          ),
          if (appState.isLoading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            AnimatedBuilder(
              animation: appState,
              builder: (context, _) {
                return Stack(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent),
                              body: AnimatedBuilder(
                                animation: appState,
                                builder: (context, _) => NotificationsScreen(appState: appState),
                              ),
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.notifications_none_rounded, color: Theme.of(context).colorScheme.onSurface, size: 26),
                    ),
                    if (appState.notifications.any((n) => !n.isRead))
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).cardColor, width: 2),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(width: 8),
           GestureDetector(
            onTap: onProfileTap,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.accent(context).withValues(alpha: 0.15) : const Color(0xFFE0E7FF),
                shape: BoxShape.circle,
                border: isDark
                    ? Border.all(color: AppTheme.accent(context).withValues(alpha: 0.3))
                    : null,
              ),
              child: Center(
                child: Text(
                  session?.name.isNotEmpty == true ? session!.name[0].toUpperCase() : 'A',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.accent(context) : const Color(0xFF312E81),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedItem {
  final String? dateKey;
  final PostItem? post;
  _FeedItem({this.dateKey, this.post});
}
