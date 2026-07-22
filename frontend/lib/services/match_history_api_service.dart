import 'dart:convert';

import '../config/api_config.dart';
import '../models/page_response.dart';
import 'api_client.dart';

/// Mirrors the backend's `MatchHistoryItemResponse` DTO.
class MatchHistoryItem {
  final int sessionId;
  final String roomCode;
  final String? gameVariant;
  final double? stakeAmount;
  final String status;
  final String? winnerUsername;
  final int? myFinalScore;
  final DateTime? startedAt;
  final DateTime? endedAt;

  MatchHistoryItem({
    required this.sessionId,
    required this.roomCode,
    this.gameVariant,
    this.stakeAmount,
    required this.status,
    this.winnerUsername,
    this.myFinalScore,
    this.startedAt,
    this.endedAt,
  });

  factory MatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return MatchHistoryItem(
      sessionId: json['sessionId'] as int,
      roomCode: json['roomCode'] as String,
      gameVariant: json['gameVariant'] as String?,
      stakeAmount: (json['stakeAmount'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'ACTIVE',
      winnerUsername: json['winnerUsername'] as String?,
      myFinalScore: json['myFinalScore'] as int?,
      startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt'] as String) : null,
      endedAt: json['endedAt'] != null ? DateTime.tryParse(json['endedAt'] as String) : null,
    );
  }
}

/// Mirrors the backend's `MatchPlayerResultResponse` DTO.
class MatchPlayerResult {
  final int userId;
  final String username;
  final int? seatNumber;
  final int? finalScore;
  final String status;

  MatchPlayerResult({
    required this.userId,
    required this.username,
    this.seatNumber,
    this.finalScore,
    required this.status,
  });

  factory MatchPlayerResult.fromJson(Map<String, dynamic> json) {
    return MatchPlayerResult(
      userId: json['userId'] as int,
      username: json['username'] as String,
      seatNumber: json['seatNumber'] as int?,
      finalScore: json['finalScore'] as int?,
      status: json['status'] as String? ?? 'JOINED',
    );
  }
}

/// Mirrors the backend's `MatchHistoryDetailResponse` DTO.
class MatchHistoryDetail {
  final int sessionId;
  final String roomCode;
  final String? gameVariant;
  final double? stakeAmount;
  final String status;
  final String? winnerUsername;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final List<MatchPlayerResult> players;

  MatchHistoryDetail({
    required this.sessionId,
    required this.roomCode,
    this.gameVariant,
    this.stakeAmount,
    required this.status,
    this.winnerUsername,
    this.startedAt,
    this.endedAt,
    this.players = const [],
  });

  factory MatchHistoryDetail.fromJson(Map<String, dynamic> json) {
    return MatchHistoryDetail(
      sessionId: json['sessionId'] as int,
      roomCode: json['roomCode'] as String,
      gameVariant: json['gameVariant'] as String?,
      stakeAmount: (json['stakeAmount'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'ACTIVE',
      winnerUsername: json['winnerUsername'] as String?,
      startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt'] as String) : null,
      endedAt: json['endedAt'] != null ? DateTime.tryParse(json['endedAt'] as String) : null,
      players: (json['players'] as List<dynamic>? ?? [])
          .map((p) => MatchPlayerResult.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Mirrors the backend's `MoveLogResponse` DTO.
class MoveLogEntry {
  final String username;
  final String moveType;
  final String? moveData;
  final int? sequenceNo;
  final DateTime? createdAt;

  MoveLogEntry({
    required this.username,
    required this.moveType,
    this.moveData,
    this.sequenceNo,
    this.createdAt,
  });

  factory MoveLogEntry.fromJson(Map<String, dynamic> json) {
    return MoveLogEntry(
      username: json['username'] as String,
      moveType: json['moveType'] as String,
      moveData: json['moveData'] as String?,
      sequenceNo: json['sequenceNo'] as int?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
    );
  }
}

/// Mirrors the backend's `ScorecardSummaryResponse` DTO.
class ScorecardSummary {
  final int totalMatches;
  final int wins;
  final int losses;
  final double netChips;
  final int? bestDealScore;

  ScorecardSummary({
    required this.totalMatches,
    required this.wins,
    required this.losses,
    required this.netChips,
    this.bestDealScore,
  });

  factory ScorecardSummary.fromJson(Map<String, dynamic> json) {
    return ScorecardSummary(
      totalMatches: json['totalMatches'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      netChips: (json['netChips'] as num?)?.toDouble() ?? 0,
      bestDealScore: json['bestDealScore'] as int?,
    );
  }
}

/// REST client for `/api/v1/history/*` (see `MatchHistoryController`).
/// Read-only, long-term records — active gameplay stays on the WebSocket.
///
/// Auth is always [AuthSessionService] via [ApiClient] (refresh on expiry/401).
class MatchHistoryApiService {
  MatchHistoryApiService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<PageResponse<MatchHistoryItem>> listMyMatches({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _client.get(
      ApiConfig.matchHistoryUri(page: page, size: size),
    );
    if (response.statusCode != 200) {
      throw Exception('Fetch match history failed (${response.statusCode}): ${response.body}');
    }
    return PageResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>, MatchHistoryItem.fromJson);
  }

  Future<MatchHistoryDetail> getMatchDetail({required int sessionId}) async {
    final response = await _client.get(ApiConfig.matchDetailUri(sessionId));
    if (response.statusCode != 200) {
      throw Exception('Fetch match detail failed (${response.statusCode}): ${response.body}');
    }
    return MatchHistoryDetail.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<PageResponse<MoveLogEntry>> getMatchMoves({
    required int sessionId,
    int page = 0,
    int size = 50,
  }) async {
    final response = await _client.get(
      ApiConfig.matchMovesUri(sessionId, page: page, size: size),
    );
    if (response.statusCode != 200) {
      throw Exception('Fetch match moves failed (${response.statusCode}): ${response.body}');
    }
    return PageResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>, MoveLogEntry.fromJson);
  }

  Future<ScorecardSummary> getScorecard() async {
    final response = await _client.get(ApiConfig.scorecardUri);
    if (response.statusCode != 200) {
      throw Exception('Fetch scorecard failed (${response.statusCode}): ${response.body}');
    }
    return ScorecardSummary.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
