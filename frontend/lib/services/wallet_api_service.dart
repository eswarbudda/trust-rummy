import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/page_response.dart';

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

/// REST client for `/api/v1/wallet/*` (see `WalletController`).
class WalletApiService {
  Future<WalletBalance> getBalance(String jwt) async {
    final response = await http.get(ApiConfig.walletBalanceUri, headers: _authHeaders(jwt));
    if (response.statusCode != 200) {
      throw Exception('Fetch balance failed (${response.statusCode}): ${response.body}');
    }
    return WalletBalance.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<WalletBalance> deposit({required String jwt, required double amount}) async {
    final response = await http.post(
      ApiConfig.walletDepositUri,
      headers: _authHeaders(jwt),
      body: jsonEncode({'amount': amount}),
    );
    if (response.statusCode != 200) {
      throw Exception('Deposit failed (${response.statusCode}): ${response.body}');
    }
    return WalletBalance.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<WalletBalance> withdraw({required String jwt, required double amount}) async {
    final response = await http.post(
      ApiConfig.walletWithdrawUri,
      headers: _authHeaders(jwt),
      body: jsonEncode({'amount': amount}),
    );
    if (response.statusCode != 200) {
      throw Exception('Withdraw failed (${response.statusCode}): ${response.body}');
    }
    return WalletBalance.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<PageResponse<WalletTransactionEntry>> getTransactions({
    required String jwt,
    int page = 0,
    int size = 20,
  }) async {
    final response = await http.get(
      ApiConfig.walletTransactionsUri(page: page, size: size),
      headers: _authHeaders(jwt),
    );
    if (response.statusCode != 200) {
      throw Exception('Fetch transactions failed (${response.statusCode}): ${response.body}');
    }
    return PageResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
      WalletTransactionEntry.fromJson,
    );
  }

  Map<String, String> _authHeaders(String jwt) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      };
}
