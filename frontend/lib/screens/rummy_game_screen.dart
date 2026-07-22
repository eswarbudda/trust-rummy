import 'dart:async';

import 'package:flutter/material.dart';

import '../models/card.dart' as rummy;
import '../models/game_state.dart';
import '../services/game_websocket_service.dart';
import '../theme/rummy_colors.dart';
import '../theme/rummy_layout.dart';
import '../widgets/rummy/hand_grouping.dart';
import '../widgets/rummy/rummy_game_view.dart';

/// Adapter: owns WebSocket + [RummyGameState] and feeds a pure [RummyGameView].
/// Does not open or close the socket — the lobby ([GameTestScreen]) owns that.
class RummyGameScreen extends StatefulWidget {
  final GameWebSocketService gameWs;
  final int? myUserId;
  final String? myUsername;
  final String roomCode;
  final Map<String, dynamic>? initialDealJson;
  /// Human-readable variant for the table header (e.g. "Points", "Pool 101").
  final String? gameVariantLabel;

  const RummyGameScreen({
    super.key,
    required this.gameWs,
    required this.roomCode,
    this.myUserId,
    this.myUsername,
    this.initialDealJson,
    this.gameVariantLabel,
  });

  @override
  State<RummyGameScreen> createState() => _RummyGameScreenState();
}

class _RummyGameScreenState extends State<RummyGameScreen> {
  static const RummyLayout _layout = RummyLayout(scale: 1.0);
  static const int _turnTimeoutSeconds = 30;

  final RummyGameState _state = RummyGameState();
  StreamSubscription<GameSocketEvent>? _eventSub;
  StreamSubscription<SocketConnectionState>? _connSub;

  int? _selectedIndex;
  final Set<int> _groupBreaks = {};
  rummy.Card? _finishSlotCard;
  DeclareResultEvent? _lastDeclareResult;
  String? _declareResultName;
  bool _matchEnded = false;
  /// Guards against double post-game UI when MATCH_ENDED repeats.
  bool _matchEndUiShown = false;
  MatchEndedEvent? _matchEndedEvent;
  ScoreUpdateEvent? _lastScoreUpdate;
  DealResultEvent? _dealResult;
  /// True after the local player requested Leave/EXIT — used to pop back to
  /// the lobby when the match continues without us (multi-player forfeit).
  bool _leaveRequested = false;

  SocketConnectionState _connectionState = SocketConnectionState.disconnected;
  int _turnSecondsLeft = _turnTimeoutSeconds;
  Timer? _turnTimer;
  int? _timerTurnUserId;
  RummyTurnPhase? _timerPhase;

  @override
  void initState() {
    super.initState();
    _state.myUserId = widget.myUserId;
    _connectionState = widget.gameWs.state;

    final initial = widget.initialDealJson;
    if (initial != null && DealSnapshot.hasDealFields(initial)) {
      _applyDealJson(initial, isFreshDeal: true);
    }

    _connSub = widget.gameWs.stateStream.listen((s) {
      if (!mounted) return;
      setState(() => _connectionState = s);
    });

    _eventSub = widget.gameWs.eventStream.listen(_onSocketEvent);
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _connSub?.cancel();
    _turnTimer?.cancel();
    super.dispose();
  }

  RummyGameUiMode get _uiMode {
    // Match-over must win over disconnect — otherwise a socket blip right as
    // MATCH_ENDED arrives hides the summary and looks like "game didn't end".
    if (_matchEnded || _state.snapshot?.matchStatus == RummyMatchStatus.completed) {
      return RummyGameUiMode.completed;
    }
    if (_connectionState != SocketConnectionState.connected) {
      return RummyGameUiMode.disconnected;
    }
    if (_dealResult != null || _state.snapshot?.matchStatus == RummyMatchStatus.betweenDeals) {
      return RummyGameUiMode.dealResult;
    }
    if (_state.snapshot == null) {
      return RummyGameUiMode.waiting;
    }
    return RummyGameUiMode.active;
  }

