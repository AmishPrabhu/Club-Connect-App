import 'package:flutter/material.dart';

import 'screens/root_screen.dart';
import 'services/push_notifications_manager.dart';
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
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final baseTheme = Theme.of(context);
        
        double scale(double baseSize) {
          final s = screenWidth / 375.0;
          return baseSize * s.clamp(0.85, 1.25);
        }
        
        return Theme(
          data: baseTheme.copyWith(
            textTheme: baseTheme.textTheme.copyWith(
              displaySmall: baseTheme.textTheme.displaySmall?.copyWith(fontSize: scale(34)),
              headlineMedium: baseTheme.textTheme.headlineMedium?.copyWith(fontSize: scale(26)),
              titleLarge: baseTheme.textTheme.titleLarge?.copyWith(fontSize: scale(20)),
              titleMedium: baseTheme.textTheme.titleMedium?.copyWith(fontSize: scale(16)),
              bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(fontSize: scale(16)),
              bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(fontSize: scale(14)),
              bodySmall: baseTheme.textTheme.bodySmall?.copyWith(fontSize: scale(12)),
            ),
          ),
          child: child!,
        );
      },
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
