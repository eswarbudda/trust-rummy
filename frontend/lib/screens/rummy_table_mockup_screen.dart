import 'dart:async';

import 'package:flutter/material.dart';

import '../models/card.dart' as rummy;
import '../models/game_state.dart';
import '../theme/rummy_colors.dart';
import '../theme/rummy_layout.dart';
import '../widgets/rummy/hand_grouping.dart';
import '../widgets/rummy/hand_view.dart';
import '../widgets/rummy/rummy_game_view.dart';

/// Static, non-networked visual mockup — feeds sample props into [RummyGameView].
class RummyTableMockupScreen extends StatefulWidget {
  const RummyTableMockupScreen({super.key});

  @override
  State<RummyTableMockupScreen> createState() => _RummyTableMockupScreenState();
}

class _RummyTableMockupScreenState extends State<RummyTableMockupScreen> {
  static const _wildValue = rummy.Value.six;
  static const _cutJoker = rummy.Card(value: rummy.Value.six, suit: rummy.Suit.clubs);

  int _closedDeckCount = 42;

  /// Open discard history (oldest → newest). Top of pile is last.
  List<rummy.Card> _discardPile = [
    const rummy.Card(value: rummy.Value.three, suit: rummy.Suit.clubs),
    const rummy.Card(value: rummy.Value.king, suit: rummy.Suit.spades),
    const rummy.Card(value: rummy.Value.five, suit: rummy.Suit.hearts),
    const rummy.Card(value: rummy.Value.eight, suit: rummy.Suit.diamonds),
  ];

  /// Extra face-down cards the mockup can "deal" from the closed deck.
  final List<rummy.Card> _closedSpare = [
    const rummy.Card(value: rummy.Value.six, suit: rummy.Suit.clubs),
    const rummy.Card(value: rummy.Value.two, suit: rummy.Suit.hearts),
    const rummy.Card(value: rummy.Value.ace, suit: rummy.Suit.diamonds),
    const rummy.Card(value: rummy.Value.nine, suit: rummy.Suit.spades),
    const rummy.Card(value: rummy.Value.four, suit: rummy.Suit.diamonds),
  ];

  late List<rummy.Card> _hand = List<rummy.Card>.of(_sampleHand());
  int? _selectedIndex;
  /// Start in draw phase so deck/discard taps work immediately.
  RummyTurnPhase _previewPhase = RummyTurnPhase.awaitingDraw;

  /// Empty at deal — only valid melds get visual trays (via auto-split / Sort).
  /// Manual group breaks after card index (gap between i and i+1).
  /// Seeded to match the sample hand's intended melds for the mockup.
  final Set<int> _groupBreaks = {3, 7, 10};

  /// Single layout source for seats / piles / hand — tune via [RummyLayout.scaled].
  static const RummyLayout _layout = RummyLayout(scale: 1.15);

  rummy.Card? _finishSlotCard;
  DeclareResultEvent? _lastDeclareResult;

  static const int _turnTimeoutSeconds = 30;
  int _turnSecondsLeft = _turnTimeoutSeconds;
  Timer? _turnTimer;

  // 6-max table (RoomCreateRequest.maxPlayers is capped at 6 server-side)
  // — 5 opponents ringed around the top of the table plus "you" at the
  // bottom.
  static const List<PlayerView> _opponents = [
    PlayerView(userId: 2, username: 'Chand Patel', seatNumber: 1, cumulativeScore: 24, handSize: 13),
    PlayerView(userId: 3, username: 'Nensi Rudra', seatNumber: 2, cumulativeScore: 58, handSize: 11),
    PlayerView(userId: 4, username: 'Jaidip Patel', seatNumber: 3, cumulativeScore: 12, handSize: 13),
    PlayerView(userId: 5, username: 'Kuldip Shah', seatNumber: 4, cumulativeScore: 40, handSize: 13),
    PlayerView(userId: 6, username: 'Badshah P.', seatNumber: 5, cumulativeScore: 37, handSize: 13),
  ];

  static const PlayerView _me = PlayerView(
    userId: 1,
    username: 'You',
    seatNumber: 0,
    cumulativeScore: 8,
    handSize: 13,
    roundStatus: RummyRoundStatus.playing,
  );

