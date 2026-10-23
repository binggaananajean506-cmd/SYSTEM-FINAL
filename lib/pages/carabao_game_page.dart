import 'package:esugid/app/theme/semantic_colors.dart';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════
// GAME ENUMS & DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════

/// Game lifecycle state machine.
enum CarabaoGameState { ready, countdown, running, paused, stumbling, gameOver }

/// Types of obstacles.
enum ObstacleType {
  rock(
    'assets/images/games/obstacle-rock-3d.png',
    0.095,
    0.076,
    353 / 281,
    12 / 281,
  ),
  log(
    'assets/images/games/obstacle-log-3d.png',
    0.145,
    0.060,
    541 / 195,
    11 / 195,
  ),
  grass(
    'assets/images/games/obstacle-grass-3d.png',
    0.115,
    0.092,
    495 / 471,
    11 / 471,
  );

  const ObstacleType(
    this.asset,
    this.width,
    this.height,
    this.assetAspectRatio,
    this.bottomPaddingFraction,
  );

  final String asset;
  final double width;
  final double height;
  final double assetAspectRatio;
  final double bottomPaddingFraction;
}

/// Simple Power-Up types.
enum PowerUpType {
  shield(Icons.shield_rounded, 'SHIELD', Color(0xFF52B788)),
  magnet(Icons.all_inclusive_rounded, 'MAGNET', Color(0xFFFFC928)),
  doubleCoins(Icons.looks_two_rounded, '2x COINS', Color(0xFFFF9F1C));

  const PowerUpType(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
}

class GameObstacle {
  GameObstacle({required this.x, required this.type});

  double x;
  ObstacleType type;
  bool passed = false;
  bool hit = false;
}

class GameCoin {
  GameCoin({required this.x, this.lift = 0.0});

  double x;
  double lift;
  bool collected = false;
}

class GamePowerUp {
  GamePowerUp({required this.x, required this.type});

  double x;
  PowerUpType type;
  bool collected = false;
}

class CoinPopup {
  CoinPopup({required this.x, required this.y, this.text = '+1'});
  final double x;
  final double y;
  final String text;
  double age = 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN GAME WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class CarabaoGamePage extends StatefulWidget {
  const CarabaoGamePage({super.key});

  @override
  State<CarabaoGamePage> createState() => _CarabaoGamePageState();
}

class _CarabaoGamePageState extends State<CarabaoGamePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Sprite frames ──────────────────────────────────────────────────────
  static const _carabaoRunFrames = <String>[
    'assets/images/games/carabao-3d-run-1.png',
    'assets/images/games/carabao-3d-run-2.png',
    'assets/images/games/carabao-3d-run-3.png',
    'assets/images/games/carabao-3d-run-4.png',
    'assets/images/games/carabao-3d-run-5.png',
    'assets/images/games/carabao-3d-run-6.png',
  ];
  static const _farmerRunFrames = <String>[
    'assets/images/games/farmer-3d-run-1.png',
    'assets/images/games/farmer-3d-run-2.png',
    'assets/images/games/farmer-3d-run-3.png',
    'assets/images/games/farmer-3d-run-4.png',
    'assets/images/games/farmer-3d-run-5.png',
    'assets/images/games/farmer-3d-run-6.png',
  ];

  // ── Ground & Layout Constants ──────────────────────────────────────────
  static const _bestScoreKey = 'carabao_runner_best_score';
  static const _groundTop = 0.81; // Unified ground reference plane
  static const _carabaoX = 0.26;
  static const _carabaoWidth = 0.24;
  static const _carabaoHeight = 0.165;
  static const _carabaoAspectRatio = 450 / 384;
  static const _carabaoBottomPaddingFraction = 35 / 384;
  static const _farmerAspectRatio = 1.0;
  static const _farmerBottomPaddingFractions = <double>[
    20 / 384,
    15 / 384,
    52 / 384,
    38 / 384,
    31 / 384,
    55 / 384,
  ];

  // ── State Variables ────────────────────────────────────────────────────
  final _random = math.Random();
  CarabaoGameState _gameState = CarabaoGameState.ready;

  final List<GameObstacle> _obstacles = [];
  final List<GameCoin> _coinsList = [];
  final List<GamePowerUp> _powerUps = [];
  final List<CoinPopup> _coinPopups = [];

  late final AnimationController _gameLoop;
  late final AnimationController _cutsceneController;
  final AudioPlayer _marketAmbiencePlayer = AudioPlayer();
  DateTime? _lastFrame;

  // Jump physics
  double _jumpOffset = 0; // negative is upward
  double _jumpVelocity = 0;
  double _jumpBuffer = 0;
  double _backgroundProgress = 0;
  double _runPhase = 0;
  double _landingEase = 0;

  // Pursuer logic
  double _farmerProximity =
      0.0; // 0.0 = offscreen, 0.55 = close, 0.85 = very close, 1.0 = caught
  int _mistakeCount = 0;
  double _cleanRunningTimer = 0;
  double _stumbleTimer = 0;

