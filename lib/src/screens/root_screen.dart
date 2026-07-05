import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'clubs_screen.dart';
import 'events_screen.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  Widget _buildNavItem(int index, IconData unselectedIcon, IconData selectedIcon, String label) {
    final isSelected = _index == index;
    final color = isSelected ? AppTheme.navy : AppTheme.muted;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _index = index),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.navy.withValues(alpha: 0.08) // Soft navy capsule background
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? selectedIcon : unselectedIcon,
                  color: color,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final screens = [
      HomeScreen(
        appState: appState,
        onOpenClubs: () => setState(() => _index = 1),
        onOpenEvents: () => setState(() => _index = 2),
        onOpenProfile: () => setState(() => _index = 3),
      ),
      ClubsScreen(appState: appState),
      EventsScreen(appState: appState),
      ProfileScreen(appState: appState),
    ];

    return Scaffold(
      body: Stack(
        children: [
          const _BackgroundDecor(),
          SafeArea(
            child: Column(
              children: [
                if (_index != 0)
                  _TopBar(
                    appState: appState,
                    onProfileTap: () => setState(() => _index = 3),
                  ),
                Expanded(
                  child: IndexedStack(index: _index, children: screens),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.blueGrey.withValues(alpha: 0.08),
              width: 1.2,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 68,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                _buildNavItem(1, Icons.groups_outlined, Icons.groups_rounded, 'Clubs'),
                _buildNavItem(2, Icons.event_outlined, Icons.event_rounded, 'Events'),
                _buildNavItem(3, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
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
                          body: AnimatedBuilder(
                            animation: appState,
                            builder: (context, _) => NotificationsScreen(appState: appState),
                          ),
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

class _BackgroundDecor extends StatelessWidget {
  const _BackgroundDecor();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF8FAFC),
            Color(0xFFF1F5F9),
          ],
        ),
      ),
    );
  }
}
