import 'dart:convert';

import '../config/api_config.dart';
import '../models/page_response.dart';
import 'api_client.dart';

/// Mirrors the backend's `WalletBalanceResponse` DTO.
class WalletBalance {
  final String username;
  final double balance;

  WalletBalance({required this.username, required this.balance});

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      username: json['username'] as String,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Mirrors the backend's `WalletTransactionResponse` DTO.
class WalletTransactionEntry {
  final int id;
  final String type;
  final double amount;
  final double balanceAfter;
  final String? referenceRoomCode;
  final DateTime? createdAt;

  WalletTransactionEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.referenceRoomCode,
    this.createdAt,
  });

  factory WalletTransactionEntry.fromJson(Map<String, dynamic> json) {
    return WalletTransactionEntry(
      id: json['id'] as int,
      type: json['type'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0,
      referenceRoomCode: json['referenceRoomCode'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
    );
  }
}

/// REST client for `/api/v1/wallet/*`.
///
/// Auth is always [AuthSessionService] via [ApiClient] (refresh on expiry/401).
class WalletApiService {
  WalletApiService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<WalletBalance> getBalance() async {
    final response = await _client.get(ApiConfig.walletBalanceUri);
    if (response.statusCode != 200) {
      throw Exception('Fetch balance failed (${response.statusCode}): ${response.body}');
    }
    return WalletBalance.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<WalletBalance> deposit({required double amount}) async {
    final response = await _client.post(
      ApiConfig.walletDepositUri,
      body: {'amount': amount},
    );
    if (response.statusCode != 200) {
      throw Exception('Deposit failed (${response.statusCode}): ${response.body}');
    }
    return WalletBalance.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<WalletBalance> withdraw({required double amount}) async {
    final response = await _client.post(
      ApiConfig.walletWithdrawUri,
      body: {'amount': amount},
    );
    if (response.statusCode != 200) {
      throw Exception('Withdraw failed (${response.statusCode}): ${response.body}');
    }
    return WalletBalance.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<PageResponse<WalletTransactionEntry>> getTransactions({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _client.get(
      ApiConfig.walletTransactionsUri(page: page, size: size),
    );
    if (response.statusCode != 200) {
      throw Exception('Fetch transactions failed (${response.statusCode}): ${response.body}');
    }
    return PageResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
      WalletTransactionEntry.fromJson,
    );
  }
}
