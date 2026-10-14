import 'package:chattiq_app/features/notifications/push_controller.dart';
import 'package:chattiq_app/core/providers.dart';
import 'package:chattiq_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('signed out: shows the login screen and checks the form', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
          pushPlatformProvider.overrideWithValue(FakePushPlatform()),
        ],
        child: const ChattiqApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsWidgets);
    expect(find.text('Email address or user name'), findsOneWidget);

    await tester.tap(find.widgetWithText(InkWell, 'Log in'));
    await tester.pump();

    expect(find.text('Enter your email address or user name and your password.'), findsOneWidget);
  });
}
