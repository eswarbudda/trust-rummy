import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/page_response.dart';
import '../services/auth_api_service.dart';
import '../services/auth_session_service.dart';
import '../services/match_history_api_service.dart';
import '../services/user_api_service.dart';
import '../services/wallet_api_service.dart';

/// Functional (non-visual) connection-verification tool for every REST
/// endpoint that isn't the game-engine WebSocket or the lobby-room routes
/// (those live in `GameTestScreen`) — Auth lifecycle (register/login/
/// refresh/logout), Profile, Wallet, and Match History/Audit. Same
/// minimalist pattern: plain buttons that fire one request each and dump
/// the raw response into a scrollable console below.
class AccountTestScreen extends StatefulWidget {
  const AccountTestScreen({super.key});

  @override
  State<AccountTestScreen> createState() => _AccountTestScreenState();
}

class _AccountTestScreenState extends State<AccountTestScreen> {
  final _session = AuthSessionService.instance;
  final _userApi = UserApiService();
  final _walletApi = WalletApiService();
  final _historyApi = MatchHistoryApiService();
  static final Random _random = Random();

  final _tokenController = TextEditingController();
  final _refreshTokenController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _amountController = TextEditingController(text: '100');
  final _sessionIdController = TextEditingController();
  final _scrollController = ScrollController();

  final List<String> _log = [];
  bool _busy = false;

  static const _jsonEncoder = JsonEncoder.withIndent('  ');