  void _onSocketEvent(GameSocketEvent event) {
    if (!mounted) return;

    // One bad payload must not cancel the subscription — otherwise the
    // peer can miss MATCH_ENDED and stay stuck on an active-looking table.
    try {
      _dispatchSocketEvent(event);
    } catch (e, st) {
      assert(() {
        // ignore: avoid_print
        print('RummyGameScreen event ${event.type} failed: $e\n$st');
        return true;
      }());
    }
  }

  void _dispatchSocketEvent(GameSocketEvent event) {
    switch (event.type) {
      case 'DEAL_STARTED':
        // Ignore stray deal events after the match is already over.
        if (_matchEnded) return;
        _matchEnded = false;
        _matchEndUiShown = false;
        _matchEndedEvent = null;
        _dealResult = null;
        _applyDealJson(event.raw, isFreshDeal: true);
        setState(() {
          _finishSlotCard = null;
          _lastDeclareResult = null;
          _selectedIndex = null;
          _groupBreaks.clear();
        });
        break;
      case 'TURN_STATE':
      case 'CARD_DRAWN':
      case 'CARD_DISCARDED':
      case 'PLAYER_DROPPED':
        if (_matchEnded || _dealResult != null) return;
        _applyDealJson(event.raw, isFreshDeal: false);
        break;
      case 'ROOM_STATE':
        if (_matchEnded) return;
        if (DealSnapshot.hasDealFields(event.raw)) {
          _applyDealJson(event.raw, isFreshDeal: false);
        }
        break;
      case 'DECLARE_RESULT':
        if (_matchEnded) return;
        _handleDeclareResult(event.raw);
        break;
      case 'SCORE_UPDATE':
        // Keep for the match-result summary; deal UI comes from DEAL_RESULT.
        setState(() {
          _lastScoreUpdate = ScoreUpdateEvent.fromJson(event.raw);
        });
        break;
      case 'DEAL_RESULT':
        if (_matchEnded) return;
        _onDealResult(DealResultEvent.fromJson(event.raw));
        break;
      case 'PLAYER_ELIMINATED':
        _onPlayerEliminated(event.raw);
        break;
      case 'MATCH_ENDED':
        // Protocol event name is MATCH_ENDED (not GAME_COMPLETED).
        _leaveRequested = false;
        _dealResult = null;
        _onMatchEnded(MatchEndedEvent.fromJson(event.raw));
        break;
      case 'ERROR':
      case 'CLIENT_ERROR':
        final msg = event.raw['message']?.toString() ?? 'Unknown error';
        _snack(msg);
        break;
      default:
        break;
    }
  }

  /// Between-deal pause: freeze actions and show DealResultDialog.
  void _onDealResult(DealResultEvent result) {
    if (!mounted) return;
    _turnTimer?.cancel();
    _dismissTransientDialogs();
    setState(() {
      _dealResult = result;
      _selectedIndex = null;
    });
  }

  /// Match lifecycle end: freeze actions → identical in-tree result overlay
  /// on every client (Option B). No Navigator dialog / popUntil races.
  void _onMatchEnded(MatchEndedEvent ended) {
    if (!mounted) return;
    _turnTimer?.cancel();

    if (_matchEndUiShown) {
      setState(() {
        _matchEnded = true;
        _matchEndedEvent = ended;
      });
      return;
    }
    _matchEndUiShown = true;

    // Dismiss Drop/Show confirm sheets only — never pop RummyGameScreen here.
    _dismissTransientDialogs();

    setState(() {
      _matchEnded = true;
      _matchEndedEvent = ended;
      _selectedIndex = null;
    });
  }

  void _dismissTransientDialogs() {
    final nav = Navigator.of(context, rootNavigator: true);
    // Pop overlay routes (dialogs) until the table PageRoute is on top.
    nav.popUntil((route) => route is PageRoute);
  }

