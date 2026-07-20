import 'dart:async';

import 'package:flutter/material.dart';

import '../models/card.dart' as rummy;
import '../models/game_state.dart';
import '../services/game_websocket_service.dart';
import '../theme/rummy_colors.dart';
import '../theme/rummy_layout.dart';
import '../widgets/rummy/rummy_action_bar.dart';
import '../widgets/rummy/rummy_table_board.dart';

/// Live gameplay table driven by an already-connected [GameWebSocketService].
/// Does not open or close the socket — the lobby ([GameTestScreen]) owns that.
class RummyGameScreen extends StatefulWidget {
  final GameWebSocketService gameWs;
  final int? myUserId;
  final String? myUsername;
  final String roomCode;
  final Map<String, dynamic>? initialDealJson;

  const RummyGameScreen({
    super.key,
    required this.gameWs,
    required this.roomCode,
    this.myUserId,
    this.myUsername,
    this.initialDealJson,
  });

  @override
  State<RummyGameScreen> createState() => _RummyGameScreenState();
}

class _RummyGameScreenState extends State<RummyGameScreen> {
  static const RummyLayout _layout = RummyLayout(scale: 1.15);
  static const int _turnTimeoutSeconds = 30;

  final RummyGameState _state = RummyGameState();
  StreamSubscription<GameSocketEvent>? _eventSub;
  StreamSubscription<SocketConnectionState>? _connSub;

  int? _selectedIndex;
  final Set<int> _groupBreaks = {};
  rummy.Card? _finishSlotCard;
  DeclareResultEvent? _lastDeclareResult;
  String? _declareResultName;

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

