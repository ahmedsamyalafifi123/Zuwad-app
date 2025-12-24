// Standard API response model for Zuwad REST API v2.
//
// All v2 endpoints return responses in this format:
// {
//   "success": true,
//   "data": { ... },
//   "meta": { "page": 1, "per_page": 20, "total": 150, "total_pages": 8 }
// }

/// Error information from the API
class ApiError {
  final String code;
  final String message;
  final int status;

  const ApiError({
    required this.code,
    required this.message,
    required this.status,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      code: json['code'] as String? ?? 'unknown',
      message: json['message'] as String? ?? 'Unknown error',
      status: json['status'] as int? ?? 500,
    );
  }

  @override
  String toString() => 'ApiError($code): $message';
}

/// Pagination metadata from the API
class ApiMeta {
  final int page;
  final int perPage;
  final int total;
  final int totalPages;

  const ApiMeta({
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  factory ApiMeta.fromJson(Map<String, dynamic> json) {
    return ApiMeta(
      page: json['page'] as int? ?? 1,
      perPage: json['per_page'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
      totalPages: json['total_pages'] as int? ?? 1,
    );
  }

  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;
}

/// Generic API response wrapper for v2 endpoints
class ApiResponse<T> {
  final bool success;
  final T? data;
  final ApiError? error;
  final ApiMeta? meta;

  const ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.meta,
  });

  /// Whether the response contains valid data
  bool get hasData => success && data != null;

  /// Whether the response contains an error
  bool get hasError => !success && error != null;

  /// Factory constructor for parsing JSON with a custom data parser
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json) fromJsonT,
  ) {
    final success = json['success'] as bool? ?? false;

    return ApiResponse<T>(
      success: success,
      data: success && json['data'] != null ? fromJsonT(json['data']) : null,
      error: !success && json['error'] != null
          ? ApiError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
      meta: json['meta'] != null
          ? ApiMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Factory for simple responses where data is the raw JSON
  factory ApiResponse.fromJsonRaw(Map<String, dynamic> json) {
    final success = json['success'] as bool? ?? false;

    return ApiResponse<T>(
      success: success,
      data: success ? json['data'] as T? : null,
      error: !success && json['error'] != null
          ? ApiError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
      meta: json['meta'] != null
          ? ApiMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Get data or throw if not available
  T getDataOrThrow() {
    if (hasData) return data as T;
    if (hasError) throw Exception(error!.message);
    throw Exception('No data available');
  }
}

/// Specialized response for paginated list endpoints
class PaginatedResponse<T> {
  final List<T> items;
  final ApiMeta meta;

  const PaginatedResponse({
    required this.items,
    required this.meta,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) fromJsonT,
  ) {
    final success = json['success'] as bool? ?? false;

    if (!success) {
      throw Exception(json['error']?['message'] ?? 'Failed to load data');
    }

    final dataList = json['data'] as List<dynamic>? ?? [];
    final items = dataList
        .map((item) => fromJsonT(item as Map<String, dynamic>))
        .toList();

    final meta = json['meta'] != null
        ? ApiMeta.fromJson(json['meta'] as Map<String, dynamic>)
        : ApiMeta(
            page: 1, perPage: items.length, total: items.length, totalPages: 1);

    return PaginatedResponse<T>(
      items: items,
      meta: meta,
    );
  }
}
