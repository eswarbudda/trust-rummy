import 'package:flutter/foundation.dart';

import '../services/auth_session_service.dart';
import '../services/auth_session_store.dart';
import '../services/match_history_api_service.dart';
import '../services/room_api_service.dart';
import '../services/user_api_service.dart';
import 'lobby_models.dart';

/// Lobby state and room REST orchestration. UI listens via [ListenableBuilder].
class LobbyController extends ChangeNotifier {
  LobbyController({
    AuthSessionService? session,
    AuthSessionStore? store,
    UserApiService? userApi,
    RoomApiService? roomApi,
    MatchHistoryApiService? historyApi,
  })  : _session = session ?? AuthSessionService.instance,
        _store = store ?? AuthSessionStore(),
        _userApi = userApi ?? UserApiService(),
        _roomApi = roomApi ?? RoomApiService(),
        _historyApi = historyApi ?? MatchHistoryApiService();

  final AuthSessionService _session;
  final AuthSessionStore _store;
  final UserApiService _userApi;
  final RoomApiService _roomApi;
  final MatchHistoryApiService _historyApi;

  UserProfile? profile;
  List<CreatedRoom> openRooms = const [];
  List<MatchHistoryItem> recentMatches = const [];
  ResumeMatchInfo? resumeMatch;

  static const int historyPageSize = 5;
  int historyPage = 0;
  int historyTotalPages = 0;
  int historyTotalElements = 0;
  bool historyLoading = false;

  bool loading = false;
  String? errorMessage;

  String? get username => profile?.displayName?.trim().isNotEmpty == true
      ? profile!.displayName
      : (profile?.username ?? _session.username);

  double get walletBalance => profile?.walletBalance ?? 0;

  bool get historyHasPrev => historyPage > 0;
  bool get historyHasNext => historyTotalPages > 0 && historyPage < historyTotalPages - 1;

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _session.ensureSignedIn();
      final profileFuture = _userApi.getProfile();
      final roomsFuture = _roomApi.listOpenRooms();
      final historyFuture = _historyApi.listMyMatches(page: 0, size: historyPageSize);
      final resumeFuture = _resolveResume();

      profile = await profileFuture;
      openRooms = await roomsFuture;
      final historyPageData = await historyFuture;
      recentMatches = historyPageData.content;
      historyPage = historyPageData.number;
      historyTotalPages = historyPageData.totalPages;
      historyTotalElements = historyPageData.totalElements;
      resumeMatch = await resumeFuture;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadHistoryPage(int page) async {
    if (page < 0) return;
    if (historyTotalPages > 0 && page >= historyTotalPages) return;
    if (historyLoading) return;

    historyLoading = true;
    notifyListeners();
    try {
      await _session.ensureSignedIn();
      final data = await _historyApi.listMyMatches(page: page, size: historyPageSize);
      recentMatches = data.content;
      historyPage = data.number;
      historyTotalPages = data.totalPages;
      historyTotalElements = data.totalElements;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      historyLoading = false;
      notifyListeners();
    }
  }

  Future<void> historyPrev() => loadHistoryPage(historyPage - 1);

  Future<void> historyNext() => loadHistoryPage(historyPage + 1);

  Future<ResumeMatchInfo?> _resolveResume() async {
    final code = await _store.readLastRoomCode();
    if (code == null || code.isEmpty) return null;
    try {
      final room = await _roomApi.getRoom(roomCode: code);
      final status = room.status.toUpperCase();
      if (status != 'WAITING' && status != 'IN_PROGRESS') {
        await _store.clearLastRoomCode();
        return null;
      }
      final me = _session.username;
      final seated = room.players.any((p) => p.username == me);
      if (!seated) {
        await _store.clearLastRoomCode();
        return null;
      }
      return ResumeMatchInfo(
        roomCode: room.roomCode,
        status: room.status,
        gameVariant: room.gameVariant,
        playerCount: room.players.length,
        maxPlayers: room.maxPlayers,
      );
    } catch (_) {
      await _store.clearLastRoomCode();
      return null;
    }
  }

  Future<CreatedRoom> createRoom({
    required String gameVariant,
    required int maxPlayers,
    required double stakeAmount,
    int? dealsPerMatch,
  }) async {
    await _session.ensureSignedIn();
    final room = await _roomApi.createRoom(
      gameVariant: gameVariant,
      maxPlayers: maxPlayers,
      stakeAmount: stakeAmount,
      dealsPerMatch: dealsPerMatch,
    );
    await _store.saveLastRoomCode(room.roomCode);
    resumeMatch = ResumeMatchInfo(
      roomCode: room.roomCode,
      status: room.status,
      gameVariant: room.gameVariant ?? gameVariant,
      playerCount: room.players.length,
      maxPlayers: room.maxPlayers ?? maxPlayers,
    );
    notifyListeners();
    return room;
  }

  Future<CreatedRoom> joinRoom(String roomCode) async {
    await _session.ensureSignedIn();
    final code = roomCode.trim().toUpperCase();
    if (!isValidLobbyRoomCode(code)) {
      throw Exception('Enter a valid 6-character room code');
    }
    final room = await _roomApi.joinRoom(roomCode: code);
    await _store.saveLastRoomCode(room.roomCode);
    resumeMatch = ResumeMatchInfo(
      roomCode: room.roomCode,
      status: room.status,
      gameVariant: room.gameVariant,
      playerCount: room.players.length,
      maxPlayers: room.maxPlayers,
    );
    notifyListeners();
    return room;
  }

  Future<CreatedRoom> refreshRoom(String roomCode) =>
      _roomApi.getRoom(roomCode: roomCode);

  Future<void> leaveRoom(String roomCode) async {
    await _session.ensureSignedIn();
    await _roomApi.leaveRoom(roomCode: roomCode);
    final last = await _store.readLastRoomCode();
    if (last == roomCode.toUpperCase()) {
      await _store.clearLastRoomCode();
      resumeMatch = null;
      notifyListeners();
    }
  }

  Future<void> cancelRoom(String roomCode) async {
    await _session.ensureSignedIn();
    await _roomApi.cancelRoom(roomCode: roomCode);
    final last = await _store.readLastRoomCode();
    if (last == roomCode.toUpperCase()) {
      await _store.clearLastRoomCode();
      resumeMatch = null;
      notifyListeners();
    }
  }

  Future<void> clearFinishedRoom(String roomCode) async {
    final last = await _store.readLastRoomCode();
    if (last == roomCode.toUpperCase()) {
      await _store.clearLastRoomCode();
      resumeMatch = null;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _session.logout();
    profile = null;
    openRooms = const [];
    recentMatches = const [];
    historyPage = 0;
    historyTotalPages = 0;
    historyTotalElements = 0;
    resumeMatch = null;
    notifyListeners();
  }
}
