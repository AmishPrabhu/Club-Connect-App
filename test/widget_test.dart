import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:club_connect_flutter/src/screens/root_screen.dart';
import 'package:club_connect_flutter/src/state/app_state.dart';
import 'package:club_connect_flutter/src/theme/app_theme.dart';

void main() {
  testWidgets('renders Club Connect shell', (WidgetTester tester) async {
    final appState = AppState()..isBootstrapping = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: RootScreen(appState: appState),
      ),
    );
    await tester.pump();

    expect(find.text('Club Connect'), findsWidgets);
    expect(find.text('Clubs'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
  });
}
