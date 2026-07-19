import 'card.dart';

/// Mirrors the backend's `com.trustrummy.backend.game.model.MatchStatus`.
enum RummyMatchStatus {
  waiting,
  inProgress,
  completed;

  static RummyMatchStatus? fromWire(String? name) {
    switch (name) {
      case 'WAITING':
        return RummyMatchStatus.waiting;
      case 'IN_PROGRESS':
        return RummyMatchStatus.inProgress;
      case 'COMPLETED':
        return RummyMatchStatus.completed;
      default:
        return null;
    }
  }
}

/// Mirrors the backend's `com.trustrummy.backend.game.model.TurnPhase`.
enum RummyTurnPhase {
  awaitingDraw,
  awaitingDiscard;

  static RummyTurnPhase? fromWire(String? name) {
    switch (name) {
      case 'AWAITING_DRAW':
        return RummyTurnPhase.awaitingDraw;
      case 'AWAITING_DISCARD':
        return RummyTurnPhase.awaitingDiscard;
      default:
        return null;
    }
  }
}

/// Mirrors the backend's `com.trustrummy.backend.game.model.RoundStatus` —
/// a player's status within the *current* deal only.
enum RummyRoundStatus {
  playing,
  dropped,
  declaredValid,
  declaredWrong;

  static RummyRoundStatus? fromWire(String? name) {
    switch (name) {
      case 'PLAYING':
        return RummyRoundStatus.playing;
      case 'DROPPED':
        return RummyRoundStatus.dropped;
      case 'DECLARED_VALID':
        return RummyRoundStatus.declaredValid;
      case 'DECLARED_WRONG':
        return RummyRoundStatus.declaredWrong;
      default:
        return null;
    }
  }
}

/// Mirrors the backend's `com.trustrummy.backend.game.model.MatchPlayerStatus`
/// — a player's status within the overall match, persisted across deals.
enum RummyMatchPlayerStatus {
  active,
  eliminated,
  winner;

  static RummyMatchPlayerStatus? fromWire(String? name) {
    switch (name) {
      case 'ACTIVE':
        return RummyMatchPlayerStatus.active;
      case 'ELIMINATED':
        return RummyMatchPlayerStatus.eliminated;
      case 'WINNER':
        return RummyMatchPlayerStatus.winner;
      default:
        return null;
    }
  }
}

/// Where a `DRAW_CARD` action pulled from, echoed back client-side for the
/// draw-pile tap targets. Mirrors `com.trustrummy.backend.game.ws.DrawSource`.
enum RummyDrawSource {
  closed,
  open;

  String get wireName => this == RummyDrawSource.closed ? 'CLOSED' : 'OPEN';
}

/// One seat's view of itself, as carried in every deal snapshot's
/// `players[]` array (`RummyEngineService#buildPlayerViews`). `hand` is
/// only ever populated for the viewer's own seat — every other seat only
/// ever exposes [handSize], per the server's anti-cheat redaction.
class PlayerView {
  final int userId;
  final String username;
  final int? seatNumber;
  final int cumulativeScore;
  final RummyMatchPlayerStatus? matchPlayerStatus;
  final RummyRoundStatus? roundStatus;
  final int? handSize;
  final List<Card>? hand;

  const PlayerView({
    required this.userId,
    required this.username,
    this.seatNumber,
    this.cumulativeScore = 0,
    this.matchPlayerStatus,
    this.roundStatus,
    this.handSize,
    this.hand,
  });

  factory PlayerView.fromJson(Map<String, dynamic> json) {
    final handField = json['hand'];
    return PlayerView(
      userId: (json['userId'] as num).toInt(),
      username: json['username'] as String? ?? 'Player ${json['userId']}',
      seatNumber: (json['seatNumber'] as num?)?.toInt(),
      cumulativeScore: (json['cumulativeScore'] as num?)?.toInt() ?? 0,
      matchPlayerStatus: RummyMatchPlayerStatus.fromWire(json['matchStatus'] as String?),
      roundStatus: RummyRoundStatus.fromWire(json['roundStatus'] as String?),
      handSize: (json['handSize'] as num?)?.toInt(),
      hand: handField is List
          ? handField.map((c) => Card.fromCode(c as String)).toList()
          : null,
    );
  }

  bool get isDropped => roundStatus == RummyRoundStatus.dropped;
  bool get isEliminated => matchPlayerStatus == RummyMatchPlayerStatus.eliminated;
  bool get isWinner => matchPlayerStatus == RummyMatchPlayerStatus.winner;
  bool get hasDeclared => roundStatus == RummyRoundStatus.declaredValid || roundStatus == RummyRoundStatus.declaredWrong;

  /// Still holding cards in the *current* deal (i.e. hasn't dropped, isn't
  /// sitting out an elimination, and hasn't already declared).
  bool get isInHand => handSize != null;
}