  @override
  void dispose() {
    _tokenController.dispose();
    _refreshTokenController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _amountController.dispose();
    _sessionIdController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _appendLog(String label, Object payload) {
    setState(() {
      _log.add('>> $label\n${_jsonEncoder.convert(payload)}');
      if (_log.length > 200) _log.removeAt(0);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  void _appendError(String label, Object error) {
    setState(() {
      _log.add('!! $label FAILED\n$error');
      if (_log.length > 200) _log.removeAt(0);
    });
  }

  Future<void> _run(String label, Future<Object> Function() action) async {
    setState(() => _busy = true);
    try {
      final result = await action();
      _appendLog(label, result);
    } catch (e) {
      _appendError(label, e);
    } finally {
      setState(() => _busy = false);
    }
  }

  String get _jwt => _tokenController.text.trim();

  @override
  void initState() {
    super.initState();
    _hydrateFromSession();
  }

  Future<void> _hydrateFromSession() async {
    await _session.restore();
    if (!mounted) return;
    if (_session.accessToken != null) {
      _tokenController.text = _session.accessToken!;
    }
    if (_session.refreshToken != null) {
      _refreshTokenController.text = _session.refreshToken!;
    }
    if (_session.username != null) {
      _usernameController.text = _session.username!;
    }
    setState(() {});
  }

  void _syncControllersFrom(AuthResult result) {
    _tokenController.text = result.token;
    _refreshTokenController.text = result.refreshToken ?? '';
    _usernameController.text = result.username;
  }

  // ---- Auth ----

  Future<void> _fillRandomAccount() async {
    final suffix = _random.nextInt(999999).toString().padLeft(6, '0');
    setState(() {
      _usernameController.text = 'acct_$suffix';
      _emailController.text = 'acct_$suffix@trust-rummy.test';
      _passwordController.text = 'AccountTest#123';
      _displayNameController.text = 'Account Tester $suffix';
    });
  }

  Future<void> _register() => _run('REGISTER', () async {
        final result = await _session.register(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _displayNameController.text.trim(),
        );
        _syncControllersFrom(result);
        return {
          'username': result.username,
          'token': result.token,
          'refreshToken': result.refreshToken,
          'expiresInMs': result.expiresInMs,
          'storedInSecureStorage': true,
        };
      });

  Future<void> _login() => _run('LOGIN', () async {
        final result = await _session.login(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
        _syncControllersFrom(result);
        return {
          'username': result.username,
          'token': result.token,
          'refreshToken': result.refreshToken,
          'expiresInMs': result.expiresInMs,
          'storedInSecureStorage': true,
        };
      });

  Future<void> _refreshToken() => _run('REFRESH TOKEN', () async {
        final ok = await _session.refreshAccessToken();
        if (!ok) {
          throw Exception('Refresh failed — register/login first or refresh token revoked');
        }
        _tokenController.text = _session.accessToken ?? '';
        _refreshTokenController.text = _session.refreshToken ?? '';
        return {
          'username': _session.username,
          'token': _session.accessToken,
          'refreshToken': _session.refreshToken,
        };
      });

  Future<void> _logout() => _run('LOGOUT', () async {
        await _session.logout();
        _tokenController.clear();
        _refreshTokenController.clear();
        return {'status': 'refresh revoked + secure storage cleared'};
      });

  // ---- Profile ----

  Future<void> _fetchProfile() => _run('FETCH MY PROFILE', () async {
        await _session.ensureSignedIn(pastedAccessToken: _jwt);
        final profile = await _userApi.getProfile();
        _tokenController.text = _session.accessToken ?? _tokenController.text;
        return _profileToMap(profile);
      });

  Future<void> _updateProfile() => _run('UPDATE PROFILE', () async {
        await _session.ensureSignedIn(pastedAccessToken: _jwt);
        final profile = await _userApi.updateProfile(
          displayName: _displayNameController.text.trim().isEmpty ? null : _displayNameController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        );
        _tokenController.text = _session.accessToken ?? _tokenController.text;
        return _profileToMap(profile);
      });

  Future<void> _changePassword() => _run('CHANGE PASSWORD', () async {
        await _session.ensureSignedIn(pastedAccessToken: _jwt);
        await _userApi.changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        );
        _tokenController.clear();
        _refreshTokenController.clear();
        return {
          'status': 'password changed; all refresh tokens revoked; local session cleared',
        };
      });

  Map<String, dynamic> _profileToMap(UserProfile p) => {
        'id': p.id,
        'username': p.username,
        'email': p.email,
        'displayName': p.displayName,
        'walletBalance': p.walletBalance,
        'role': p.role,
        'createdAt': p.createdAt?.toIso8601String(),
      };

  // ---- Wallet ----

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  Future<void> _fetchBalance() => _run('WALLET BALANCE', () async {
        await _session.ensureSignedIn(pastedAccessToken: _jwt);
        final balance = await _walletApi.getBalance();
        _tokenController.text = _session.accessToken ?? _tokenController.text;
        return {'username': balance.username, 'balance': balance.balance};
      });

  Future<void> _deposit() => _run('WALLET DEPOSIT', () async {
        await _session.ensureSignedIn(pastedAccessToken: _jwt);
        final balance = await _walletApi.deposit(amount: _amount);
        _tokenController.text = _session.accessToken ?? _tokenController.text;
        return {'username': balance.username, 'balance': balance.balance};
      });

  Future<void> _withdraw() => _run('WALLET WITHDRAW', () async {
        await _session.ensureSignedIn(pastedAccessToken: _jwt);
        final balance = await _walletApi.withdraw(amount: _amount);
        _tokenController.text = _session.accessToken ?? _tokenController.text;
        return {'username': balance.username, 'balance': balance.balance};
      });

  Future<void> _fetchTransactions() => _run('WALLET TRANSACTIONS', () async {
        await _session.ensureSignedIn(pastedAccessToken: _jwt);
        final page = await _walletApi.getTransactions();
        _tokenController.text = _session.accessToken ?? _tokenController.text;
        return _pageToMap(page, (t) => {
              'id': t.id,
              'type': t.type,
              'amount': t.amount,
              'balanceAfter': t.balanceAfter,
              'createdAt': t.createdAt?.toIso8601String(),
            });
      });

  // ---- Match history ----

  Future<void> _fetchMatchHistory() => _run('MATCH HISTORY', () async {
        await _session.ensureSignedIn(pastedAccessToken: _jwt);
        final page = await _historyApi.listMyMatches();
        _tokenController.text = _session.accessToken ?? _tokenController.text;
        return _pageToMap(page, (m) => {
              'sessionId': m.sessionId,
              'roomCode': m.roomCode,
              'status': m.status,
              'stakeAmount': m.stakeAmount,
              'winnerUsername': m.winnerUsername,
              'myFinalScore': m.myFinalScore,
            });
      });

  int? get _sessionId => int.tryParse(_sessionIdController.text.trim());

  Future<void> _fetchMatchDetail() => _run('MATCH DETAIL', () async {
        if (_sessionId == null) throw Exception('Enter a numeric session id first');
        await _session.ensureSignedIn(pastedAccessToken: _jwt);
        final detail = await _historyApi.getMatchDetail(sessionId: _sessionId!);
        _tokenController.text = _session.accessToken ?? _tokenController.text;
        return {
          'sessionId': detail.sessionId,
          'roomCode': detail.roomCode,
          'status': detail.status,
          'winnerUsername': detail.winnerUsername,
          'players': detail.players
              .map((p) => {'username': p.username, 'seatNumber': p.seatNumber, 'finalScore': p.finalScore, 'status': p.status})
              .toList(),
        };
      });

  Future<void> _fetchMatchMoves() => _run('MATCH MOVES', () async {
        if (_sessionId == null) throw Exception('Enter a numeric session id first');
        await _session.ensureSignedIn(pastedAccessToken: _jwt);
        final page = await _historyApi.getMatchMoves(sessionId: _sessionId!);
        _tokenController.text = _session.accessToken ?? _tokenController.text;
        return _pageToMap(page, (m) => {'username': m.username, 'moveType': m.moveType, 'sequenceNo': m.sequenceNo});
      });

  Future<void> _fetchScorecard() => _run('SCORECARD', () async {
        await _session.ensureSignedIn(pastedAccessToken: _jwt);
        final s = await _historyApi.getScorecard();
        _tokenController.text = _session.accessToken ?? _tokenController.text;
        return {'totalMatches': s.totalMatches, 'wins': s.wins, 'losses': s.losses, 'netChips': s.netChips, 'bestDealScore': s.bestDealScore};
      });

  Map<String, dynamic> _pageToMap<T>(PageResponse<T> page, Map<String, dynamic> Function(T) toMap) => {
        'totalElements': page.totalElements,
        'totalPages': page.totalPages,
        'page': page.number,
        'content': page.content.map(toMap).toList(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account, Wallet & History — Connection Test'), centerTitle: true),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      _buildAuthCard(),
                      const SizedBox(height: 14),
                      _buildProfileCard(),
                      const SizedBox(height: 14),
                      _buildWalletCard(),
                      const SizedBox(height: 14),
                      _buildHistoryCard(),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Response log', style: Theme.of(context).textTheme.labelLarge),
                ),
                const SizedBox(height: 8),
                SizedBox(height: 220, child: _buildLogConsole()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildAuthCard() {
    return _card(
      title: 'Auth (/api/v1/auth)',
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username', isDense: true, border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password', isDense: true, border: OutlineInputBorder()),
                obscureText: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', isDense: true, border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _displayNameController,
                decoration: const InputDecoration(labelText: 'Display name', isDense: true, border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _busy ? null : _fillRandomAccount, child: const Text('Fill Random Account')),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton(onPressed: _busy ? null : () => _register(), child: const Text('Register')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(onPressed: _busy ? null : () => _login(), child: const Text('Login')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _tokenController,
          decoration: const InputDecoration(labelText: 'Access JWT', isDense: true, border: OutlineInputBorder()),
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _refreshTokenController,
          decoration: const InputDecoration(labelText: 'Refresh token', isDense: true, border: OutlineInputBorder()),
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: _busy ? null : () => _refreshToken(), child: const Text('Refresh Token')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(onPressed: _busy ? null : () => _logout(), child: const Text('Logout')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    return _card(
      title: 'Profile (/api/v1/users)',
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: _busy ? null : () => _fetchProfile(), child: const Text('Fetch My Profile Data')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(onPressed: _busy ? null : () => _updateProfile(), child: const Text('Update Profile')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _currentPasswordController,
                decoration: const InputDecoration(labelText: 'Current password', isDense: true, border: OutlineInputBorder()),
                obscureText: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _newPasswordController,
                decoration: const InputDecoration(labelText: 'New password', isDense: true, border: OutlineInputBorder()),
                obscureText: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _busy ? null : () => _changePassword(), child: const Text('Change Password')),
      ],
    );
  }

  Widget _buildWalletCard() {
    return _card(
      title: 'Wallet (/api/v1/wallet)',
      children: [
        TextField(
          controller: _amountController,
          decoration: const InputDecoration(labelText: 'Amount', isDense: true, border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: _busy ? null : () => _fetchBalance(), child: const Text('Balance')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(onPressed: _busy ? null : () => _deposit(), child: const Text('Deposit')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(onPressed: _busy ? null : () => _withdraw(), child: const Text('Withdraw')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _busy ? null : () => _fetchTransactions(), child: const Text('Transaction Ledger')),
      ],
    );
  }

  Widget _buildHistoryCard() {
    return _card(
      title: 'Match History & Audit (/api/v1/history)',
      children: [
        OutlinedButton(onPressed: _busy ? null : () => _fetchMatchHistory(), child: const Text('Check Historical Matches')),
        const SizedBox(height: 10),
        TextField(
          controller: _sessionIdController,
          decoration: const InputDecoration(labelText: 'Session id (from history above)', isDense: true, border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: _busy ? null : () => _fetchMatchDetail(), child: const Text('Match Detail')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(onPressed: _busy ? null : () => _fetchMatchMoves(), child: const Text('Match Moves')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _busy ? null : () => _fetchScorecard(), child: const Text('My Scorecard')),
      ],
    );
  }

  Widget _buildLogConsole() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.85), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(12),
      child: _log.isEmpty
          ? const Center(
              child: Text('No calls yet — try a button above.', style: TextStyle(color: Colors.white38)),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: _log.length,
              itemBuilder: (context, index) {
                final entry = _log[index];
                final isError = entry.startsWith('!!');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    entry,
                    style: TextStyle(
                      color: isError ? Colors.redAccent : Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
