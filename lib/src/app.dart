import 'package:flutter/material.dart';

import 'screens/root_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

class ClubConnectApp extends StatefulWidget {
  const ClubConnectApp({super.key});

  @override
  State<ClubConnectApp> createState() => _ClubConnectAppState();
}

class _ClubConnectAppState extends State<ClubConnectApp> {
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    _appState.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Club Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: AnimatedBuilder(
        animation: _appState,
        builder: (context, _) {
          if (_appState.isBootstrapping) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return RootScreen(appState: _appState);
        },
      ),
    );
  }
}
