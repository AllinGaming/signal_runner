import 'dart:math';

enum Direction { up, down, left, right }

class Point {
  const Point(this.x, this.y);
  final int x;
  final int y;

  Point move(Direction dir) {
    switch (dir) {
      case Direction.up:
        return Point(x, y - 1);
      case Direction.down:
        return Point(x, y + 1);
      case Direction.left:
        return Point(x - 1, y);
      case Direction.right:
        return Point(x + 1, y);
    }
  }

  @override
  bool operator ==(Object other) => other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

class Hazard {
  Hazard({
    required this.anchor,
    required this.vertical,
    required this.range,
    required this.speed,
    required this.seed,
    required this.maxX,
    required this.maxY,
  }) : phase = Random(seed).nextDouble() * pi * 2;

  final Point anchor;
  final bool vertical;
  final int range;
  final double speed;
  final int seed;
  final int maxX;
  final int maxY;
  double phase;

  Point position(int tick) {
    final offset = (sin(phase + tick * speed) * range).round();
    final x = vertical ? anchor.x : (anchor.x + offset).clamp(0, maxX);
    final y = vertical ? (anchor.y + offset).clamp(0, maxY) : anchor.y;
    return Point(x, y);
  }
}

class GameConfig {
  GameConfig({
    this.cols = 20,
    this.rows = 15,
    this.pickupsBase = 4,
    this.pickupsGrowth = 2,
    this.hazardBase = 2,
    this.hazardGrowth = 1,
    this.maxPickups = 14,
    this.maxHazards = 9,
    this.maxLives = 3,
    this.overheatTick = 700,
  });

  final int cols;
  final int rows;
  final int pickupsBase;
  final int pickupsGrowth;
  final int hazardBase;
  final int hazardGrowth;
  final int maxPickups;
  final int maxHazards;
  final int maxLives;
  final int overheatTick;
}

class GameState {
  GameState(this.config, {Random? random})
      : _random = random ?? Random(),
        stage = 1,
        bestStage = 1,
        lives = config.maxLives {
    _initStage(1);
  }

  final GameConfig config;
  final Random _random;

  int stage;
  int bestStage;
  int lives;
  bool alive = true;
  int tick = 0;
  bool overheated = false;

  late Point player;
  late List<Point> pickups;
  late List<Hazard> hazards;
  Point? exitPad;

  void reset(int newStage, {bool restoreLives = false}) {
    if (restoreLives) {
      lives = config.maxLives;
    }
    _initStage(newStage);
  }

  void _initStage(int newStage) {
    stage = newStage;
    bestStage = bestStage < stage ? stage : bestStage;
    tick = 0;
    overheated = false;
    alive = true;
    exitPad = null;
    player = Point(config.cols ~/ 2, config.rows ~/ 2);
    pickups = _buildPickups();
    hazards = _buildHazards();
  }

  void advanceStage() {
    reset(stage + 1);
  }

  /// Skip forward a stage by spending a life; returns false if denied.
  bool advanceWithCost() {
    if (lives <= 1) return false;
    lives -= 1;
    advanceStage();
    return true;
  }

  void rerollStage() {
    reset(stage);
  }

  void move(Direction dir) {
    if (!alive) return;
    final next = player.move(dir);
    final nx = next.x.clamp(0, config.cols - 1);
    final ny = next.y.clamp(0, config.rows - 1);
    player = Point(nx, ny);
    _collect();
  }

  /// Steps simulation forward. Returns true if a hazard hit occurred.
  bool step() {
    if (!alive) return false;
    tick++;
    _maybeOverheat();
    final hit = _checkHazards();
    if (hit) {
      alive = false;
    }
    return hit;
  }

  /// Applies damage and rerolls or resets depending on remaining lives.
  bool processHit() {
    lives -= 1;
    if (lives <= 0) {
      reset(1, restoreLives: true);
      return true;
    }
    reset(stage);
    return false;
  }

  void _collect() {
    final idx = pickups.indexOf(player);
    if (idx != -1) {
      pickups.removeAt(idx);
      if (pickups.isEmpty) {
        exitPad = _randomOpenCell(excluded: {player});
      }
    }
    if (exitPad == player) {
      advanceStage();
    }
  }

  void _maybeOverheat() {
    if (overheated || tick < config.overheatTick) return;
    overheated = true;
    hazards.add(
      Hazard(
        anchor: _randomOpenCell(),
        vertical: _random.nextBool(),
        range: 4 + _random.nextInt(3),
        speed: 0.12 + stage * 0.02,
        seed: _random.nextInt(1 << 16),
        maxX: config.cols - 1,
        maxY: config.rows - 1,
      ),
    );
  }

  bool _checkHazards() {
    for (final h in hazards) {
      if (h.position(tick) == player) {
        return true;
      }
    }
    return false;
  }

  List<Point> _buildPickups() {
    final count = (config.pickupsBase + stage * config.pickupsGrowth).clamp(1, config.maxPickups);
    final result = <Point>{};
    while (result.length < count) {
      final p = _randomOpenCell();
      if (p == player) continue;
      result.add(p);
    }
    return result.toList();
  }

  List<Hazard> _buildHazards() {
    final count = (config.hazardBase + (stage ~/ 2) * config.hazardGrowth).clamp(1, config.maxHazards);
    return List.generate(count, (i) {
      final vertical = i.isEven;
      final anchor = _randomOpenCell();
      final range = 2 + _random.nextInt(4);
      final speed = 0.05 + stage * 0.01 + _random.nextDouble() * 0.02;
      return Hazard(
        anchor: anchor,
        vertical: vertical,
        range: range,
        speed: speed,
        seed: _random.nextInt(1 << 16),
        maxX: config.cols - 1,
        maxY: config.rows - 1,
      );
    });
  }

  Point _randomOpenCell({Set<Point>? excluded}) {
    excluded ??= {};
    while (true) {
      final p = Point(_random.nextInt(config.cols), _random.nextInt(config.rows));
      if (excluded.contains(p)) continue;
      if (p == player) continue;
      return p;
    }
  }
}