  @override
  void initState() {
    super.initState();
    _restartTurnTimer();
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    super.dispose();
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

  /// Demo hand arranged so valid melds read clearly (reference-style groups).
  static List<rummy.Card> _sampleHand() => const [
        // Pure sequence
        rummy.Card(value: rummy.Value.ten, suit: rummy.Suit.spades),
        rummy.Card(value: rummy.Value.jack, suit: rummy.Suit.spades),
        rummy.Card(value: rummy.Value.queen, suit: rummy.Suit.spades),
        rummy.Card(value: rummy.Value.king, suit: rummy.Suit.spades),
        // Impure sequence (6♣ is wild)
        rummy.Card(value: rummy.Value.ace, suit: rummy.Suit.hearts),
        rummy.Card(value: rummy.Value.six, suit: rummy.Suit.clubs),
        rummy.Card(value: rummy.Value.three, suit: rummy.Suit.hearts),
        rummy.Card(value: rummy.Value.four, suit: rummy.Suit.hearts),
        // Set
        rummy.Card(value: rummy.Value.seven, suit: rummy.Suit.hearts),
        rummy.Card(value: rummy.Value.joker),
        rummy.Card(value: rummy.Value.seven, suit: rummy.Suit.diamonds),
        // Invalid leftover
        rummy.Card(value: rummy.Value.three, suit: rummy.Suit.spades),
        rummy.Card(value: rummy.Value.five, suit: rummy.Suit.spades),
      ];

  @override
  Widget build(BuildContext context) {
    return RummyGameView(
      mode: RummyGameUiMode.active,
      headerLabel: 'Entry : ₹ 5   ·   Points Rummy   ·   #TR8794201',
      layout: _layout,
      opponents: _opponents,
      me: _me,
      hand: _hand,
      wildValue: _wildValue,
      cutJokerCard: _cutJoker,
      closedDeckCount: _closedDeckCount,
      discardPile: _discardPile,
      finishSlotCard: _finishSlotCard,
      phase: _previewPhase,
      currentTurnUserId: _me.userId,
      turnSecondsRemaining: _turnSecondsLeft,
      selectedIndex: _selectedIndex,
      groupBreaksAfterIndex: _groupBreaks,
      declareResult: _lastDeclareResult,
      declareResultName: 'You',
      isMyTurn: true,
      canDiscardSelected: _previewPhase == RummyTurnPhase.awaitingDiscard,
      headerTrailing: _walletChip(),
      belowHeader: _previewPhaseSwitch(),
      onExit: () => _confirmExit(context),
      onCloseDeclareResult: () => setState(() => _lastDeclareResult = null),
      onCardTap: (index, card) {
        setState(() => _selectedIndex = _selectedIndex == index ? null : index);
      },
      onToggleGroupBreak: (index) => setState(() {
        final next = HandGrouping.toggleBreak(_groupBreaks, index, _hand.length);
        _groupBreaks
          ..clear()
          ..addAll(next);
      }),
      onMoveCard: _moveCard,
      onMoveIntoGap: _moveIntoGap,
      onAcceptFromPile: _previewPhase == RummyTurnPhase.awaitingDraw ? _drawFromPile : null,
      onDrawClosed: _previewPhase == RummyTurnPhase.awaitingDraw ? () => _drawFromPile(true) : null,
      onDrawOpen: _previewPhase == RummyTurnPhase.awaitingDraw ? () => _drawFromPile(false) : null,
      onDiscardDrop: _previewPhase == RummyTurnPhase.awaitingDiscard
          ? (payload) => _discardCard(payload.handIndex)
          : null,
      onFinishDrop: _previewPhase == RummyTurnPhase.awaitingDiscard
          ? (payload) {
              setState(() => _selectedIndex = payload.handIndex);
              _openDeclareReview();
            }
          : null,
      onDrop: _confirmDropGame,
      onDeclare: _openDeclareReview,
      onNudgeLeft: () => _nudgeSelected(-1),
      onNudgeRight: () => _nudgeSelected(1),
      onToggleSplit: () {
        final i = _selectedIndex;
        if (i == null) return;
        setState(() {
          final next = HandGrouping.toggleBreak(_groupBreaks, i, _hand.length);
          _groupBreaks
            ..clear()
            ..addAll(next);
        });
      },
      onDiscardSelected: () {
        final i = _selectedIndex;
        if (i != null) _discardCard(i);
      },
    );
  }

  Widget _walletChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RummyColors.gold.withOpacity(0.45)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_wallet_outlined, color: RummyColors.gold, size: 16),
          SizedBox(width: 5),
          Text('₹ 80.00', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }

