import 'dart:convert';

import 'api_client.dart';
import '../config/api_config.dart';

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.payload,
    required this.status,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final String status;
  final DateTime createdAt;
  final DateTime? readAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      readAt: json['readAt'] == null ? null : DateTime.parse(json['readAt'] as String),
    );
  }
}

class NotificationInboxPage {
  NotificationInboxPage({
    required this.items,
    required this.unreadCount,
    required this.page,
    required this.size,
  });

  final List<AppNotification> items;
  final int unreadCount;
  final int page;
  final int size;
}

class NotificationApiService {
  NotificationApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<NotificationInboxPage> list({String? status, int page = 0, int size = 20}) async {
    final response = await _client.get(ApiConfig.notificationsUri(status: status, page: page, size: size));
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (map['items'] as List<dynamic>? ?? const [])
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
    return NotificationInboxPage(
      items: items,
      unreadCount: (map['unreadCount'] as num?)?.toInt() ?? 0,
      page: (map['page'] as num?)?.toInt() ?? page,
      size: (map['size'] as num?)?.toInt() ?? size,
    );
  }

  Future<int> unreadCount() async {
    final response = await _client.get(ApiConfig.notificationsUnreadCountUri);
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return (map['unreadCount'] as num?)?.toInt() ?? 0;
  }

  Future<AppNotification> markRead(String id) async {
    final response = await _client.post(ApiConfig.notificationReadUri(id));
    return AppNotification.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<int> markAllRead() async {
    final response = await _client.post(ApiConfig.notificationsReadAllUri);
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return (map['unreadCount'] as num?)?.toInt() ?? 0;
  }
}