/// The full per-recipient deal snapshot shape shared by `ROOM_STATE` (when a
/// deal is already live), `DEAL_STARTED`, `TURN_STATE`, `CARD_DRAWN`,
/// `CARD_DISCARDED`, and `PLAYER_DROPPED` (`RULES_ENGINE.md` §9).
class DealSnapshot {
  final String? roomCode;
  final int? dealNumber;
  final RummyMatchStatus? matchStatus;
  final Value? wildValue;
  final Card? cutJokerCard;
  final Card? discardTop;
  final int closedDeckCount;
  final int? currentTurnUserId;
  final RummyTurnPhase? turnPhase;
  final List<PlayerView> players;

  const DealSnapshot({
    this.roomCode,
    this.dealNumber,
    this.matchStatus,
    this.wildValue,
    this.cutJokerCard,
    this.discardTop,
    this.closedDeckCount = 0,
    this.currentTurnUserId,
    this.turnPhase,
    this.players = const [],
  });

  factory DealSnapshot.fromJson(Map<String, dynamic> json) {
    final wild = json['wildValue'] as String?;
    final cut = json['cutJokerCard'] as String?;
    final topDiscard = json['discardTop'] as String?;
    final playersField = json['players'];
    return DealSnapshot(
      roomCode: json['roomCode'] as String?,
      dealNumber: (json['dealNumber'] as num?)?.toInt(),
      matchStatus: RummyMatchStatus.fromWire(json['matchStatus'] as String?),
      wildValue: wild != null ? Value.fromWire(wild) : null,
      cutJokerCard: cut != null ? Card.fromCode(cut) : null,
      discardTop: topDiscard != null ? Card.fromCode(topDiscard) : null,
      closedDeckCount: (json['closedDeckCount'] as num?)?.toInt() ?? 0,
      currentTurnUserId: (json['currentTurnUserId'] as num?)?.toInt(),
      turnPhase: RummyTurnPhase.fromWire(json['turnPhase'] as String?),
      players: playersField is List
          ? playersField.whereType<Map<String, dynamic>>().map(PlayerView.fromJson).toList()
          : const [],
    );
  }

  /// Whether this JSON payload actually carries a live deal, vs. a bare
  /// pre-match `ROOM_STATE` (`{roomCode, matchStatus}` only).
  static bool hasDealFields(Map<String, dynamic> json) => json.containsKey('dealNumber');
}

/// One meld out of a `DECLARE_RESULT` event's `melds[]`.
class MeldView {
  final String type;
  final List<Card> cards;

  const MeldView({required this.type, required this.cards});

  factory MeldView.fromJson(Map<String, dynamic> json) {
    final cardsField = json['cards'];
    return MeldView(
      type: json['type'] as String? ?? 'SET',
      cards: cardsField is List ? cardsField.map((c) => Card.fromCode(c as String)).toList() : const [],
    );
  }
}

/// `DECLARE_RESULT` — broadcast to the whole room, whether the declare was
/// valid or not.
class DeclareResultEvent {
  final int userId;
  final bool valid;
  final String? reason;
  final List<MeldView> melds;

  const DeclareResultEvent({required this.userId, required this.valid, this.reason, this.melds = const []});

  factory DeclareResultEvent.fromJson(Map<String, dynamic> json) {
    final meldsField = json['melds'];
    return DeclareResultEvent(
      userId: (json['userId'] as num).toInt(),
      valid: json['valid'] as bool? ?? false,
      reason: json['reason'] as String?,
      melds: meldsField is List
          ? meldsField.whereType<Map<String, dynamic>>().map(MeldView.fromJson).toList()
          : const [],
    );
  }
}

/// One row of a `SCORE_UPDATE` event's `scores[]`.
class ScoreRow {
  final int userId;
  final String username;
  final int roundPoints;
  final int cumulativeScore;
  final RummyMatchPlayerStatus? matchPlayerStatus;

  const ScoreRow({
    required this.userId,
    required this.username,
    required this.roundPoints,
    required this.cumulativeScore,
    this.matchPlayerStatus,
  });

  factory ScoreRow.fromJson(Map<String, dynamic> json) {
    return ScoreRow(
      userId: (json['userId'] as num).toInt(),
      username: json['username'] as String? ?? 'Player ${json['userId']}',
      roundPoints: (json['roundPoints'] as num?)?.toInt() ?? 0,
      cumulativeScore: (json['cumulativeScore'] as num?)?.toInt() ?? 0,
      matchPlayerStatus: RummyMatchPlayerStatus.fromWire(json['matchStatus'] as String?),
    );
  }
}

/// `SCORE_UPDATE` — broadcast once a deal ends.
class ScoreUpdateEvent {
  final int? dealNumber;
  final List<ScoreRow> scores;