  /// Room is COMPLETED after MATCH_ENDED — Play Again / Leave both return
  /// to the lobby so the player can create or join a fresh table.
  void _returnToLobby() {
    if (!mounted) return;
    _dismissTransientDialogs();
    // Drop the old room socket so the lobby cannot send START_MATCH to a
    // completed room after the player creates a new one.
    widget.gameWs.disconnect();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _startNextDeal() {
    if (_matchEnded || _dealResult == null) return;
    widget.gameWs.startNextDeal();
  }

  /// Leave from deal result or active play: ask the server to forfeit / end
  /// the match, then stay on the table until MATCH_ENDED so everyone
  /// (including the leaver) sees the match summary. If the match continues
  /// without us (3+ players), [PLAYER_ELIMINATED] pops us back to lobby.
  void _requestLeaveTable() {
    if (_matchEnded) {
      _returnToLobby();
      return;
    }
    _leaveRequested = true;
    widget.gameWs.leaveTable();
  }

  void _onPlayerEliminated(Map<String, dynamic> raw) {
    if (!_leaveRequested || _matchEnded || !mounted) return;
    final eliminatedId = (raw['userId'] as num?)?.toInt();
    final me = _state.myUserId ?? widget.myUserId;
    if (me != null && eliminatedId == me) {
      // Match kept going without us — return to lobby.
      _returnToLobby();
    }
  }

  void _applyDealJson(Map<String, dynamic> raw, {required bool isFreshDeal}) {
    final snap = DealSnapshot.fromJson(raw);
    _state.resolveMyUserId(widget.myUsername);
    if (_state.myUserId == null && widget.myUserId != null) {
      _state.myUserId = widget.myUserId;
    }
    _state.applyDealSnapshot(snap, isFreshDeal: isFreshDeal);
    setState(() {
      if (isFreshDeal) {
        _selectedIndex = null;
        _groupBreaks.clear();
      } else if (_selectedIndex != null && _selectedIndex! >= _state.myHandArrangement.length) {
        _selectedIndex = null;
      }
      _syncTurnTimer();
    });
  }

  void _syncTurnTimer() {
    final turnUser = _state.snapshot?.currentTurnUserId;
    final phase = _state.snapshot?.turnPhase;
    if (turnUser != _timerTurnUserId || phase != _timerPhase) {
      _timerTurnUserId = turnUser;
      _timerPhase = phase;
      _restartTurnTimer();
    }
  }

  void _restartTurnTimer() {
    _turnTimer?.cancel();
    _turnSecondsLeft = _turnTimeoutSeconds;
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_turnSecondsLeft <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _turnSecondsLeft--);
    });
  }

  void _handleDeclareResult(Map<String, dynamic> raw) {
    final result = DeclareResultEvent.fromJson(raw);
    String name = 'Player ${result.userId}';
    for (final p in _state.snapshot?.players ?? const <PlayerView>[]) {
      if (p.userId == result.userId) {
        name = p.username;
        break;
      }
    }
    rummy.Card? finish;
    for (final meld in result.melds) {
      if (meld.type == 'SET_ASIDE' && meld.cards.isNotEmpty) {
        finish = meld.cards.first;
        break;
      }
    }
    setState(() {
      _lastDeclareResult = result;
      _declareResultName = name;
      if (finish != null) _finishSlotCard = finish;
    });
  }

  String? _nameFor(int? userId) {
    if (userId == null) return null;
    for (final p in _state.snapshot?.players ?? const <PlayerView>[]) {
      if (p.userId == userId) return p.username;
    }
    for (final s in _dealResult?.scores ?? const <ScoreRow>[]) {
      if (s.userId == userId) return s.username;
    }
    for (final s in _lastScoreUpdate?.scores ?? const <ScoreRow>[]) {
      if (s.userId == userId) return s.username;
    }
    return null;
  }

  String? _lastDealScoreLines() {
    final pending = _lastScoreUpdate;
    if (pending == null || pending.scores.isEmpty) return null;
    return pending.scores
        .map((s) => '${s.username}: +${s.roundPoints} (total ${s.cumulativeScore})')
        .join('\n');
  }

  void _snack(String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _draw(bool fromClosed) {
    if (_matchEnded || _dealResult != null) return;
    if (!_state.canDraw) {
      _snack(_state.isMyTurn ? 'Finish your discard first' : 'Not your turn');
      return;
    }
    widget.gameWs.drawCard(fromClosed ? GameDrawSource.closed : GameDrawSource.open);
  }

  void _discardAt(int? index) {
    if (_matchEnded || _dealResult != null) return;
    if (!_state.canDiscardOrDeclare) {
      _snack(_state.isMyTurn ? 'Draw a card first' : 'Not your turn');
      return;
    }
    final hand = _state.myHandArrangement;
    if (index == null || index < 0 || index >= hand.length) {
      _snack('Select or drag a card onto OPEN DECK');
      return;
    }
    final card = hand[index];
    widget.gameWs.discardCard(card.code);
    setState(() {
      final next = HandGrouping.afterRemove(_groupBreaks, index, hand.length - 1);
      _groupBreaks
        ..clear()
        ..addAll(next);
      _selectedIndex = null;
    });
  }

  void _confirmDrop() {
    if (_matchEnded || _dealResult != null) return;
    if (!_state.canDrop) {
      _snack('Drop is only available before you draw');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RummyColors.panelBg,
        title: const Text('Drop this deal?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You fold this deal and take a penalty. In a 2-player table this ends the match for everyone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RummyColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              widget.gameWs.drop();
            },
            child: const Text('Drop'),
          ),
        ],
      ),
    );
  }

  void _openDeclare() {
    if (_matchEnded || _dealResult != null) return;
    if (!_state.canDiscardOrDeclare) {
      _snack(_state.isMyTurn ? 'Draw a card first' : 'Not your turn');
      return;
    }
    if (_selectedIndex == null) {
      _snack('Select the 14th card to set aside, then tap SHOW');
      return;
    }
    final hand = _state.myHandArrangement;
    final extraIndex = _selectedIndex!;
    if (extraIndex < 0 || extraIndex >= hand.length) return;
    final extraCard = hand[extraIndex];

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RummyColors.panelBg,
        title: const Text('Declare (Show)?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Set aside ${extraCard.code} as the finish card and submit your hand for validation.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RummyColors.showGreen),
            onPressed: () {
              Navigator.pop(ctx);
              widget.gameWs.declare(extraCard.code);
              setState(() {
                _finishSlotCard = extraCard;
                _selectedIndex = null;
              });
            },
            child: const Text('Show'),
          ),
        ],
      ),
    );
  }

  void _moveCard(int fromIndex, int toIndex) {
    final hand = List<rummy.Card>.from(_state.myHandArrangement);
    if (fromIndex == toIndex || fromIndex < 0 || fromIndex >= hand.length) return;
    var target = toIndex.clamp(0, hand.length - 1);
    final before = Set<int>.from(_groupBreaks);
    final card = hand.removeAt(fromIndex);
    if (fromIndex < target) target -= 1;
    hand.insert(target, card);
    setState(() {
      _state.reorderHand(hand);
      _groupBreaks
        ..clear()
        ..addAll(HandGrouping.afterMove(before, fromIndex, target, hand.length));
      _selectedIndex = target;
    });
  }

  void _moveIntoGap(int fromIndex, int gapAfterIndex) {
    final hand = List<rummy.Card>.from(_state.myHandArrangement);
    if (fromIndex < 0 || fromIndex >= hand.length) return;
    var insertAt = gapAfterIndex + 1;
    if (fromIndex < insertAt) insertAt -= 1;
    insertAt = insertAt.clamp(0, hand.length - 1);
    final before = Set<int>.from(_groupBreaks);
    final card = hand.removeAt(fromIndex);
    hand.insert(insertAt, card);
    setState(() {
      _state.reorderHand(hand);
      _groupBreaks
        ..clear()
        ..addAll(HandGrouping.afterMove(before, fromIndex, insertAt, hand.length));
      _selectedIndex = insertAt;
    });
  }

  void _nudgeSelected(int delta) {
    final from = _selectedIndex;
    if (from == null) return;
    _moveCard(from, from + delta);
  }

  void _confirmExit() {
    if (_matchEnded) {
      _returnToLobby();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RummyColors.panelBg,
        title: const Text('Leave table?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Leave this table? On a 2-player table this ends the match for everyone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Stay')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RummyColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              _requestLeaveTable();
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snap = _state.snapshot;
    final me = _state.myPlayerView ??
        PlayerView(
          userId: _state.myUserId ?? 0,
          username: widget.myUsername ?? 'You',
          handSize: _state.myHandArrangement.length,
        );
    final hand = _state.myHandArrangement;
    final phase = snap?.turnPhase;
    final dealLabel = _matchEnded
        ? 'Match completed'
        : (_dealResult != null
            ? 'Deal result'
            : (snap?.dealNumber != null ? 'Deal ${snap!.dealNumber}' : 'Waiting for deal'));
    final canAct = !_matchEnded && _dealResult == null;
    final canDraw = canAct && _state.canDraw;
    final canDiscard = canAct && _state.canDiscardOrDeclare;

    return RummyGameView(
      mode: _uiMode,
      headerLabel: '${widget.gameVariantLabel ?? 'Rummy'}   ·   #${widget.roomCode}   ·   $dealLabel',
      layout: _layout,
      opponents: _state.opponents,
      me: me,
      hand: hand,
      wildValue: snap?.wildValue,
      cutJokerCard: snap?.cutJokerCard,
      closedDeckCount: snap?.closedDeckCount ?? 0,
      discardTop: snap?.discardTop,
      finishSlotCard: _finishSlotCard,
      phase: phase,
      currentTurnUserId: snap?.currentTurnUserId,
      turnSecondsRemaining: (_matchEnded || _dealResult != null) ? null : _turnSecondsLeft,
      selectedIndex: _selectedIndex,
      groupBreaksAfterIndex: _groupBreaks,
      declareResult: _lastDeclareResult,
      declareResultName: _declareResultName,
      isMyTurn: canAct && _state.isMyTurn,
      canDiscardSelected: canDiscard,
      matchResult: _matchEndedEvent,
      matchWinnerName: _nameFor(_matchEndedEvent?.winnerUserId),
      lastDealScoreLines: _lastDealScoreLines(),
      playerNames: {
        for (final p in snap?.players ?? const <PlayerView>[]) p.userId: p.username,
        for (final s in _lastScoreUpdate?.scores ?? const <ScoreRow>[]) s.userId: s.username,
        for (final s in _dealResult?.scores ?? const <ScoreRow>[]) s.userId: s.username,
      },
      dealResult: _dealResult,
      dealWinnerName: _nameFor(_dealResult?.winnerUserId),
      onStartNextDeal: _startNextDeal,
      onPlayAgain: _returnToLobby,
      onLeaveTable: _matchEnded ? _returnToLobby : _requestLeaveTable,
      onExit: _matchEnded ? _returnToLobby : _confirmExit,
      onCloseDeclareResult: () => setState(() => _lastDeclareResult = null),
      onCardTap: canAct
          ? (index, card) {
              setState(() => _selectedIndex = _selectedIndex == index ? null : index);
            }
          : null,
      onToggleGroupBreak: canAct
          ? (index) => setState(() {
                final next = HandGrouping.toggleBreak(_groupBreaks, index, _state.myHandArrangement.length);
                _groupBreaks
                  ..clear()
                  ..addAll(next);
              })
          : null,
      onMoveCard: canAct ? _moveCard : null,
      onMoveIntoGap: canAct ? _moveIntoGap : null,
      onAcceptFromPile: canDraw ? _draw : null,
      onDrawClosed: canDraw ? () => _draw(true) : null,
      onDrawOpen: canDraw ? () => _draw(false) : null,
      onDiscardDrop: canDiscard ? (payload) => _discardAt(payload.handIndex) : null,
      onFinishDrop: canDiscard
          ? (payload) {
              setState(() => _selectedIndex = payload.handIndex);
              _openDeclare();
            }
          : null,
      onDrop: canAct ? _confirmDrop : null,
      onDeclare: canAct ? _openDeclare : null,
      onNudgeLeft: canAct ? () => _nudgeSelected(-1) : null,
      onNudgeRight: canAct ? () => _nudgeSelected(1) : null,
      onToggleSplit: canAct
          ? () {
              final i = _selectedIndex;
              if (i == null) return;
              setState(() {
                final next = HandGrouping.toggleBreak(_groupBreaks, i, _state.myHandArrangement.length);
                _groupBreaks
                  ..clear()
                  ..addAll(next);
              });
            }
          : null,
      onDiscardSelected: canDiscard ? () => _discardAt(_selectedIndex) : null,
    );
  }
}
