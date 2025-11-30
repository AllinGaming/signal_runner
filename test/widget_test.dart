// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signal_runner/main.dart';
import 'package:signal_runner/sound/sound_player_stub.dart';

void main() {
  testWidgets('HUD renders and buttons exist', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(soundPlayer: StubSoundPlayer()),
      ),
    );

    expect(find.textContaining('Signal Runner'), findsOneWidget);
    expect(find.textContaining('Stage 1'), findsOneWidget);
    expect(find.text('RESET'), findsOneWidget);
    expect(find.text('ADVANCE (-1 LIFE)'), findsOneWidget);
  });
}
