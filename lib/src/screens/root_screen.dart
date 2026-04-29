import 'package:flutter/material.dart';

import '../state/app_state.dart';
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

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final screens = [
      HomeScreen(
        appState: appState,
        onOpenClubs: () => setState(() => _index = 1),
        onOpenEvents: () => setState(() => _index = 2),
      ),
      ClubsScreen(appState: appState),
      EventsScreen(appState: appState),
      NotificationsScreen(appState: appState),
      ProfileScreen(appState: appState),
    ];

    return Scaffold(
      body: Stack(
        children: [
          const _BackgroundDecor(),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  appState: appState,
                  onOpenProfile: () => setState(() => _index = 4),
                ),
                Expanded(
                  child: IndexedStack(index: _index, children: screens),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Clubs',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event_rounded),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.appState, required this.onOpenProfile});

  final AppState appState;
  final VoidCallback onOpenProfile;

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
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  session == null
                      ? 'Live data from your campus backend'
                      : 'Signed in as ${session.name}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (appState.isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (!appState.isLoading)
            IconButton(
              onPressed: appState.refreshAll,
              icon: const Icon(Icons.refresh_rounded),
            ),
          IconButton(
            onPressed: onOpenProfile,
            icon: const Icon(Icons.account_circle_outlined),
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
          colors: [Color(0xFFF7FAFD), Color(0xFFEFF4FB)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -20,
            child: _blob(const Color(0x2038BDF8), 220),
          ),
          Positioned(
            top: 160,
            right: -40,
            child: _blob(const Color(0x187C3AED), 180),
          ),
          Positioned(
            bottom: -70,
            left: 40,
            child: _blob(const Color(0x142563EB), 200),
          ),
        ],
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size),
      ),
    );
  }
}
