import 'package:flutter_test/flutter_test.dart';

import 'package:signal_runner/game_logic.dart';

void main() {
  group('GameState', () {
    test('does not move outside bounds', () {
      final state = GameState(GameConfig(cols: 6, rows: 6));
      for (var i = 0; i < 10; i++) {
        state.move(Direction.left);
      }
      expect(state.player.x, 0);
      for (var i = 0; i < 10; i++) {
        state.move(Direction.up);
      }
      expect(state.player.y, 0);
    });

    test('collecting all pickups spawns exit', () {
      final state = GameState(GameConfig(cols: 6, rows: 6));
      state.pickups = [const Point(1, 1)];
      state.player = const Point(0, 1);
      state.move(Direction.right); // collect at 1,1
      expect(state.pickups, isEmpty);
      expect(state.exitPad, isNotNull);
    });

    test('hazard collision ends run', () {
      final state = GameState(GameConfig(cols: 6, rows: 6));
      state.hazards = [
        Hazard(
          anchor: state.player,
          vertical: true,
          range: 0,
          speed: 0,
          seed: 1,
          maxX: state.config.cols - 1,
          maxY: state.config.rows - 1,
        ),
      ];
      final hit = state.step();
      expect(hit, isTrue);
      final resetToStart = state.processHit();
      expect(resetToStart, isFalse);
      expect(state.lives, state.config.maxLives - 1);
      expect(state.stage, 1);
      expect(state.alive, isTrue);
    });

    test('advance with cost requires spare life', () {
      final state = GameState(GameConfig(cols: 6, rows: 6));
      expect(state.lives, state.config.maxLives);
      final ok = state.advanceWithCost();
      expect(ok, isTrue);
      expect(state.stage, 2);
      expect(state.lives, state.config.maxLives - 1);
      state.lives = 1;
      final denied = state.advanceWithCost();
      expect(denied, isFalse);
      expect(state.stage, 2);
    });

    test('overheat spawns an extra hazard after threshold', () {
      final config = GameConfig(cols: 6, rows: 6, overheatTick: 2);
      final state = GameState(config);
      final initialHazards = state.hazards.length;
      state.step(); // tick 1
      state.step(); // tick 2 triggers overheat
      expect(state.overheated, isTrue);
      expect(state.hazards.length, greaterThan(initialHazards));
    });
  });
}