  // Power-ups active
  bool _hasShield = false;
  double _magnetTimer = 0;
  double _doubleCoinsTimer = 0;

  // Metrics
  int _score = 0;
  int _coins = 0;
  int _bestScore = 0;
  int _previousBestScore = 0;
  double _distanceRun = 0;
  int _lastMilestoneDistance = 0;
  String _milestoneMessage = '';
  double _milestoneDisplayTimer = 0;

  // Countdown
  int _countdownNumber = 3;
  bool _assetsPrecached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gameLoop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onFrame);
    _cutsceneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );
    _loadBestScore();
  }

  Future<void> _loadBestScore() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _bestScore = preferences.getInt(_bestScoreKey) ?? 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_assetsPrecached) return;
    _assetsPrecached = true;
    precacheImage(
      ResizeImage.resizeIfNeeded(
        1280,
        null,
        const AssetImage(
          'assets/images/games/forest-runner-background-terrain-v2.png',
        ),
      ),
      context,
    );
    for (final frame in [..._carabaoRunFrames, ..._farmerRunFrames]) {
      precacheImage(AssetImage(frame), context);
    }
    precacheImage(
      const AssetImage('assets/images/games/obstacle-rock-3d.png'),
      context,
    );
    precacheImage(
      const AssetImage('assets/images/games/obstacle-log-3d.png'),
      context,
    );
    precacheImage(
      const AssetImage('assets/images/games/obstacle-grass-3d.png'),
      context,
    );
    precacheImage(
      const AssetImage('assets/images/games/carabao_game_over.png'),
      context,
    );
  }

  // ── Spawner with Fair Patterns ─────────────────────────────────────────
  void _spawnInitialWorld() {
    _obstacles.clear();
    _coinsList.clear();
    _powerUps.clear();

    // Spawn a gentle introductory pattern
    _spawnPattern(1.2, isIntro: true);
    _spawnPattern(2.2);
    _spawnPattern(3.2);
  }

  void _spawnPattern(double startX, {bool isIntro = false}) {
    if (isIntro) {
      // The first obstacle teaches the game's only action: jump.
      _obstacles.add(GameObstacle(x: startX, type: ObstacleType.rock));
      _addJumpArc(startX);
      return;
    }

    final distance = _distanceRun;
    final patternRoll = _random.nextInt(100);
    final obstacleTypes = ObstacleType.values;

    if (distance < 300) {
      // Beginner: one clear obstacle and a generous coin arc.
      final type = obstacleTypes[_random.nextInt(obstacleTypes.length)];
      _obstacles.add(GameObstacle(x: startX, type: type));
      _addJumpArc(startX);
    } else if (distance < 700) {
      // Intermediate: varied silhouettes, still one fair jump path.
      final type = obstacleTypes[_random.nextInt(obstacleTypes.length)];
      _obstacles.add(GameObstacle(x: startX, type: type));
      _addJumpArc(startX);
      if (patternRoll >= 72) {
        _coinsList.add(GameCoin(x: startX + 0.34, lift: 0.04));
      }
    } else {
      // Advanced: a readable jump rhythm with enough landing time.
      final type = obstacleTypes[_random.nextInt(obstacleTypes.length)];
      _obstacles.add(GameObstacle(x: startX, type: type));
      _addJumpArc(startX);
      if (patternRoll >= 60) {
        _obstacles.add(
          GameObstacle(
            x: startX + 0.72,
            type: obstacleTypes[_random.nextInt(obstacleTypes.length)],
          ),
        );
        _addJumpArc(startX + 0.72);
      }
    }

    // Rare power-up spawn (every ~200-300m)
    if (_random.nextInt(100) < 16 && _powerUps.isEmpty) {
      final powerUpType =
          PowerUpType.values[_random.nextInt(PowerUpType.values.length)];
      _powerUps.add(GamePowerUp(x: startX + 0.70, type: powerUpType));
    }
  }

  void _addJumpArc(double obstacleX) {
    _coinsList
      ..add(GameCoin(x: obstacleX - 0.12, lift: 0.07))
      ..add(GameCoin(x: obstacleX, lift: 0.15))
      ..add(GameCoin(x: obstacleX + 0.12, lift: 0.07));
  }

  // ── Speed & Difficulty Calculation ─────────────────────────────────────
  double get _speed {
    final distance = _distanceRun;
    if (distance < 300) {
      return 0.36 + (0.08 * (distance / 300));
    } else if (distance < 700) {
      return 0.44 + (0.10 * ((distance - 300) / 400));
    } else if (distance < 1200) {
      return 0.54 + (0.08 * ((distance - 700) / 500));
    } else {
      return 0.62 + (0.08 * math.min(1.0, (distance - 1200) / 1000));
    }
  }

  // ── Environment Progression & Tints ────────────────────────────────────
  String get _currentEnvironmentName {
    final d = _distanceRun;
    if (d < 300) return 'Forest Trail';
    if (d < 600) return 'Farm Path';
    if (d < 900) return 'Rice Field';
    if (d < 1200) return 'Riverside';
    if (d < 1500) return 'Mountain Road';
    if (d < 1800) return 'Barangay Road';
    return 'Sunset Trail';
  }

  Color get _environmentTintColor {
    final d = _distanceRun;
    if (d < 300) return Colors.transparent;
    if (d < 600) {
      // Farm Path: warm golden ambient
      return context.colors.warning.withValues(alpha: 0.05);
    }
    if (d < 900) {
      // Rice Field: fresh green hue
      return context.colors.primaryGreen.withValues(alpha: 0.06);
    }
    if (d < 1200) {
      // Riverside: cool azure breeze
      return context.colors.info.withValues(alpha: 0.06);
    }
    if (d < 1500) {
      // Mountain Road: light amber mist
      return context.colors.warning.withValues(alpha: 0.08);
    }
    if (d < 1800) {
      // Barangay Road: rich afternoon light
      return context.colors.error.withValues(alpha: 0.10);
    }
    // Sunset Trail: dramatic golden-hour glow
    return context.colors.error.withValues(alpha: 0.14);
  }

  // ── Game Frame Loop ────────────────────────────────────────────────────
  void _onFrame() {
    if (_gameState != CarabaoGameState.running &&
        _gameState != CarabaoGameState.stumbling) {
      return;
    }

    final now = DateTime.now();
    final previous = _lastFrame ?? now;
    final seconds = now.difference(previous).inMicroseconds / 1000000;
    final delta = seconds.clamp(0.0, 0.034).toDouble();
    _lastFrame = now;

    // Jump physics
    if (_jumpOffset < 0 || _jumpVelocity < 0) {
      final gravity = _jumpVelocity < 0 ? 3.1 : 2.4;
      _jumpVelocity = math.min(1.1, _jumpVelocity + (gravity * delta));
      _jumpOffset += _jumpVelocity * delta;
      if (_jumpOffset >= 0) {
        _jumpOffset = 0;
        _jumpVelocity = 0;
        _landingEase = 1.0;
      }
    }

    // Jump buffering
    _jumpBuffer = math.max(0, _jumpBuffer - delta);
    if (_jumpBuffer > 0 && _jumpOffset == 0) {
      _jumpVelocity = -1.25;
      _jumpBuffer = 0;
    }

    // Stumble timer
    if (_stumbleTimer > 0) {
      _stumbleTimer -= delta;
      if (_stumbleTimer <= 0 && _gameState == CarabaoGameState.stumbling) {
        _gameState = CarabaoGameState.running;
      }
    }

    // Power-up timers
    if (_magnetTimer > 0) _magnetTimer -= delta;
    if (_doubleCoinsTimer > 0) _doubleCoinsTimer -= delta;

    final currentSpeed = _speed;
    _distanceRun += currentSpeed * delta * 52;
    _backgroundProgress =
        (_backgroundProgress + (currentSpeed * 0.44 * delta)) % 2;
    _runPhase =
        (_runPhase + (delta * (12 + (currentSpeed * 8)))) % (math.pi * 2);
    _landingEase = math.max(0, _landingEase - (delta * 6));

    // Milestone checks (every 250m)
    final distanceMeters = _distanceRun.toInt();
    final milestoneStep = distanceMeters ~/ 250;
    if (milestoneStep > _lastMilestoneDistance && distanceMeters >= 250) {
      _lastMilestoneDistance = milestoneStep;
      _milestoneMessage = '${distanceMeters}M • $_currentEnvironmentName!';
      _milestoneDisplayTimer = 2.0;
      HapticFeedback.mediumImpact();
    }
    if (_milestoneDisplayTimer > 0) {
      _milestoneDisplayTimer -= delta;
    }

    // Farmer Pursuer recovery
    _cleanRunningTimer += delta;
    if (_cleanRunningTimer > 6.0 && _farmerProximity > 0) {
      // Pulling away from farmer smoothly
      _farmerProximity = math.max(0.0, _farmerProximity - (delta * 0.06));
    }

    // Update coin popups
    _coinPopups.removeWhere((p) => p.age > 0.8);
    for (final popup in _coinPopups) {
      popup.age += delta;
    }

    // Move & Recycle Obstacles
    for (final obs in _obstacles) {
      obs.x -= currentSpeed * delta;
      if (!obs.passed && obs.x + obs.type.width < _carabaoX) {
        obs.passed = true;
        _score++;
      }
    }

    // Move & Collect Coins
    final magnetActive = _magnetTimer > 0;
    for (final coin in _coinsList) {
      coin.x -= currentSpeed * delta;

      // Magnet effect: pull coins towards carabao
      if (magnetActive && !coin.collected) {
        final dist = (coin.x - _carabaoX).abs();
        if (dist < 0.35) {
          coin.x += (_carabaoX - coin.x) * (delta * 8);
        }
      }

      if (!coin.collected && _checkCoinPickup(coin)) {
        coin.collected = true;
        final addCoins = _doubleCoinsTimer > 0 ? 2 : 1;
        _coins += addCoins;
        _coinPopups.add(
          CoinPopup(
            x: coin.x,
            y: _groundTop - coin.lift - 0.05,
            text: addCoins == 2 ? '+2 ₱' : '+1 ₱',
          ),
        );
        HapticFeedback.selectionClick();
      }
    }

    // Move & Collect PowerUps
    for (final pu in _powerUps) {
      pu.x -= currentSpeed * delta;
      if (!pu.collected && _checkPowerUpPickup(pu)) {
        pu.collected = true;
        _applyPowerUp(pu.type);
        HapticFeedback.mediumImpact();
      }
    }

    // Clean out offscreen items
    _obstacles.removeWhere((o) => o.x < -0.30);
    _coinsList.removeWhere((c) => c.x < -0.30);
    _powerUps.removeWhere((p) => p.x < -0.30);

    // Spawn new patterns ahead
    final furthestObstacleX = _obstacles.isEmpty
        ? 0.0
        : _obstacles.map((o) => o.x).reduce(math.max);
    if (furthestObstacleX < 2.0) {
      final fairGap = currentSpeed * 1.35; // Guaranteed 1.35s reaction time!
      _spawnPattern(math.max(1.8, furthestObstacleX + fairGap));
    }

    // Collisions
    _checkObstacleCollisions();

    if (mounted) setState(() {});
  }

  void _applyPowerUp(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        _hasShield = true;
        _milestoneMessage = 'SHIELD ACTIVE! 🛡️';
        _milestoneDisplayTimer = 1.8;
      case PowerUpType.magnet:
        _magnetTimer = 10.0;
        _milestoneMessage = 'COIN MAGNET! 🧲';
        _milestoneDisplayTimer = 1.8;
      case PowerUpType.doubleCoins:
        _doubleCoinsTimer = 12.0;
        _milestoneMessage = '2x COINS! 🪙';
        _milestoneDisplayTimer = 1.8;
    }
  }

  bool _checkCoinPickup(GameCoin coin) {
    final coinX = coin.x;
    final carabaoLeft = _carabaoX;
    final carabaoRight = _carabaoX + _carabaoWidth - 0.05;
    if (coinX < carabaoLeft || coinX > carabaoRight) return false;

    // Check vertical reach
    final jumpHeight = -_jumpOffset;
    if (coin.lift > 0.10) {
      // High coin requires jump
      return jumpHeight > 0.04;
    }
    return jumpHeight < 0.12;
  }

  bool _checkPowerUpPickup(GamePowerUp pu) {
    final puX = pu.x;
    return puX >= _carabaoX && puX <= _carabaoX + _carabaoWidth - 0.05;
  }

  void _checkObstacleCollisions() {
    if (_gameState == CarabaoGameState.stumbling) return;

    for (final obs in _obstacles) {
      if (obs.hit) continue;

      // Horizontal overlap
      final obsLeft = obs.x + 0.02;
      final obsRight = obs.x + obs.type.width - 0.02;
      final carabaoLeft = _carabaoX + 0.05;
      final carabaoRight = _carabaoX + _carabaoWidth - 0.05;
      final overlaps = carabaoRight > obsLeft && carabaoLeft < obsRight;
      if (!overlaps) continue;

      // Every obstacle is cleared with the game's single action: jump.
      final jumpHeight = -_jumpOffset;
      if (jumpHeight >= obs.type.height * 0.72) {
        continue;
      }

      // Collision detected!
      obs.hit = true;
      _handleCollision();
      return;
    }
  }

  void _handleCollision() {
    HapticFeedback.heavyImpact();

    // Shield protection check
    if (_hasShield) {
      _hasShield = false;
      _milestoneMessage = 'SHIELD BROKEN! 💥';
      _milestoneDisplayTimer = 1.5;
      return;
    }

    _cleanRunningTimer = 0;
    _mistakeCount++;

    if (_mistakeCount == 1) {
      // First mistake: Farmer rushes in
      _farmerProximity = 0.55;
      _stumbleTimer = 0.6;
      _gameState = CarabaoGameState.stumbling;
      _milestoneMessage = 'FARMER IS CLOSING IN! 🏃';
      _milestoneDisplayTimer = 1.8;
    } else if (_mistakeCount == 2) {
      // Second mistake: Farmer is right behind!
      _farmerProximity = 0.85;
      _stumbleTimer = 0.6;
      _gameState = CarabaoGameState.stumbling;
      _milestoneMessage = 'DANGER! ONE MORE HIT!';
      _milestoneDisplayTimer = 1.8;
    } else {
      // Fatal collision: Farmer catches Carabao!
      _farmerProximity = 1.0;
      _triggerGameOver();
    }
  }

  Future<void> _triggerGameOver() async {
    _gameLoop.stop();
    setState(() => _gameState = CarabaoGameState.gameOver);

    final previousBest = _bestScore;
    final newBest = math.max(_bestScore, _score);
    _previousBestScore = previousBest;
    _bestScore = newBest;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_bestScoreKey, newBest);

    try {
      await _marketAmbiencePlayer.setReleaseMode(ReleaseMode.loop);
      await _marketAmbiencePlayer.setVolume(0.24);
      await _marketAmbiencePlayer.play(
        AssetSource('audio/market_ambience.wav'),
      );
    } catch (_) {}

    await _cutsceneController.forward(from: 0);
    if (mounted) setState(() {});
  }

  // ── Input & Controls ───────────────────────────────────────────────────
  void _jump() {
    if (_gameState == CarabaoGameState.ready) {
      _startRunning();
      return;
    }
    if (_gameState != CarabaoGameState.running &&
        _gameState != CarabaoGameState.stumbling) {
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      if (_jumpOffset == 0) {
        _jumpVelocity = -1.25;
      } else {
        _jumpBuffer = 0.15;
      }
    });
  }

  // ── Game Lifecycle Actions ─────────────────────────────────────────────
  void _startRunning() {
    setState(() {
      _gameState = CarabaoGameState.countdown;
      _countdownNumber = 3;
    });
    _runCountdown();
  }

  Future<void> _runCountdown() async {
    for (var i = 3; i >= 1; i--) {
      if (!mounted || _gameState == CarabaoGameState.gameOver) return;
      setState(() => _countdownNumber = i);
      HapticFeedback.selectionClick();
      await Future.delayed(const Duration(milliseconds: 650));
    }
    if (!mounted || _gameState == CarabaoGameState.gameOver) return;

    setState(() {
      _gameState = CarabaoGameState.running;
      _jumpOffset = 0;
      _jumpVelocity = 0;
      _farmerProximity = 0.0;
      _mistakeCount = 0;
      _cleanRunningTimer = 0;
      _stumbleTimer = 0;
      _score = 0;
      _coins = 0;
      _distanceRun = 0;
      _lastMilestoneDistance = 0;
      _milestoneDisplayTimer = 0;
      _hasShield = false;
      _magnetTimer = 0;
      _doubleCoinsTimer = 0;
      _coinPopups.clear();
      _spawnInitialWorld();
      _lastFrame = DateTime.now();
    });
    _gameLoop.repeat();
  }

  void _togglePause() {
    if (_gameState == CarabaoGameState.running) {
      _gameLoop.stop();
      setState(() => _gameState = CarabaoGameState.paused);
    } else if (_gameState == CarabaoGameState.paused) {
      _startRunning();
    }
  }

  void _runAgain() {
    _marketAmbiencePlayer.stop();
    _cutsceneController.reset();
    _startRunning();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        _gameState == CarabaoGameState.running) {
      _togglePause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameLoop.dispose();
    _cutsceneController.dispose();
    _marketAmbiencePlayer.dispose();
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD METHODS
  // ═════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: _gameState == CarabaoGameState.gameOver
            ? _buildGameOverScreen()
            : Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                      child: _buildGameViewport(),
                    ),
                  ),
                  _buildBottomHud(),
                ],
              ),
      ),
    );
  }

  // ── Header Bar ─────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          _CircleIconBtn(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back to Home',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '// BARILI COUNTRYSIDE RUNNER',
                  style: GoogleFonts.robotoMono(
                    color: dark ? context.colors.textSecondary : context.colors.primaryGreen,
                    fontSize: 9.5,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'CARABAO RUNNER',
                  style: GoogleFonts.poppins(
                    color: context.colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          // Clean Pause button (no confusing restart button!)
          _CircleIconBtn(
            icon: _gameState == CarabaoGameState.paused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            tooltip: _gameState == CarabaoGameState.paused ? 'Resume' : 'Pause',
            onPressed:
                (_gameState == CarabaoGameState.running ||
                    _gameState == CarabaoGameState.paused)
                ? _togglePause
                : null,
          ),
        ],
      ),
    );
  }

  // ── Interactive Game Viewport ──────────────────────────────────────────
  Widget _buildGameViewport() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _jump,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final backgroundWidth = math.max(width, height * 1.78);
            final backgroundLeft = -(_backgroundProgress * backgroundWidth);

            // Sprite run frame indexing
            final runFrame =
                ((_runPhase / (math.pi * 2)) * _carabaoRunFrames.length)
                    .floor() %
                _carabaoRunFrames.length;
            final carabaoFrame = _jumpOffset < -0.015
                ? _carabaoRunFrames[2]
                : _carabaoRunFrames[runFrame];
            final farmerFrame = _farmerRunFrames[runFrame];
            final groundBottom = height * (1 - _groundTop);
            final carabaoRenderedHeight = math.min(
              _carabaoHeight * height,
              (_carabaoWidth * width) / _carabaoAspectRatio,
            );
            final farmerRenderedHeight = math.min(
              height * 0.205,
              (width * 0.21) / _farmerAspectRatio,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                // ── 1. Parallax Scrolling Background ──
                for (var i = 0; i < 3; i++)
                  Positioned(
                    left: backgroundLeft + (backgroundWidth * i),
                    top: 0,
                    width: backgroundWidth + 1,
                    height: height,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(
                        i.isOdd ? -1 : 1,
                        1,
                        1,
                      ),
                      child: Image.asset(
                        'assets/images/games/forest-runner-background-terrain-v2.png',
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),

                // ── 2. Atmospheric & Environment Tints ──
                if (_environmentTintColor != Colors.transparent)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(color: _environmentTintColor),
                    ),
                  ),

                // ── 3. Coins on Ground / Arcs ──
                ..._coinsList.where((c) => !c.collected).map((coin) {
                  return Positioned(
                    left: coin.x * width,
                    bottom: groundBottom + (coin.lift * height),
                    width: width * 0.052,
                    height: width * 0.052,
                    child: _CoinView(phase: _runPhase + (coin.x * 3)),
                  );
                }),

                // ── 4. Power-Up Pickups ──
                ..._powerUps.where((p) => !p.collected).map((pu) {
                  return Positioned(
                    left: pu.x * width,
                    bottom: groundBottom + (height * 0.02),
                    width: 34,
                    height: 34,
                    child: _PowerUpPickupView(type: pu.type),
                  );
                }),

                // ── 5. Obstacle Shadows & Sprites ──
                ..._obstacles.map((obs) {
                  final renderedHeight = math.min(
                    obs.type.height * height,
                    (obs.type.width * width) / obs.type.assetAspectRatio,
                  );
                  final paddingCompensation =
                      renderedHeight * obs.type.bottomPaddingFraction;

                  return Positioned(
                    left: obs.x * width,
                    bottom: groundBottom - paddingCompensation,
                    width: obs.type.width * width,
                    height: obs.type.height * height,
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: [
                        // Ground Contact Shadow directly under obstacle base
                        Positioned(
                          left: obs.type.width * width * 0.1,
                          bottom: paddingCompensation,
                          width: obs.type.width * width * 0.8,
                          height: height * 0.016,
                          child: const _ContactShadow(opacity: 0.38),
                        ),
                        Image.asset(
                          obs.type.asset,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                        ),
                      ],
                    ),
                  );
                }),

                // ── 6. Farmer Pursuer (Grounded with Contact Shadow) ──
                if (_farmerProximity > 0.05)
                  Positioned(
                    left: width * (-0.22 + (0.42 * _farmerProximity)),
                    bottom:
                        groundBottom -
                        (farmerRenderedHeight *
                            _farmerBottomPaddingFractions[runFrame]),
                    width: width * 0.21,
                    height: height * 0.205,
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: [
                        // Contact shadow under farmer's boots
                        Positioned(
                          left: width * 0.04,
                          bottom:
                              farmerRenderedHeight *
                              _farmerBottomPaddingFractions[runFrame],
                          width: width * 0.13,
                          height: height * 0.018,
                          child: const _ContactShadow(opacity: 0.42),
                        ),
                        Image.asset(
                          farmerFrame,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                        ),
                      ],
                    ),
                  ),

                // ── 7. Carabao Contact Shadow (Anchored to Ground) ──
                Positioned(
                  left: (_carabaoX + 0.04) * width,
                  bottom: groundBottom,
                  width: (_carabaoWidth - 0.08) * width,
                  height: height * 0.022,
                  child: Opacity(
                    opacity: (0.48 - (-_jumpOffset * 1.8)).clamp(0.12, 0.48),
                    child: Transform.scale(
                      scale: (1.0 - (-_jumpOffset * 0.9)).clamp(0.65, 1.0),
                      child: const _ContactShadow(opacity: 0.45),
                    ),
                  ),
                ),

                // ── 8. Carabao Hero Sprite ──
                Positioned(
                  left: _carabaoX * width,
                  bottom:
                      groundBottom -
                      (_jumpOffset * height) -
                      (carabaoRenderedHeight * _carabaoBottomPaddingFraction),
                  width: _carabaoWidth * width,
                  height: _carabaoHeight * height,
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.diagonal3Values(
                      1 + (_landingEase * 0.05),
                      1 - (_landingEase * 0.06),
                      1,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.center,
                      children: [
                        // Shield Aura Effect
                        if (_hasShield)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.colors.primaryGreen,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.colors.brandStrong
                                        .withValues(alpha: 0.4000),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Stumble blink
                        Opacity(
                          opacity:
                              (_gameState == CarabaoGameState.stumbling &&
                                  math.sin(_runPhase * 6) > 0)
                              ? 0.4
                              : 1.0,
                          child: Image.asset(
                            carabaoFrame,
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 9. Coin Collect Popups (+1 ₱) ──
                ..._coinPopups.map(
                  (popup) => Positioned(
                    left: popup.x * width,
                    top: height * (popup.y - (popup.age * 0.07)),
                    child: Opacity(
                      opacity: (1 - (popup.age / 0.8)).clamp(0.0, 1.0),
                      child: Text(
                        popup.text,
                        style: GoogleFonts.poppins(
                          color: context.colors.warning,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(color: context.colors.textPrimary, blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── 10. In-Game Live HUD & Active Buffs ──
                if (_gameState == CarabaoGameState.running ||
                    _gameState == CarabaoGameState.stumbling)
                  _buildLiveHud(),

                // ── 11. Milestone / Speed-Up Pill Toast ──
                if (_milestoneDisplayTimer > 0)
                  Positioned(
                    top: 50,
                    left: 20,
                    right: 20,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              context.colors.brand,
                              context.colors.brand,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.brandStrong.withValues(
                                alpha: 0.3333,
                              ),
                              blurRadius: 12,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          _milestoneMessage,
                          style: GoogleFonts.poppins(
                            color: context.colors.onAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── 12. Countdown Overlay (3, 2, 1) ──
                if (_gameState == CarabaoGameState.countdown)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.35),
                      child: Center(
                        child: Text(
                          '$_countdownNumber',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.w900,
                            shadows: const [
                              Shadow(color: Color(0xFF34D399), blurRadius: 28),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── 13. State Overlays: Ready or Paused ──
                if (_gameState == CarabaoGameState.ready) _buildReadyOverlay(),
                if (_gameState == CarabaoGameState.paused)
                  _buildPausedOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Live In-Game HUD ───────────────────────────────────────────────────
  Widget _buildLiveHud() {
    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Metrics Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF092319).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF34D399).withValues(alpha: 0.40),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.straighten_rounded,
                  color: Color(0xFF6EE7B7),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_distanceRun.toInt()}m',
                  style: GoogleFonts.robotoMono(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.monetization_on_rounded,
                  color: Color(0xFFFBBF24),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_coins',
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFFFDE68A),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          // Active Power-Up Badges
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasShield)
                _buildActiveBadge(
                  Icons.shield_rounded,
                  'SHIELD',
                  const Color(0xFF059669),
                ),
              if (_magnetTimer > 0)
                _buildActiveBadge(
                  Icons.all_inclusive_rounded,
                  '${_magnetTimer.toInt()}s',
                  const Color(0xFFD97706),
                ),
              if (_doubleCoinsTimer > 0)
                _buildActiveBadge(
                  Icons.looks_two_rounded,
                  '${_doubleCoinsTimer.toInt()}s',
                  const Color(0xFFD97706),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveBadge(IconData icon, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 3),
          Text(
            text,
            style: GoogleFonts.robotoMono(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ── Ready to Run Overlay (FIRST OPEN) ──────────────────────────────────
  Widget _buildReadyOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.32),
        alignment: const Alignment(0, -0.34),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF092319).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF34D399).withValues(alpha: 0.65),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.pets_rounded,
                color: Color(0xFF6EE7B7),
                size: 34,
              ),
              const SizedBox(height: 6),
              Text(
                'Ready to Run?',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              // The runner deliberately has one clear, accessible action.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF04150E).withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: 0.30),
                    width: 1.0,
                  ),
                ),
                child: _buildControlGuideRow(
                  Icons.touch_app_rounded,
                  'Tap to Jump',
                  'Clear Every Obstacle',
                ),
              ),
              const SizedBox(height: 16),
              // [ START RUNNING ] Button — strictly no "RUN AGAIN" before playing!
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _startRunning,
                  icon: const Icon(Icons.play_arrow_rounded, size: 22, color: Colors.white),
                  label: const Text('START RUNNING'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    textStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 4,
                    shadowColor: const Color(0xFF059669).withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlGuideRow(IconData icon, String title, String desc) {
    return Row(
      children: [
        const Icon(Icons.touch_app_rounded, color: Color(0xFF6EE7B7), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                desc,
                style: GoogleFonts.poppins(
                  color: const Color(0xFFA7F3D0),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Paused Overlay ─────────────────────────────────────────────────────
  Widget _buildPausedOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.50),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: BoxDecoration(
              color: const Color(0xFF092319).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF34D399).withValues(alpha: 0.70),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.pause_circle_rounded,
                  color: Color(0xFF6EE7B7),
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  'PAUSED',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _togglePause,
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                  label: const Text('RESUME'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom HUD & Touch Controls ────────────────────────────────────────
  Widget _buildBottomHud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton.icon(
          onPressed: _jump,
          icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 22, color: Colors.white),
          label: const Text('JUMP'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: const Color(0xFF059669).withValues(alpha: 0.5),
            textStyle: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
    );
  }

  // ── Game Over Screen (Shown ONLY after losing) ──────────────────────────
  Widget _buildGameOverScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final isCompact = screenHeight < 680;

        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: context.colors.disabledBackground,
            gradient: RadialGradient(
              center: Alignment(0, -0.2),
              radius: 1.3,
              colors: [
                context.colors.brandStrong,
                context.colors.disabledBackground,
                context.colors.shadow,
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              isCompact ? 8 : 12,
              16,
              isCompact ? 10 : 16,
            ),
            child: Column(
              children: [
                Text(
                  'GAME OVER',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: isCompact ? 26 : 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 12),
                    ],
                  ),
                ),
                SizedBox(height: isCompact ? 6 : 10),
                // Game Over artwork
                Expanded(
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: context.colors.primaryGreen.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: 0.4667),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18.5),
                        child: Image.asset(
                          'assets/images/games/carabao_game_over.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isCompact ? 8 : 12),
                // Results Card
                _buildResultsCard(isCompact: isCompact),
                SizedBox(height: isCompact ? 8 : 12),
                // Buttons: RUN AGAIN & BACK TO HOME
                _buildGameOverButtons(isCompact: isCompact),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultsCard({bool isCompact = false}) {
    final hasNewBest = _score > _previousBestScore && _score > 0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 16,
        vertical: isCompact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF092319).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF34D399).withValues(alpha: 0.70),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatPod(
                  icon: Icons.emoji_events_rounded,
                  label: 'SCORE',
                  value: '$_score',
                  accentColor: context.colors.warningSolid,
                  isCompact: isCompact,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatPod(
                  icon: Icons.monetization_on_rounded,
                  label: 'COINS',
                  value: '$_coins',
                  accentColor: context.colors.warningSolid,
                  isCompact: isCompact,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 8 : 10),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFBBF24),
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'BEST',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF6EE7B7),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_bestScore',
                      style: GoogleFonts.robotoMono(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (hasNewBest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'NEW BEST!',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF051912).withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.straighten_rounded,
                      size: 13,
                      color: Color(0xFF6EE7B7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_distanceRun.toInt()}m',
                      style: GoogleFonts.robotoMono(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPod({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
    required bool isCompact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 12,
        vertical: isCompact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF051912).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.40)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: isCompact ? 18 : 22),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF6EE7B7),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: isCompact ? 18 : 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverButtons({bool isCompact = false}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary: RUN AGAIN — strictly shown after Game Over
        SizedBox(
          width: double.infinity,
          height: isCompact ? 46 : 50,
          child: FilledButton.icon(
            onPressed: _runAgain,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: const Text('RUN AGAIN'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              textStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ),
        SizedBox(height: isCompact ? 6 : 8),
        // Secondary: return to the app home screen.
        SizedBox(
          width: double.infinity,
          height: isCompact ? 40 : 44,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_rounded,
              size: 16,
              color: dark ? Colors.white : context.colors.textPrimary,
            ),
            label: const Text('BACK TO HOME'),
            style: OutlinedButton.styleFrom(
              backgroundColor: dark ? context.colors.surfaceAlt : Colors.white,
              foregroundColor: dark ? Colors.white : context.colors.textPrimary,
              side: BorderSide(
                color: dark ? context.colors.border : context.colors.border.withValues(alpha: 0.8),
                width: 1.2,
              ),
              textStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPER VISUAL WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _CircleIconBtn extends StatelessWidget {
  const _CircleIconBtn({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = enabled
        ? (dark ? Colors.white : context.colors.textPrimary)
        : context.colors.disabled;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark
                ? context.colors.surfaceAlt
                : Colors.white,
            border: Border.all(
              color: dark
                  ? context.colors.border.withValues(alpha: 0.40)
                  : context.colors.border.withValues(alpha: 0.65),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadow.withValues(alpha: dark ? 0.30 : 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _ContactShadow extends StatelessWidget {
  const _ContactShadow({required this.opacity});
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.shadow.withValues(alpha: opacity),
        borderRadius: const BorderRadius.all(Radius.elliptical(100, 18)),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: opacity * 0.4),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _CoinView extends StatelessWidget {
  const _CoinView({required this.phase});
  final double phase;

  @override
  Widget build(BuildContext context) {
    final spinWidth = (0.25 + (math.sin(phase).abs() * 0.75)).clamp(0.25, 1.0);
    return Transform.scale(
      scaleX: spinWidth,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: Alignment(-0.3, -0.3),
            colors: [
              context.colors.warningSurface,
              context.colors.warningSolid,
              context.colors.warningSolid,
            ],
          ),
          border: Border.all(color: context.colors.border, width: 1.2),
          boxShadow: [BoxShadow(color: context.colors.highlight.withValues(alpha: 0.4000), blurRadius: 6,
            ),
          ],
        ),
        child: Center(
          child: FittedBox(
            child: Text(
              '₱',
              style: GoogleFonts.robotoMono(
                color: context.colors.warning,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PowerUpPickupView extends StatelessWidget {
  const _PowerUpPickupView({required this.type});
  final PowerUpType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: type.color,
        border: Border.all(color: context.colors.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: type.color.withValues(alpha: 0.6),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(child: Icon(type.icon, color: context.colors.onAccent, size: 18),
      ),
    );
  }
}