  const ScoreUpdateEvent({this.dealNumber, this.scores = const []});

  factory ScoreUpdateEvent.fromJson(Map<String, dynamic> json) {
    final scoresField = json['scores'];
    return ScoreUpdateEvent(
      dealNumber: (json['dealNumber'] as num?)?.toInt(),
      scores: scoresField is List
          ? scoresField.whereType<Map<String, dynamic>>().map(ScoreRow.fromJson).toList()
          : const [],
    );
  }
}

/// `MATCH_ENDED` — the whole match is over; `finalScores` keys are userIds
/// (JSON object keys are always strings on the wire, even though the
/// backend's map is keyed by `Long`).
class MatchEndedEvent {
  final int? winnerUserId;
  final Map<int, int> finalScores;

  const MatchEndedEvent({this.winnerUserId, this.finalScores = const {}});

  factory MatchEndedEvent.fromJson(Map<String, dynamic> json) {
    final scoresField = json['finalScores'];
    final scores = <int, int>{};
    if (scoresField is Map) {
      scoresField.forEach((key, value) {
        final id = int.tryParse(key.toString());
        if (id != null) scores[id] = (value as num).toInt();
      });
    }
    return MatchEndedEvent(
      winnerUserId: (json['winnerUserId'] as num?)?.toInt(),
      finalScores: scores,
    );
  }
}

/// Aggregates the live gameplay truth for the table screen: the latest deal
/// snapshot plus a client-only "arrangement" of the viewer's own hand that
/// survives incremental draw/discard updates, so drag-to-reorder groupings
/// (a purely visual aid — real meld validation only ever happens
/// server-side on `DECLARE`) aren't wiped out every time a new snapshot
/// arrives.
class RummyGameState {
  DealSnapshot? snapshot;
  int? myUserId;
  List<Card> _handArrangement = const [];

  List<Card> get myHandArrangement => _handArrangement;

  PlayerView? get myPlayerView {
    if (myUserId == null || snapshot == null) return null;
    for (final p in snapshot!.players) {
      if (p.userId == myUserId) return p;
    }
    return null;
  }

  List<PlayerView> get opponents {
    if (snapshot == null) return const [];
    return snapshot!.players.where((p) => p.userId != myUserId).toList();
  }

  bool get isMyTurn => myUserId != null && myUserId == snapshot?.currentTurnUserId;

  bool get hasActiveDeal => snapshot?.dealNumber != null && snapshot?.matchStatus == RummyMatchStatus.inProgress;

  bool get canDraw => hasActiveDeal && isMyTurn && snapshot?.turnPhase == RummyTurnPhase.awaitingDraw;

  bool get canDrop => canDraw;

  bool get canDiscardOrDeclare =>
      hasActiveDeal && isMyTurn && snapshot?.turnPhase == RummyTurnPhase.awaitingDiscard;

  /// Resolves "which seated player am I" the first time the JWT-decoded
  /// username shows up in a snapshot's `players[]` — the deal snapshot
  /// never carries the viewer's own userId directly, only per-seat
  /// `username`/`userId` pairs.
  void resolveMyUserId(String? myUsername) {
    if (myUserId != null || myUsername == null || snapshot == null) return;
    for (final p in snapshot!.players) {
      if (p.username == myUsername) {
        myUserId = p.userId;
        return;
      }
    }
  }

  /// Applies a freshly parsed deal snapshot (from `ROOM_STATE` w/ a live
  /// deal, `DEAL_STARTED`, `TURN_STATE`, `CARD_DRAWN`, `CARD_DISCARDED`, or
  /// `PLAYER_DROPPED`) and reconciles the client-side hand arrangement.
  void applyDealSnapshot(DealSnapshot next, {required bool isFreshDeal}) {
    snapshot = next;
    if (myUserId == null) return;

    List<Card>? myHand;
    for (final p in next.players) {
      if (p.userId == myUserId) {
        myHand = p.hand;
        break;
      }
    }
    if (myHand == null) return;
    _handArrangement = _reconcileArrangement(isFreshDeal ? const [] : _handArrangement, myHand);
  }

  /// Persists a drag-to-reorder (or tap-to-swap) the player performed on
  /// their own hand — purely a client-side visual grouping aid.
  void reorderHand(List<Card> newArrangement) {
    _handArrangement = newArrangement;
  }

  static List<Card> _reconcileArrangement(List<Card> oldArrangement, List<Card> truth) {
    final remaining = List<Card>.from(truth);
    final result = <Card>[];
    for (final card in oldArrangement) {
      final idx = remaining.indexWhere((r) => r == card);
      if (idx != -1) {
        result.add(remaining.removeAt(idx));
      }
    }
    result.addAll(remaining);
    return result;
  }
}