  void _confirmExit(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RummyColors.panelBg,
        title: const Text('Exit game?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Leave this table and return to the lobby?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Stay')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RummyColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  Widget _previewPhaseSwitch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          _phaseChip('Draw', RummyTurnPhase.awaitingDraw),
          const SizedBox(width: 6),
          _phaseChip('Discard', RummyTurnPhase.awaitingDiscard),
          const Spacer(),
          Text(
            'Mock preview',
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _phaseChip(String label, RummyTurnPhase value) {
    final selected = _previewPhase == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) => setState(() {
        _previewPhase = value;
        _selectedIndex = null;
        _restartTurnTimer();
      }),
      selectedColor: RummyColors.gold.withOpacity(0.85),
      backgroundColor: Colors.white.withOpacity(0.06),
      labelStyle: TextStyle(color: selected ? Colors.black : Colors.white70),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _drawFromPile(bool fromClosed) {
    if (_previewPhase != RummyTurnPhase.awaitingDraw) {
      _showMockSnack('Finish your discard first — or switch preview to Awaiting Draw');
      return;
    }

    rummy.Card? drawn;
    if (fromClosed) {
      if (_closedSpare.isEmpty || _closedDeckCount <= 0) {
        _showMockSnack('Closed deck is empty');
        return;
      }
      drawn = _closedSpare.removeLast();
    } else {
      if (_discardPile.isEmpty) {
        _showMockSnack('Discard pile is empty');
        return;
      }
      drawn = _discardPile.removeLast();
    }

    setState(() {
      if (fromClosed) _closedDeckCount -= 1;
      _hand.add(drawn!);
      _selectedIndex = _hand.length - 1;
      _previewPhase = RummyTurnPhase.awaitingDiscard;
      _restartTurnTimer();
    });
    _showMockSnack('Drew ${drawn.code} from ${fromClosed ? 'deck' : 'discard'}');
  }

  void _nudgeSelected(int delta) {
    final from = _selectedIndex;
    if (from == null) return;
    final to = from + delta;
    if (to < 0 || to >= _hand.length) return;
    setState(() {
      final card = _hand.removeAt(from);
      _hand.insert(to, card);
      _selectedIndex = to;
    });
  }

  /// Drag a card from [fromIndex] onto [toIndex]. Preserves group breaks.
  void _moveCard(int fromIndex, int toIndex) {
    if (fromIndex == toIndex || fromIndex < 0 || fromIndex >= _hand.length) return;
    var target = toIndex.clamp(0, _hand.length - 1);
    setState(() {
      final before = Set<int>.from(_groupBreaks);
      final card = _hand.removeAt(fromIndex);
      if (fromIndex < target) target -= 1;
      _hand.insert(target, card);
      final next = HandGrouping.afterMove(before, fromIndex, target, _hand.length);
      _groupBreaks
        ..clear()
        ..addAll(next);
      _selectedIndex = target;
    });
  }

  /// Drop onto the gap after [gapAfterIndex] — move card there; keep breaks.
  void _moveIntoGap(int fromIndex, int gapAfterIndex) {
    if (fromIndex < 0 || fromIndex >= _hand.length) return;
    var insertAt = gapAfterIndex + 1;
    if (fromIndex < insertAt) insertAt -= 1;
    insertAt = insertAt.clamp(0, _hand.length - 1);

    setState(() {
      final before = Set<int>.from(_groupBreaks);
      final card = _hand.removeAt(fromIndex);
      _hand.insert(insertAt, card);
      final next = HandGrouping.afterMove(before, fromIndex, insertAt, _hand.length);
      _groupBreaks
        ..clear()
        ..addAll(next);
      _selectedIndex = insertAt;
    });
  }

  void _confirmDropGame() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RummyColors.panelBg,
        title: const Text('Drop this deal?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Drop means you fold this deal and take a penalty (20 pts first turn / 40 pts later). '
          'You sit out until the next deal.\n\n'
          'This is different from discarding a single card onto the DISCARD pile.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RummyColors.danger),
            onPressed: () {
              Navigator.of(ctx).pop();
              _showMockSnack('Dropped this deal — mockup only (penalty applied server-side later)');
            },
            child: const Text('Drop game'),
          ),
        ],
      ),
    );
  }

  void _discardCard(int? index) {
    if (index == null || index < 0 || index >= _hand.length) {
      _showMockSnack('Drag a card onto the DISCARD pile');
      return;
    }
    final card = _hand[index];
    setState(() {
      final shifted = HandGrouping.afterRemove(_groupBreaks, index, _hand.length - 1);
      _hand.removeAt(index);
      _discardPile = [..._discardPile, card];
      _selectedIndex = null;
      _groupBreaks
        ..clear()
        ..addAll(shifted);
      _restartTurnTimer();
    });
    _showMockSnack('Discarded ${card.code}');
    // Next turn preview — back to draw phase so deck/discard work again.
    setState(() => _previewPhase = RummyTurnPhase.awaitingDraw);
  }

  /// Opens a bottom sheet previewing how the current hand's group-break
  /// arrangement would be submitted as a `DECLARE` — the 14th (selected)
  /// card is set aside and the rest are shown grouped exactly as arranged.
  /// Confirming simulates the backend's `DECLARE_RESULT` broadcast as an
  /// on-board reveal panel (see `DeclareResultPanel`).
  void _openDeclareReview() {
    if (_selectedIndex == null) {
      _showMockSnack('Select the 14th card to set aside, then tap Show');
      return;
    }
    final extraIndex = _selectedIndex!;
    final extraCard = _hand[extraIndex];
    final remaining = List<rummy.Card>.from(_hand)..removeAt(extraIndex);
    final breaksForRemaining = _groupBreaks.where((i) => i != extraIndex).map((i) => i > extraIndex ? i - 1 : i).toSet();
    final groups = HandGrouping.splitIntoGroups(remaining, breaksForRemaining);
    final melds = [for (final group in groups) MeldView(type: _classifyGroup(group), cards: group)];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RummyColors.panelBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Declare (Show) — review', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'Declare means you claim a winning hand. Your 14th card goes to the Finish Slot; the other 13 must form valid sets/sequences. Everyone at the table then sees your melds on the board.',
                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.3),
              ),
              const SizedBox(height: 14),
              Text('Finish Slot card: ${extraCard.code}', style: const TextStyle(color: RummyColors.gold, fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (var i = 0; i < melds.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${_meldLabel(melds[i].type)} ${i + 1}: ${melds[i].cards.map((c) => c.code).join(', ')}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Keep arranging'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: RummyColors.gold, foregroundColor: Colors.black),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        setState(() {
                          _finishSlotCard = extraCard;
                          _hand.removeAt(extraIndex);
                          _selectedIndex = null;
                          final shifted = _groupBreaks
                              .where((i) => i != extraIndex)
                              .map((i) => i > extraIndex ? i - 1 : i)
                              .toSet();
                          _groupBreaks
                            ..clear()
                            ..addAll(shifted);

                          final looksValid = melds.length >= 2 &&
                              melds.every((m) => m.type == 'SET' || m.type == 'SEQUENCE' || m.type == 'PURE_SEQUENCE');
                          _lastDeclareResult = DeclareResultEvent(
                            userId: 1,
                            valid: looksValid,
                            reason: looksValid
                                ? 'Declared melds are shown on the board for everyone. Finish card sits in the Finish Slot.'
                                : 'Not all groups form a valid set or sequence — mockup preview only, the server has the final say',
                            melds: [
                              ...melds,
                              MeldView(type: 'SET_ASIDE', cards: [extraCard]),
                            ],
                          );
                        });
                      },
                      child: const Text('Confirm Show'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _classifyGroup(List<rummy.Card> group) => HandView.classifyGroup(group, _wildValue);

  String _meldLabel(String type) => HandView.meldLabel(type);

  void _showMockSnack(String message) {
    if (message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}
