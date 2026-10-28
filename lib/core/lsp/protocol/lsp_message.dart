import 'dart:convert';

/// خطأ في استجابة JSON-RPC
class LspResponseError {
  final int code;
  final String message;
  final dynamic data;

  const LspResponseError({
    required this.code,
    required this.message,
    this.data,
  });

  factory LspResponseError.fromJson(Map<String, dynamic> json) {
    return LspResponseError(
      code: json['code'] as int? ?? -32603,
      message: json['message'] as String? ?? 'Internal LSP error',
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (data != null) 'data': data,
      };

  @override
  String toString() => 'LspResponseError(code: $code, message: $message)';
}

/// طلب LSP مع انتظار الرد (Request)
class LspRequest {
  static const String jsonrpcVersion = '2.0';

  final int id;
  final String method;
  final dynamic params;

  const LspRequest({
    required this.id,
    required this.method,
    this.params,
  });

  Map<String, dynamic> toJson() => {
        'jsonrpc': jsonrpcVersion,
        'id': id,
        'method': method,
        if (params != null) 'params': params,
      };

  String serialize() => jsonEncode(toJson());

  @override
  String toString() => 'LspRequest(id: $id, method: $method)';
}

/// استجابة لخادم LSP على طلب سابق (Response)
class LspResponse {
  final int? id;
  final dynamic result;
  final LspResponseError? error;

  const LspResponse({
    this.id,
    this.result,
    this.error,
  });

  bool get isSuccess => error == null;
  bool get isError => error != null;

  factory LspResponse.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'];
    final id = idVal is int ? idVal : (idVal is String ? int.tryParse(idVal) : null);

    return LspResponse(
      id: id,
      result: json['result'],
      error: json['error'] != null
          ? LspResponseError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'jsonrpc': '2.0',
        'id': id,
        if (result != null) 'result': result,
        if (error != null) 'error': error!.toJson(),
      };

  String serialize() => jsonEncode(toJson());

  @override
  String toString() => 'LspResponse(id: $id, isSuccess: $isSuccess, error: $error)';
}

/// إشعار أحادي الاتجاه بدون انتظار رد (Notification)
class LspNotification {
  static const String jsonrpcVersion = '2.0';

  final String method;
  final dynamic params;

  const LspNotification({
    required this.method,
    this.params,
  });

  factory LspNotification.fromJson(Map<String, dynamic> json) {
    return LspNotification(
      method: json['method'] as String? ?? '',
      params: json['params'],
    );
  }

  Map<String, dynamic> toJson() => {
        'jsonrpc': jsonrpcVersion,
        'method': method,
        if (params != null) 'params': params,
      };

  String serialize() => jsonEncode(toJson());

  @override
  String toString() => 'LspNotification(method: $method)';
}
