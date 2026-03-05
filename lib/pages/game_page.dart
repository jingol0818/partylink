import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/game_room.dart';
import '../models/game_player.dart';
import '../models/game_chat_message.dart';
import '../services/game_service.dart';
import '../services/game_chat_service.dart';
import '../services/game_realtime_service.dart';
import '../services/session_service.dart';
import '../services/gm_service.dart';
import '../services/profanity_filter_service.dart';
import '../services/trap_card_service.dart';
import '../services/stats_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_icon.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/phase_timer.dart';
import '../widgets/trap_card_widget.dart';
import '../widgets/result_reveal_widget.dart';

/// 게임 메인 화면 (/game/:code)
///
/// 5개 phase를 하나의 StatefulWidget에서 관리:
/// waiting → chatting → trap_question (3인+) → voting → result
///
/// 비주얼 가이드 적용: 라운드별 파스텔 그라데이션 배경,
/// 라운드 전환 풀스크린 오버레이, 아바타 바운스 등
class GamePage extends StatefulWidget {
  final String code;
  final String? gameId;
  final String? playerId;

  const GamePage({
    super.key,
    required this.code,
    this.gameId,
    this.playerId,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with TickerProviderStateMixin {
  final _gameService = GameService();
  final _chatService = GameChatService();
  final _realtimeService = GameRealtimeService();
  final _trapCardService = TrapCardService();
  final _statsService = StatsService();
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
  final _chatFocusNode = FocusNode();

  GameRoom? _game;
  List<GamePlayer> _players = [];
  List<GameChatMessage> _messages = [];
  String? _myPlayerId;
  String? _gameId;
  bool _loading = true;
  String? _error;

  // 타이머
  Timer? _phaseTimer;
  Duration _remaining = Duration.zero;
  Duration _totalPhaseTime = Duration.zero;

  // 투표
  String? _selectedVoteTarget;
  bool _hasVoted = false;

  // 채팅 쿨다운
  DateTime? _lastSentAt;

  // 준비 완료
  bool _isReady = false;
  int _readyCountdown = 0;
  Timer? _readyTimer;

  // Realtime 구독
  StreamSubscription? _realtimeSub;
  StreamSubscription? _chatSub;

  // 게임 시작 처리 플래그
  bool _gameStarted = false;

  // 침묵 감지 타이머
  Timer? _silenceTimer;

  // GM 오버레이 메시지 (순차 표시)
  String? _gmOverlayText;
  bool _showGmOverlay = false;

  // AI 자동 채팅 타이머 + 타이핑 표시
  Timer? _aiChatTimer;
  bool _aiTyping = false;

  // 결과 처리 플래그
  bool _statsUpdated = false;

  // 라운드 전환 오버레이
  bool _showRoundTransition = false;
  String _transitionMain = '';
  String _transitionSub = '';

  // 현재 라운드 테마 (파스텔 그라데이션)
  GameRoundTheme _currentTheme = GameRoundTheme.waiting;

  // 아바타 바운스 (sender_id → 트리거)
  String? _bouncingPlayerId;

  // 바운스 애니메이션 컨트롤러
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  // 라운드 전환 애니메이션 컨트롤러
  late AnimationController _transitionController;
  late Animation<double> _transitionScale;
  late Animation<double> _transitionOpacity;

  GamePlayer? get _me {
    if (_myPlayerId == null) return null;
    final matches = _players.where((p) => p.id == _myPlayerId);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  void initState() {
    super.initState();
    _myPlayerId = widget.playerId ?? SessionService.memberId;
    _gameId = widget.gameId;

    // 바운스 애니메이션
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.15)
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(_bounceController);

    // 라운드 전환 애니메이션
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _transitionScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _transitionController, curve: Curves.elasticOut),
    );
    _transitionOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _transitionController, curve: Curves.easeIn),
    );

    _init();
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _readyTimer?.cancel();
    _silenceTimer?.cancel();
    _aiChatTimer?.cancel();
    _realtimeSub?.cancel();
    _chatSub?.cancel();
    _bounceController.dispose();
    _transitionController.dispose();
    _realtimeService.dispose();
    _chatService.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    _chatFocusNode.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      GameRoom? game;
      if (_gameId != null) {
        game = await _gameService.getGameById(_gameId!);
      }
      game ??= await _gameService.getGameByCode(widget.code);

