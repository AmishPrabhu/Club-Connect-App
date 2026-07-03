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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_calendarScrollController.hasClients) {
        final screenWidth = MediaQuery.of(context).size.width;
        const todayIndex = 15; // middle of 31 days
        const itemWidth = 54.0;
        const separatorWidth = 12.0;
        const itemSpace = itemWidth + separatorWidth;

        // Offset to align center of item with center of screen
        final targetOffset = (todayIndex * itemSpace) - (screenWidth / 2) + (itemWidth / 2) + 20; // 20 is horizontal padding
        _calendarScrollController.jumpTo(targetOffset);
      }
    });
  }

  @override
  void dispose() {
    _calendarScrollController.dispose();
    super.dispose();
  }

  DateTime _startOfCurrentWeek() {
    final now = DateTime.now();
    final daysToSubtract = now.weekday - 1;
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysToSubtract));
  }

  bool _dateHasEvents(DateTime date) {
    return widget.appState.posts.any((post) =>
        post.isEvent &&
        post.date != null &&
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

    // Calculate current week days
    final startOfWeek = _startOfCurrentWeek();
    final currentWeekDays = List.generate(
      7,
      (index) => startOfWeek.add(Duration(days: index)),
    );

    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final calendarDays = List.generate(
      31,
      (index) => todayMidnight.add(Duration(days: index - 15)),
    );

    final List<PostItem> displayedEvents;
    final String eventsHeader;

    if (_selectedDate == null) {
      eventsHeader = 'Weekly Events';
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

    final weekdaysShort = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        
        // Dynamic snap calculations based on screen height
        final double heroHeight = 415.0; // Heading + subtext + campus photo + top bar + margin
        final double textHeight = 208.0; // Top bar + heading + subtext + margins
        const double headerBarHeight = 66.0; // Height of _HomeTopBar (logo 42px + 24px padding)
        
        double minSize = 1.0 - (heroHeight / screenHeight);
        double restingSize = 1.0 - (textHeight / screenHeight);
        // Leave headerBarHeight always visible above the panel
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
              height: heroHeight,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
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
                          const Text(
                            'Walchand College\nof Engineering',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 34,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.navy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Discover communities, track club activity, and join the next wave of campus events.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.muted,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/images/wce-campus.png',
                              width: double.infinity,
                              height: 175,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, -8),
                      ),
                    ],
                    border: Border(
                      top: BorderSide(
                        color: Colors.blueGrey.withValues(alpha: 0.05),
                        width: 1.5,
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
                            color: Colors.grey.shade300,
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
                            // Metric Cards
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricCard(
                                    context: context,
                                    icon: Icons.groups_outlined,
                                    value: '${clubs.length}',
                                    label: 'Active Clubs',
                                    onTap: widget.onOpenClubs,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildMetricCard(
                                    context: context,
                                    icon: Icons.calendar_month_outlined,
                                    value: '${upcomingEvents.length}',
                                    label: 'Upcoming Events',
                                    onTap: widget.onOpenEvents,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Search Bar
                            TextField(
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search_rounded, size: 24, color: AppTheme.muted),
                                hintText: 'Search clubs or events...',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                fillColor: const Color(0xFFF8FAFC),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.blueGrey.withValues(alpha: 0.08),
                                    width: 1.2,
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
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade100, width: 1.5),
                                ),
                                child: Column(
                                  children: matches.isEmpty
                                      ? [
                                          const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 20),
                                            child: Text(
                                              'No matches found',
                                              style: TextStyle(color: AppTheme.muted, fontSize: 13),
                                            ),
                                          )
                                        ]
                                      : matches.map((club) {
                                          return ListTile(
                                            leading: Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
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
                                              style: const TextStyle(fontSize: 11, color: AppTheme.muted),
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
                            
                            const SizedBox(height: 24),
                            
                            // Featured Clubs Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Featured Clubs',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.navy,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                TextButton(
                                  onPressed: widget.onOpenClubs,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Row(
                                    children: [
                                      Text(
                                        'View all',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.blue,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.blue),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Horizontal Carousel list of featured clubs
                            SizedBox(
                              height: 238,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: clubs.length > 6 ? 6 : clubs.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 14),
                                itemBuilder: (context, index) {
                                  final club = clubs[index];
                                  return SizedBox(
                                    width: 270,
                                    child: GestureDetector(
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ClubDetailScreen(
                                            appState: widget.appState,
                                            club: club,
                                          ),
                                        ),
                                      ),
                                      child: _FeaturedClubCard(
                                        name: club.name,
                                        imageUrl: club.imageAsset,
                                        category: club.category,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Static Page dots indicator
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFCBD5E1),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFCBD5E1),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 26),
                            
                            // Calendar Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Calendar',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.navy,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatMonthYear(_selectedDate ?? todayMidnight).toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.muted,
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
                                  child: const Text(
                                    'View Month',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.blue),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Horizontal scroll date list
                            SizedBox(
                              height: 98,
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
                                  separatorBuilder: (_, _) => const SizedBox(width: 12),
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
                                          } else {
                                            _selectedDate = cellDate;
                                          }
                                        });
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 54,
                                            height: 76,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppTheme.navy
                                                  : const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(18),
                                              border: Border.all(
                                                color: isSelected
                                                    ? AppTheme.navy
                                                    : const Color(0xFFE2E8F0),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  weekdaysShort[cellDate.weekday - 1],
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: isSelected
                                                        ? Colors.white.withValues(alpha: 0.8)
                                                        : AppTheme.muted,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '${cellDate.day}',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                    color: isSelected
                                                        ? Colors.white
                                                        : AppTheme.text,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            width: 5,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color: hasEvent
                                                  ? (isSelected ? AppTheme.navy : const Color(0xFF22C55E))
                                                  : Colors.transparent,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
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
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.navy,
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
                                    child: const Text('Clear Filter'),
                                  ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            
                            if (displayedEvents.isEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade100, width: 1.5),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.event_busy_rounded,
                                      size: 40,
                                      color: AppTheme.muted.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _selectedDate == null
                                          ? 'No events scheduled for this week.'
                                          : 'No events scheduled for this day.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppTheme.muted,
                                        fontSize: 13,
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
                                separatorBuilder: (_, _) => const SizedBox(height: 12),
                                itemBuilder: (context, index) => EventCard(
                                  post: displayedEvents[index],
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PostDetailScreen(
                                        appState: widget.appState,
                                        initialPost: displayedEvents[index],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
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

  // Metric Card Helper Widget Builder
  Widget _buildMetricCard({
    required BuildContext context,
    required IconData icon,
    required String value,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 155,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.blueGrey.withValues(alpha: 0.08),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Outlined Custom Icon Box
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF), // Light blue-purple tint
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFDBEAFE),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: AppTheme.blue,
                size: 24,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    color: AppTheme.navy,
                    height: 1.0,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Redesigned Carousel Card Widget matching visual mockups
class _FeaturedClubCard extends StatelessWidget {
  const _FeaturedClubCard({
    required this.name,
    required this.imageUrl,
    required this.category,
  });

  final String name;
  final String imageUrl;
  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              category,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 96,
              height: 96,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl.startsWith('http')
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Image.asset(
                          'assets/images/club-default.jpg',
                          fit: BoxFit.contain,
                        ),
                      )
                    : Image.asset(
                        imageUrl.startsWith('/')
                            ? 'assets/images$imageUrl'
                            : imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Image.asset(
                          'assets/images/club-default.jpg',
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.center,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
                        color: AppTheme.blue,
                      ),
                ),
                if (session != null)
                  Text(
                    'Signed in as ${session.name}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.muted,
                        ),
                  ),
              ],
            ),
          ),
          if (appState.isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Stack(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent),
                          body: NotificationsScreen(appState: appState),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.navy, size: 26),
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
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onProfileTap,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFE0E7FF), // Light Indigo background matching screenshot
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  session?.name.isNotEmpty == true ? session!.name[0].toUpperCase() : 'A',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF312E81), // Dark indigo text color
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
