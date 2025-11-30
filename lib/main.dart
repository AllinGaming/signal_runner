import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'game_logic.dart';
import 'sound/sound_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SignalRunnerApp());
}

class SignalRunnerApp extends StatelessWidget {
  const SignalRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Signal Runner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF94c76b),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'monospace',
      ),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key, this.soundPlayer});

  final SoundPlayer? soundPlayer;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  late final GameState _state;
  late final SoundPlayer _sound;
  late final Ticker _ticker;
  late final FocusNode _focusNode;

  Duration _lastTick = Duration.zero;
  double _accumulator = 0;
  final double _stepMs = 110;
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    _state = GameState(GameConfig());
    _sound = widget.soundPlayer ?? createSoundPlayer();
    _focusNode = FocusNode();
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final delta = (elapsed - _lastTick).inMilliseconds.toDouble();
    _lastTick = elapsed;
    _accumulator += delta;
    while (_accumulator >= _stepMs) {
      _stepGame();
      _accumulator -= _stepMs;
    }
    setState(() {});
  }

  void _stepGame() {
    final stageBefore = _state.stage;
    final hit = _state.step();
    if (hit) {
      _sound.fail();
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 320), () {
        final resetToStart = _state.processHit();
        if (resetToStart) {
          _sound.blip(300);
        }
        setState(() {});
      });
    }
    if (_state.stage > stageBefore) {
      _sound.melody();
    }
  }

  void _handleMove(Direction dir) {
    final stageBefore = _state.stage;
    final hadExit = _state.exitPad != null;
    final pickupsBefore = _state.pickups.length;
    _state.move(dir);
    if (_state.pickups.length < pickupsBefore) {
      _sound.blip(820);
    } else {
      _sound.blip(560);
    }
    if (_state.stage > stageBefore) {
      _sound.melody();
    } else if (hadExit && _state.exitPad == null) {
      _sound.melody();
    }
    setState(() {});
  }

  void _toggleMusic() {
    _musicEnabled = !_musicEnabled;
    _sound.setEnabled(_musicEnabled, _sfxEnabled);
    setState(() {});
  }

  void _toggleSfx() {
    _sfxEnabled = !_sfxEnabled;
    _sound.setEnabled(_musicEnabled, _sfxEnabled);
    setState(() {});
  }

  void _reroll() {
    _resetTimer?.cancel();
    _state.rerollStage();
    _sound.blip(320);
    setState(() {});
  }

  void _advance() {
    // Advance jumps to a harder layout by spending one life (if available).
    final ok = _state.advanceWithCost();
    if (ok) {
      _sound.melody();
    } else {
      _sound.fail();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const palette = _Palette();
    return Scaffold(
      backgroundColor: palette.bgDeep,
      body: SafeArea(
        child: KeyboardListener(
          focusNode: _focusNode,
          onKeyEvent: _handleKeyEvent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 900;
              final gameView = _buildGameView(context, palette, compact);
              final sidebar = _buildSidebar(palette);
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      gameView,
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: sidebar,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGameView(BuildContext context, _Palette palette, bool compact) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = compact
        ? (screenWidth - 64).clamp(240.0, 420.0)
        : 520.0;
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Container(
        decoration: BoxDecoration(
          color: palette.bgMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.frame, width: 6),
          boxShadow: [
            BoxShadow(color: palette.shadow, offset: const Offset(0, 6)),
          ],
          gradient: LinearGradient(
            colors: [palette.bgMid, palette.bgDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.1, 0.9],
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHud(palette),
            const SizedBox(height: 8),
            SizedBox(
              width: boardSize,
              height: boardSize * (_state.config.rows / _state.config.cols),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.bgDeep,
                  border: Border.all(color: palette.frame, width: 4),
                  boxShadow: [
                    BoxShadow(color: palette.shadow, offset: const Offset(0, 3)),
                    BoxShadow(color: palette.glow.withValues(alpha: 0.3), blurRadius: 6),
                  ],
                ),
                child: CustomPaint(
                  painter: _GamePainter(_state, palette),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildControls(palette),
          ],
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      _handleMove(Direction.up);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      _handleMove(Direction.down);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      _handleMove(Direction.left);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
      _handleMove(Direction.right);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      _reroll();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildHud(_Palette palette) {
    final status = _state.alive ? 'Online' : 'Tagged';
    final statusColor = _state.alive ? palette.accent : palette.alert;
    final heat = _state.overheated ? 'Heat: SPIKE' : 'Heat: Stable';
    final heatColor = _state.overheated ? palette.alert : palette.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.bgDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.frame),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          _HudBlock(label: 'Stage', value: _state.stage.toString()),
          _HudBlock(label: 'Best', value: _state.bestStage.toString()),
          _HudBlock(label: 'Diskettes', value: '${_state.pickups.length}'),
          _HudBlock(label: 'Lives', value: '${_state.lives}/${_state.config.maxLives}'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              _state.config.maxLives,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  Icons.favorite,
                  size: 14,
                  color: i < _state.lives ? palette.accent : palette.grid,
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department, size: 14, color: heatColor),
              const SizedBox(width: 6),
              Text(heat, style: TextStyle(color: heatColor, letterSpacing: 1.1, fontSize: 12)),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 10, color: statusColor),
              const SizedBox(width: 6),
              Text(status, style: TextStyle(color: statusColor, letterSpacing: 1.2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls(_Palette palette) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _reroll,
                style: FilledButton.styleFrom(backgroundColor: palette.accent),
                child: const Text('RESET'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _advance,
                style: FilledButton.styleFrom(backgroundColor: palette.accentDark),
                child: const Text('ADVANCE (-1 LIFE)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _ToggleChip(
              label: 'Music',
              enabled: _musicEnabled,
              onPressed: _toggleMusic,
            ),
            const SizedBox(width: 8),
            _ToggleChip(
              label: 'SFX',
              enabled: _sfxEnabled,
              onPressed: _toggleSfx,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Dpad(onMove: _handleMove),
      ],
    );
  }

  Widget _buildSidebar(_Palette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.bgMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.frame, width: 6),
        gradient: LinearGradient(
          colors: [palette.bgMid, palette.bgDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Signal Runner', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'You are a courier pushing signal cartridges across a hostile grid. '
            'Collect every diskette, unlock the exit node, and survive roaming drones. '
            'Heat spikes over time, adding extra drones. '
            'ADVANCE skips ahead by spending one life; RESET rerolls the current stage.',
          ),
          const SizedBox(height: 12),
          const Text('Controls'),
          const SizedBox(height: 6),
          const Text('Arrow keys / WASD to move. Space to RESET quickly.'),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.bolt, size: 16),
              const SizedBox(width: 6),
              Text('Stage ${_state.stage} · Best ${_state.bestStage}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _GamePainter extends CustomPainter {
  _GamePainter(this.state, this.palette);

  final GameState state;
  final _Palette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = state.config.cols;
    final rows = state.config.rows;
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    final bgPaint = Paint()..color = palette.bgDeep;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final gridPaint = Paint()
      ..color = palette.grid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var c = 0; c <= cols; c++) {
      final x = c * cellW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var r = 0; r <= rows; r++) {
      final y = r * cellH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final diskPaint = Paint()..color = palette.accent;
    final innerDisk = Paint()..color = palette.accentDark;
    for (final p in state.pickups) {
      final rect = Rect.fromLTWH(p.x * cellW + 3, p.y * cellH + 3, cellW - 6, cellH - 6);
      canvas.drawRect(rect, diskPaint);
      final inset = rect.deflate(5);
      canvas.drawRect(inset, innerDisk);
    }

    if (state.exitPad != null) {
      final p = state.exitPad!;
      final rect = Rect.fromLTWH(p.x * cellW + 2, p.y * cellH + 2, cellW - 4, cellH - 4);
      canvas.drawRect(rect, Paint()..color = palette.signal);
      canvas.drawRect(rect.deflate(3), Paint()..color = palette.accent);
    }

    final hazardPaint = Paint()..color = palette.alert;
    for (final h in state.hazards) {
      final pos = h.position(state.tick);
      final rect = Rect.fromLTWH(pos.x * cellW + 1, pos.y * cellH + 1, cellW - 2, cellH - 2);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), hazardPaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(4), const Radius.circular(3)),
        Paint()..color = palette.accentDark,
      );
    }

    final player = Rect.fromLTWH(
      state.player.x * cellW + 1,
      state.player.y * cellH + 1,
      cellW - 2,
      cellH - 2,
    );
    canvas.drawRect(player, Paint()..color = state.alive ? palette.player : palette.alert);
    canvas.drawRect(player.deflate(4), Paint()..color = palette.accent);

    if (state.overheated) {
      final overlay = Paint()..color = palette.alert.withValues(alpha: 0.1);
      canvas.drawRect(Offset.zero & size, overlay);
    }
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) {
    return true;
  }
}

class _HudBlock extends StatelessWidget {
  const _HudBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 1.2)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.label, required this.enabled, required this.onPressed});

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: enabled,
      label: Text('$label ${enabled ? "ON" : "OFF"}'),
      onSelected: (_) => onPressed(),
    );
  }
}

class _Dpad extends StatelessWidget {
  const _Dpad({required this.onMove});

  final void Function(Direction) onMove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _padButton(Icons.keyboard_arrow_up, () => onMove(Direction.up)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _padButton(Icons.keyboard_arrow_left, () => onMove(Direction.left)),
              const SizedBox(width: 8),
              _padButton(Icons.keyboard_arrow_down, () => onMove(Direction.down)),
              const SizedBox(width: 8),
              _padButton(Icons.keyboard_arrow_right, () => onMove(Direction.right)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _padButton(IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(12),
      ),
      onPressed: onPressed,
      child: Icon(icon),
    );
  }
}

class _Palette {
  const _Palette();
  final Color bgDeep = const Color(0xFF0e1f1a);
  final Color bgMid = const Color(0xFF21402e);
  final Color frame = const Color(0xFF31563b);
  final Color grid = const Color(0xFF193225);
  final Color accent = const Color(0xFF9dcf73);
  final Color accentDark = const Color(0xFF6e9a5a);
  final Color player = const Color(0xFFe9fdd1);
  final Color alert = const Color(0xFFd76969);
  final Color signal = const Color(0xFFf5d06f);
  final Color shadow = Colors.black45;
  final Color glow = const Color(0xFFa0d884);
}