      if (game == null) {
        setState(() {
          _error = '게임을 찾을 수 없습니다.';
          _loading = false;
        });
        return;
      }

      _gameId = game.id;
      _game = game;
      _currentTheme = GameRoundTheme.fromGame(game.phase, game.round);

      _players = await _gameService.getPlayers(game.id);

      if (_myPlayerId == null) {
        final myPlayer = _players.where(
          (p) => p.sessionId == SessionService.sessionId,
        );
        if (myPlayer.isNotEmpty) {
          _myPlayerId = myPlayer.first.id;
        }
      }

      _messages = await _chatService.getMessages(game.id);

      _realtimeService.subscribeToGame(game.id);
      _chatService.subscribeToGame(game.id);

      _realtimeSub = _realtimeService.onChanged.listen((_) => _refresh());
      _chatSub = _chatService.onMessage.listen(_onNewMessage);

      setState(() => _loading = false);
      _startPhaseTimer();

      if (game.isWaiting && !_gameStarted) {
        _gameStarted = true;
        _autoStartGame();
      }
    } catch (e) {
      setState(() {
        _error = '초기화 실패: $e';
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    if (_gameId == null) return;
    try {
      final game = await _gameService.getGameById(_gameId!);
      final players = await _gameService.getPlayers(_gameId!);

      if (mounted) {
        final prevPhase = _game?.phase;
        setState(() {
          _game = game;
          _players = players;
        });

        // 페이즈 변경 감지
        if (prevPhase != game?.phase) {
          SoundService.phaseChange();

          // 라운드 전환 오버레이 표시
          if (game != null) {
            _showPhaseTransition(game.phase, game.round);
            _currentTheme = GameRoundTheme.fromGame(game.phase, game.round);
          }

          _startPhaseTimer();

          if (game?.isChatting == true) {
            _resetSilenceTimer();
            _startAiAutoChat();
          } else {
            _silenceTimer?.cancel();
            _stopAiAutoChat();
          }

          if (game?.isVoting == true) {
            setState(() {
              _selectedVoteTarget = null;
              _hasVoted = false;
            });
          }

          if (game?.isResult == true) {
            SoundService.resultReveal();
            final msgs = await _chatService.getMessages(_gameId!);
            if (mounted) setState(() => _messages = msgs);
            _updateStats();
          }
        }
      }
    } catch (_) {}
  }

  /// 라운드 전환 풀스크린 오버레이 (2초)
  Future<void> _showPhaseTransition(String phase, int round) async {
    final text = GameRoundTheme.transitionText(phase, round);
    setState(() {
      _transitionMain = text.main;
      _transitionSub = text.sub;
      _showRoundTransition = true;
    });
    _transitionController.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) {
      _transitionController.reverse();
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) setState(() => _showRoundTransition = false);
    }
  }

  void _onNewMessage(GameChatMessage msg) {
    if (!mounted) return;

    if (msg.senderId == _myPlayerId) {
      final localIdx = _messages.indexWhere(
        (m) => m.id.startsWith('local_') && m.content == msg.content,
      );
      if (localIdx >= 0) {
        setState(() => _messages[localIdx] = msg);
      } else {
        setState(() => _messages.add(msg));
      }
    } else {
      setState(() => _messages.add(msg));
      SoundService.messageReceived();

      // 아바타 바운스 트리거
      if (!msg.isGm) {
        _triggerBounce(msg.senderId);
      }
    }

    _scrollToBottom();

    if (_game?.isChatting == true) {
      _resetSilenceTimer();
    }
  }

  /// 아바타 바운스 애니메이션 트리거
  void _triggerBounce(String? playerId) {
    if (playerId == null) return;
    setState(() => _bouncingPlayerId = playerId);
    _bounceController.forward(from: 0).then((_) {
      _bounceController.reverse().then((_) {
        if (mounted) setState(() => _bouncingPlayerId = null);
      });
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- 침묵 감지 ---

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 15), () {
      if (_gameId != null && _game?.isChatting == true) {
        GmService.nudgeSilence(_gameId!, _game?.round ?? 1);
      }
    });
  }

  // --- AI 자동 채팅 ---
  //
  // AI는 기본적으로 "반응형":
  //   1) 채팅 시작 시 1회 인사만 자동 트리거
  //   2) 이후에는 사람이 메시지를 보낼 때만 응답
  //   3) 사람이 오래 침묵하면(20초) 1회 넛지
  //
  void _startAiAutoChat() {
    _aiChatTimer?.cancel();
    // 채팅 시작 후 2~3초 뒤 AI 첫 인사 1회만
    _aiChatTimer = Timer(Duration(seconds: 2 + Random().nextInt(2)), () {
      _triggerAiChat();
      // 주기적 반복 없음! 이후는 사람 메시지에 반응
      // 대신 사람이 오래 침묵하면 1회 넛지
      _startAiNudgeTimer();
    });
  }

  /// 사람이 20초 이상 침묵하면 AI가 1회 말 걸기
  Timer? _aiNudgeTimer;
  void _startAiNudgeTimer() {
    _aiNudgeTimer?.cancel();
    _aiNudgeTimer = Timer(const Duration(seconds: 20), () {
      if (_gameId != null && _game?.isChatting == true) {
        _triggerAiChat();
        // 넛지 후 다시 30초 대기 (무한 도배 방지)
        _aiNudgeTimer = Timer(const Duration(seconds: 30), () {
          if (_gameId != null && _game?.isChatting == true) {
            _triggerAiChat();
          }
        });
      }
    });
  }

  /// 사람이 메시지를 보내면 넛지 타이머 리셋
  void _resetAiNudgeTimer() {
    if (_game?.isChatting == true) {
      _startAiNudgeTimer();
    }
  }

  void _stopAiAutoChat() {
    _aiChatTimer?.cancel();
    _aiChatTimer = null;
    _aiNudgeTimer?.cancel();
    _aiNudgeTimer = null;
  }

  Future<void> _triggerAiChat() async {
    if (_gameId == null || _game?.isChatting != true) return;
    if (mounted) setState(() => _aiTyping = true);

    // 최대 3번 재시도
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final result = await _gameService.triggerAiResponse(_gameId!);
        // ignore: avoid_print
        print('[GamePage] AI trigger result: $result');
        break;
      } catch (e) {
        // ignore: avoid_print
        print('[GamePage] AI trigger attempt ${attempt + 1} failed: $e');
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: 1 + attempt));
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _aiTyping = false);
  }

  // --- GM 오버레이 순차 표시 ---

  Future<void> _showGmSequence(List<String> messages) async {
    for (final text in messages) {
      if (!mounted) return;
      setState(() {
        _gmOverlayText = text;
        _showGmOverlay = true;
      });
      await Future.delayed(const Duration(milliseconds: 2000));
    }
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => _showGmOverlay = false);
    }
  }

  // --- 통계 업데이트 ---

  Future<void> _updateStats() async {
    if (_statsUpdated || _gameId == null || _me == null) return;
    _statsUpdated = true;
    try {
      final myScore = _me!.score;
      final won = myScore > 0;
      await _statsService.updateStats(
        sessionId: SessionService.sessionId,
        displayName: _me!.nickname,
        score: myScore,
        won: won,
      );
    } catch (_) {}
  }

  // --- 게임 흐름 ---

  Future<void> _autoStartGame() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted || _gameId == null) return;

    final topic = _game?.topic ?? '자유 대화';
    final playerCount = _game?.playerCount ?? 2;
    final chatTime = switch (playerCount) { <= 2 => 90, 3 => 120, 4 => 150, _ => 180 };

    SoundService.gameStart();

    await GmService.announceGameStart(
      _gameId!, topic, _game?.round ?? 1,
      playerCount: playerCount,
    );
    await _gameService.advancePhase(_gameId!, 'chatting');

    // 테마 즉시 전환
    setState(() {
      _currentTheme = GameRoundTheme.fromGame('chatting', _game?.round ?? 1);
    });

    await _refresh();

    // 라운드 전환 오버레이
    _showPhaseTransition('chatting', _game?.round ?? 1);

    // GM 메시지 (오버레이 후)
    await Future.delayed(const Duration(milliseconds: 2200));
    _showGmSequence([
      '🎮 게임을 시작합니다!',
      '🤖 이 중에 AI가 숨어 있습니다',
      '💬 주제: "$topic"',
      '⏱️ 대화 시간: ${chatTime}초',
    ]);

    _startAiAutoChat();
  }

  void _startPhaseTimer() {
    _phaseTimer?.cancel();

    if (_game?.phaseEndsAt == null) {
      setState(() => _remaining = Duration.zero);
      return;
    }

    if (_game!.isChatting) {
      _totalPhaseTime = Duration(seconds: _game!.chattingSeconds);
    } else if (_game!.isVoting) {
      _totalPhaseTime = Duration(seconds: _game!.votingSeconds);
    } else if (_game!.isTrapQuestion) {
      _totalPhaseTime = const Duration(seconds: 15);
    } else {
      _totalPhaseTime = Duration.zero;
    }

    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now().toUtc();
      final end = _game!.phaseEndsAt!;
      final diff = end.difference(now);

      if (diff.isNegative) {
        _phaseTimer?.cancel();
        _onPhaseTimeout();
      } else {
        if (mounted) {
          setState(() => _remaining = diff);
          if (diff.inSeconds <= 10 && diff.inSeconds > 0) {
            SoundService.timerWarning();
          }
        }
      }
    });

    final now = DateTime.now().toUtc();
    final end = _game!.phaseEndsAt!;
    _remaining = end.difference(now);
    if (_remaining.isNegative) _remaining = Duration.zero;
  }

  Future<void> _onPhaseTimeout() async {
    if (_gameId == null) return;

    if (_game?.isChatting == true) {
      if ((_game?.playerCount ?? 2) >= 3) {
        await _startTrapQuestion();
      } else {
        await _startVoting();
      }
    } else if (_game?.isTrapQuestion == true) {
      await _startVoting();
    } else if (_game?.isVoting == true) {
      await _finishVoting();
    }
  }

  Future<void> _startTrapQuestion() async {
    if (_gameId == null || _me == null) return;
    final others = _players.where((p) => p.id != _myPlayerId).toList();
    if (others.isEmpty) {
      await _startVoting();
      return;
    }
    others.shuffle();
    final target = others.first;

    try {
      await _trapCardService.drawCard(
        gameId: _gameId!,
        round: _game?.round ?? 1,
        askerId: _myPlayerId!,
        targetId: target.id,
      );
    } catch (_) {}

    await GmService.announceTrapQuestion(
      _gameId!, _me!.nickname, target.nickname, _game?.round ?? 1,
    );

    await _gameService.advancePhase(_gameId!, 'trap_question');
    await _refresh();
  }

  Future<void> _startVoting() async {
    if (_gameId == null) return;
    final playerCount = _game?.playerCount ?? 2;
    await GmService.announceVoting(
      _gameId!, _game?.round ?? 1,
      playerCount: playerCount,
    );
    await _gameService.advancePhase(_gameId!, 'voting');
    await _refresh();
  }

  void _onReady() {
    if (_isReady) return;
    setState(() {
      _isReady = true;
      _readyCountdown = 3;
    });

    _readyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _readyCountdown--);
      if (_readyCountdown <= 0) {
        timer.cancel();
        _onPhaseTimeout();
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _myPlayerId == null || _gameId == null) return;
    if (text.length > 100) return;

    if (_lastSentAt != null) {
      final diff = DateTime.now().difference(_lastSentAt!);
      if (diff.inMilliseconds < 1000) return;
    }

    if (ProfanityFilterService.containsProfanity(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('부적절한 표현이 포함되어 있습니다.')),
      );
      return;
    }

    _chatController.clear();
    _lastSentAt = DateTime.now();

    final localMsg = GameChatMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      gameId: _gameId!,
      senderId: _myPlayerId,
      senderType: 'player',
      nickname: _me?.nickname ?? '???',
      content: text,
      round: _game?.round ?? 1,
      createdAt: DateTime.now(),
    );
    setState(() => _messages.add(localMsg));
    _scrollToBottom();

    try {
      await _chatService.sendMessage(
        gameId: _gameId!,
        senderId: _myPlayerId!,
        nickname: _me?.nickname ?? '???',
        content: text,
        round: _game?.round ?? 1,
      );

      _resetAiNudgeTimer(); // 사람이 말했으니 넛지 타이머 리셋
      setState(() => _aiTyping = true);
      _scrollToBottom();
      // 메시지 저장 후 살짝 딜레이 → AI가 최신 메시지 읽을 수 있게
      Future.delayed(const Duration(milliseconds: 500), () async {
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            final result = await _gameService.triggerAiResponse(_gameId!);
            // ignore: avoid_print
            print('[GamePage] post-send AI result: $result');
            break;
          } catch (e) {
            // ignore: avoid_print
            print('[GamePage] post-send AI attempt ${attempt + 1} failed: $e');
            if (attempt < 2) {
              await Future.delayed(Duration(seconds: 1 + attempt));
            }
          }
        }
        if (mounted) setState(() => _aiTyping = false);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m.id == localMsg.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('메시지 전송 실패: $e')),
        );
      }
    }
  }

  Future<void> _castVote() async {
    if (_selectedVoteTarget == null || _myPlayerId == null || _gameId == null) return;
    if (_hasVoted) return;

    final success = await _gameService.castVote(_myPlayerId!, _selectedVoteTarget!);
    if (success) {
      SoundService.vote();
      setState(() => _hasVoted = true);
      if ((_game?.playerCount ?? 2) <= 2) {
        await _finishVoting();
      }
    }
  }

  Future<void> _finishVoting() async {
    if (_gameId == null) return;
    await _gameService.aiAutoVote(_gameId!);
    await _gameService.calculateScore(_gameId!);
    await GmService.announceResult(_gameId!, _game?.round ?? 1);
    await _gameService.advancePhase(_gameId!, 'result');
    await _refresh();
  }

  Future<void> _nextRound() async {
    if (_gameId == null) return;
    await _gameService.advanceToNextRound(_gameId!);
    await GmService.announceNextRound(_gameId!, (_game?.round ?? 1) + 1);
    await _gameService.advancePhase(_gameId!, 'chatting');

    setState(() {
      _hasVoted = false;
      _selectedVoteTarget = null;
      _isReady = false;
      _statsUpdated = false;
    });

    await _refresh();
  }

  Future<void> _playAgain() async {
    if (mounted) context.go('/');
  }

  // ================================================================
  // UI 빌드 — 파스텔 그라데이션 배경 + 라운드 전환 오버레이
  // ================================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();
    if (_error != null) return _buildError();
    if (_game == null) return _buildError();

    final theme = _currentTheme;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.gradient,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 메인 콘텐츠
              switch (_game!.phase) {
                'waiting' => _buildWaitingPhase(),
                'chatting' => _buildChattingPhase(),
                'trap_question' => _buildTrapQuestionPhase(),
                'voting' => _buildVotingPhase(),
                'result' => _buildResultPhase(),
                _ => _buildChattingPhase(),
              },

              // 라운드 전환 풀스크린 오버레이
              if (_showRoundTransition) _buildRoundTransitionOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  /// 라운드 전환 풀스크린 오버레이 (2초)
  Widget _buildRoundTransitionOverlay() {
    return AnimatedBuilder(
      animation: _transitionController,
      builder: (context, _) {
        return Container(
          color: Colors.black.withAlpha((_transitionOpacity.value * 180).toInt()),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _transitionScale,
                  child: Text(
                    _transitionMain,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeTransition(
                  opacity: _transitionOpacity,
                  child: Text(
                    _transitionSub,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha(200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoading() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: CyberColors.accentTeal),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? '알 수 없는 오류',
                style: const TextStyle(color: CyberColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CyberColors.accentTeal,
                  foregroundColor: Colors.white,
                ),
                child: const Text('로비로 돌아가기'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Waiting Phase ---

  Widget _buildWaitingPhase() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: CyberColors.accentTeal,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '게임 준비 중...',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _currentTheme.textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_players.length}명 참가',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: _currentTheme.subTextColor,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: _players.map((p) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AvatarIcon(
                    shape: p.avatarShape,
                    colorHex: p.avatarColor,
                    size: 48,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.nickname,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      color: _currentTheme.subTextColor,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- Chatting Phase (파스텔 배경 + 라이트 모드) ---

  Widget _buildChattingPhase() {
    final chatMessages = _messages.where((m) => !m.isGm).toList();
    final theme = _currentTheme;

    return Stack(
      children: [
        Column(
          children: [
            _buildTopBar(),

            // 참가자 아바타 바 (바운스 지원)
            _buildPlayerAvatarBar(),

            // 메시지 목록
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: chatMessages.length + (_aiTyping ? 1 : 0),
                itemBuilder: (_, i) {
                  if (_aiTyping && i == chatMessages.length) {
                    return _buildTypingIndicator();
                  }

                  final msg = chatMessages[i];
                  final isMine = msg.senderId == _myPlayerId;

                  String? shape;
                  String? color;
                  if (!isMine) {
                    final sender = _players.where((p) => p.id == msg.senderId);
                    if (sender.isNotEmpty) {
                      shape = sender.first.avatarShape;
                      color = sender.first.avatarColor;
                    }
                  }

                  return ChatBubble(
                    message: msg,
                    isMine: isMine,
                    avatarShape: shape,
                    avatarColor: color,
                    theme: theme,
                  );
                },
              ),
            ),

            _buildChatInput(),
          ],
        ),

        // GM 오버레이
        if (_showGmOverlay && _gmOverlayText != null)
          Positioned(
            top: 120,
            left: 24,
            right: 24,
            child: AnimatedOpacity(
              opacity: _showGmOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.gmOverlayBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(80),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _gmOverlayText!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.gmTextColor,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 참가자 아바타 가로 바 (메시지 수신 시 바운스)
  Widget _buildPlayerAvatarBar() {
    final theme = _currentTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.topBarBg.withAlpha(100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _players.map((p) {
          final isBouncing = _bouncingPlayerId == p.id;
          final isMe = p.id == _myPlayerId;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    final scale = isBouncing ? _bounceAnimation.value : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: isMe
                          ? Border.all(color: CyberColors.accentTeal, width: 2)
                          : null,
                    ),
                    child: AvatarIcon(
                      shape: p.avatarShape,
                      colorHex: p.avatarColor,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isMe ? '나' : p.nickname.length > 4
                      ? '${p.nickname.substring(0, 4)}..'
                      : p.nickname,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 10,
                    color: theme.subTextColor,
                    fontWeight: isMe ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopBar() {
    final theme = _currentTheme;
    final roundInfo = (_game?.maxRounds ?? 1) > 1
        ? ' (라운드 ${_game?.round ?? 1}/${_game?.maxRounds ?? 1})'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.topBarBg,
        border: Border(
          bottom: BorderSide(color: theme.isDark
              ? CyberColors.borderSubtle
              : Colors.black.withAlpha(15)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_game?.topic ?? '자유 대화'}$roundInfo',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.isDark
                      ? CyberColors.accentTeal.withAlpha(30)
                      : Colors.black.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_players.length}명',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.subTextColor,
                  ),
                ),
              ),
            ],
          ),
          if (_game?.phaseEndsAt != null) ...[
            const SizedBox(height: 8),
            if (_isReady)
              Text(
                '투표 시작까지 $_readyCountdown초...',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.isDark ? CyberColors.warningAmber : const Color(0xFFE65100),
                ),
              )
            else
              PhaseTimer(
                remaining: _remaining,
                total: _totalPhaseTime,
                isDark: theme.isDark,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final theme = _currentTheme;
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 60, top: 2, bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.bubbleBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.bubbleBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
                const SizedBox(width: 8),
                Text(
                  '입력 중...',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    color: theme.subTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    final theme = _currentTheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + index * 200),
      builder: (_, value, child) => Opacity(opacity: value, child: child),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: theme.isDark ? CyberColors.accentTeal : const Color(0xFF00897B),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    final theme = _currentTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.inputBarBg,
        border: Border(
          top: BorderSide(color: theme.isDark
              ? CyberColors.borderSubtle
              : Colors.black.withAlpha(15)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  focusNode: _chatFocusNode,
                  maxLength: 100,
                  maxLines: 1,
                  enabled: !_isReady,
                  textInputAction: TextInputAction.send,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    color: theme.textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: _isReady ? '투표 준비 중...' : '메시지를 입력하세요...',
                    hintStyle: TextStyle(color: theme.subTextColor),
                    counterText: '',
                    filled: true,
                    fillColor: theme.isDark
                        ? CyberColors.bgCard
                        : Colors.white.withAlpha(200),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) {
                    _sendMessage();
                    // 엔터 후 포커스 유지 → 바로 다음 메시지 입력 가능
                    _chatFocusNode.requestFocus();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isReady ? null : _sendMessage,
                icon: const Icon(Icons.send_rounded),
                color: theme.isDark ? CyberColors.accentTeal : const Color(0xFF00897B),
                style: IconButton.styleFrom(
                  backgroundColor: (theme.isDark
                          ? CyberColors.accentTeal
                          : const Color(0xFF00897B))
                      .withAlpha(25),
                ),
              ),
            ],
          ),
          if (!_isReady) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _onReady,
                icon: const Icon(Icons.how_to_vote_rounded, size: 18),
                label: const Text('대화 끝! 투표하기'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.isDark
                      ? CyberColors.warningAmber
                      : const Color(0xFFE65100),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Trap Question Phase ---

  Widget _buildTrapQuestionPhase() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: TrapCardWidget(
                gameId: _gameId!,
                playerId: _myPlayerId ?? '',
                round: _game?.round ?? 1,
                remaining: _remaining,
                onAnswered: () {},
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Voting Phase ---

  Widget _buildVotingPhase() {
    final theme = _currentTheme;
    final others = _players.where((p) => p.id != _myPlayerId).toList();
    final useGrid = others.length >= 4;

    return Column(
      children: [
        _buildTopBar(),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  '🤖 AI는 누구일까요?',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI라고 생각되는 사람을 지목하세요',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    color: theme.subTextColor,
                  ),
                ),
                const SizedBox(height: 24),

                Expanded(
                  child: useGrid
                      ? GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.6,
                          ),
                          itemCount: others.length,
                          itemBuilder: (_, i) => _buildVoteCard(others[i]),
                        )
                      : ListView.builder(
                          itemCount: others.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildVoteCard(others[i]),
                          ),
                        ),
                ),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_selectedVoteTarget != null && !_hasVoted)
                        ? _castVote
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF06292),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.withAlpha(80),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(_hasVoted ? '✅ 투표 완료!' : '투표 확정'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoteCard(GamePlayer target) {
    final theme = _currentTheme;
    final isSelected = _selectedVoteTarget == target.id;

    return InkWell(
      onTap: _hasVoted
          ? null
          : () => setState(() => _selectedVoteTarget = target.id),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0x30F06292)
              : theme.bubbleBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF06292)
                : theme.bubbleBorder,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFFF06292).withAlpha(40), blurRadius: 12)]
              : null,
        ),
        child: Row(
          children: [
            AvatarIcon(
              shape: target.avatarShape,
              colorHex: target.avatarColor,
              size: 44,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                target.nickname,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFFF06292)),
          ],
        ),
      ),
    );
  }

  // --- Result Phase (라벤더 파스텔 배경) ---

  Widget _buildResultPhase() {
    final theme = _currentTheme;

    // 승패 판정
    final myScore = _me?.score ?? 0;
    final won = myScore > 0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            won ? '🎉 AI를 찾아냈습니다!' : '🤖 AI가 살아남았습니다...',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            won ? '축하합니다! +$myScore점' : '아쉽네요... ${myScore}점',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              color: won ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),

          // 순차 공개
          Expanded(
            child: ResultRevealWidget(
              players: _players,
              myPlayerId: _myPlayerId,
              theme: theme,
            ),
          ),

          const SizedBox(height: 16),

          // 하단 버튼
          if (_game?.hasNextRound == true) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _nextRound,
                icon: const Icon(Icons.skip_next_rounded),
                label: Text('다음 라운드 (${(_game?.round ?? 1) + 1}/${_game?.maxRounds ?? 1})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBA68C8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.textColor,
                    side: BorderSide(color: theme.bubbleBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('로비로'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _playAgain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBA68C8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('다시 하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
