/// Thin decoder for Spring Data's `Page<T>` JSON shape
/// (`content`, `totalElements`, `totalPages`, `number`, `size`, ...), used by
/// every paginated `/api/v1/wallet/transactions` and `/api/v1/history/**` response.
class PageResponse<T> {
  final List<T> content;
  final int totalElements;
  final int totalPages;
  final int number; // zero-based current page index
  final int size;

  PageResponse({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.number,
    required this.size,
  });

  factory PageResponse.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJsonT) {
    return PageResponse(
      content: (json['content'] as List<dynamic>? ?? const [])
          .map((e) => fromJsonT(e as Map<String, dynamic>))
          .toList(),
      totalElements: json['totalElements'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      number: json['number'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
    );
  }
}