  void _onSocketEvent(GameSocketEvent event) {
    if (!mounted) return;

    switch (event.type) {
      case 'DEAL_STARTED':
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
        _applyDealJson(event.raw, isFreshDeal: false);
        break;
      case 'ROOM_STATE':
        if (DealSnapshot.hasDealFields(event.raw)) {
          _applyDealJson(event.raw, isFreshDeal: false);
        }
        break;
      case 'DECLARE_RESULT':
        _handleDeclareResult(event.raw);
        break;
      case 'SCORE_UPDATE':
        _showScoreUpdate(ScoreUpdateEvent.fromJson(event.raw));
        break;
      case 'MATCH_ENDED':
        _showMatchEnded(MatchEndedEvent.fromJson(event.raw));
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

  void _showScoreUpdate(ScoreUpdateEvent update) {
    final lines = update.scores
        .map((s) => '${s.username}: +${s.roundPoints} (total ${s.cumulativeScore})')
        .join('\n');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RummyColors.panelBg,
        title: Text(
          'Deal ${update.dealNumber ?? ''} scores',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(lines.isEmpty ? 'No scores' : lines, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showMatchEnded(MatchEndedEvent ended) {
    final winnerName = _nameFor(ended.winnerUserId) ?? 'Player ${ended.winnerUserId}';
    final scores = ended.finalScores.entries
        .map((e) => '${_nameFor(e.key) ?? e.key}: ${e.value}')
        .join('\n');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RummyColors.panelBg,
        title: const Text('Match ended', style: TextStyle(color: Colors.white)),
        content: Text(
          'Winner: $winnerName\n\n$scores',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
            },
            child: const Text('Back to lobby'),
          ),
        ],
      ),
    );
  }

  String? _nameFor(int? userId) {
    if (userId == null) return null;
    for (final p in _state.snapshot?.players ?? const <PlayerView>[]) {
      if (p.userId == userId) return p.username;
    }
    return null;
  }

  void _snack(String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // ---- Actions (phase-gated) ----

  void _draw(bool fromClosed) {
    if (!_state.canDraw) {
      _snack(_state.isMyTurn ? 'Finish your discard first' : 'Not your turn');
      return;
    }
    widget.gameWs.drawCard(fromClosed ? GameDrawSource.closed : GameDrawSource.open);
  }

  void _discardAt(int? index) {
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
    setState(() => _selectedIndex = null);
  }

  void _confirmDrop() {
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
          'You fold this deal and take a penalty. You sit out until the next deal.',
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
    final card = hand.removeAt(fromIndex);
    if (fromIndex < target) target -= 1;
    hand.insert(target, card);
    setState(() {
      _state.reorderHand(hand);
      _selectedIndex = target;
    });
  }

  void _moveIntoGap(int fromIndex, int gapAfterIndex) {
    final hand = List<rummy.Card>.from(_state.myHandArrangement);
    if (fromIndex < 0 || fromIndex >= hand.length) return;
    var insertAt = gapAfterIndex + 1;
    if (fromIndex < insertAt) insertAt -= 1;
    insertAt = insertAt.clamp(0, hand.length - 1);
    final card = hand.removeAt(fromIndex);
    hand.insert(insertAt, card);
    setState(() {
      _state.reorderHand(hand);
      _selectedIndex = insertAt;
    });
  }

  void _nudgeSelected(int delta) {
    final from = _selectedIndex;
    if (from == null) return;
    _moveCard(from, from + delta);
  }

  void _confirmExit() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RummyColors.panelBg,
        title: const Text('Leave table?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Return to the lobby? The game socket stays connected.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Stay')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RummyColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
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
    final isMyTurn = _state.isMyTurn;
    final phase = snap?.turnPhase;
    final dealLabel = snap?.dealNumber != null ? 'Deal ${snap!.dealNumber}' : 'Waiting for deal';
    final connected = _connectionState == SocketConnectionState.connected;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: RummyColors.boardGradient),
        child: SafeArea(
          child: Column(
            children: [
              _topBar(dealLabel, connected),
              if (snap == null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'Waiting for DEAL_STARTED…',
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
                  ),
                ),
              Expanded(
                child: RummyTableBoard(
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
                  turnSecondsRemaining: _turnSecondsLeft,
                  layout: _layout,
                  selectedIndex: _selectedIndex,
                  groupBreaksAfterIndex: _groupBreaks,
                  declareResult: _lastDeclareResult,
                  declareResultName: _declareResultName,
                  onCloseDeclareResult: () => setState(() => _lastDeclareResult = null),
                  onCardTap: (index, card) {
                    setState(() => _selectedIndex = _selectedIndex == index ? null : index);
                  },
                  onToggleGroupBreak: (index) => setState(() {
                    if (_groupBreaks.contains(index)) {
                      _groupBreaks.remove(index);
                    } else {
                      _groupBreaks.add(index);
                    }
                  }),
                  onMoveCard: _moveCard,
                  onMoveIntoGap: _moveIntoGap,
                  onAcceptFromPile: _state.canDraw ? _draw : null,
                  onDrawClosed: _state.canDraw ? () => _draw(true) : null,
                  onDrawOpen: _state.canDraw ? () => _draw(false) : null,
                  onDiscardDrop: _state.canDiscardOrDeclare
                      ? (payload) => _discardAt(payload.handIndex)
                      : null,
                  onFinishDrop: _state.canDiscardOrDeclare
                      ? (payload) {
                          setState(() => _selectedIndex = payload.handIndex);
                          _openDeclare();
                        }
                      : null,
                ),
              ),
              if (_selectedIndex != null) _selectedCardTools(hand),
              _footerActions(me, isMyTurn, phase),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(String dealLabel, bool connected) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 4),
      child: Row(
        children: [
          Material(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: _confirmExit,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 5),
                    Text(
                      'EXIT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: RummyColors.headerPill.withOpacity(0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Points Rummy   ·   #${widget.roomCode}   ·   $dealLabel',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.signal_cellular_alt,
                    color: connected ? RummyColors.success : RummyColors.danger,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerActions(PlayerView me, bool isMyTurn, RummyTurnPhase? phase) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'SCORE: ${me.cumulativeScore}',
            style: const TextStyle(color: RummyColors.gold, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(width: 16),
          RummyActionBar(
            isMyTurn: isMyTurn,
            phase: phase,
            onDrop: _confirmDrop,
            onDeclare: _openDeclare,
          ),
        ],
      ),
    );
  }

  Widget _selectedCardTools(List<rummy.Card> hand) {
    final i = _selectedIndex!;
    final canLeft = i > 0;
    final canRight = i < hand.length - 1;
    final splitActive = i < hand.length - 1 && _groupBreaks.contains(i);
    final canDiscard = _state.canDiscardOrDeclare;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _toolChip(
            icon: Icons.chevron_left_rounded,
            label: 'Left',
            enabled: canLeft,
            onTap: canLeft ? () => _nudgeSelected(-1) : null,
          ),
          const SizedBox(width: 8),
          _toolChip(
            icon: Icons.view_column_rounded,
            label: splitActive ? 'Merge' : 'Split',
            enabled: canRight,
            active: splitActive,
            onTap: canRight
                ? () => setState(() {
                      if (_groupBreaks.contains(i)) {
                        _groupBreaks.remove(i);
                      } else {
                        _groupBreaks.add(i);
                      }
                    })
                : null,
          ),
          const SizedBox(width: 8),
          _toolChip(
            icon: Icons.chevron_right_rounded,
            label: 'Right',
            enabled: canRight,
            onTap: canRight ? () => _nudgeSelected(1) : null,
          ),
          if (canDiscard) ...[
            const SizedBox(width: 8),
            _toolChip(
              icon: Icons.upload_rounded,
              label: 'Discard',
              enabled: true,
              onTap: () => _discardAt(i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _toolChip({
    required IconData icon,
    required String label,
    required bool enabled,
    bool active = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: active ? RummyColors.gold.withOpacity(0.25) : Colors.white.withOpacity(enabled ? 0.1 : 0.04),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: enabled ? (active ? RummyColors.gold : Colors.white) : Colors.white30),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? (active ? RummyColors.gold : Colors.white70) : Colors.white30,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
