class AppException implements Exception {
  final String message;
  final String? prefix;
  final String? url;

  AppException([this.message = '', this.prefix, this.url]);

  @override
  String toString() {
    return "$prefix$message";
  }
}

class FetchDataException extends AppException {
  FetchDataException([String? message, String? url])
      : super(message ?? "Error During Communication", "Communication Error: ", url);
}

class BadRequestException extends AppException {
  BadRequestException([String? message, String? url])
      : super(message ?? "Invalid Request", "Bad Request: ", url);
}

class UnauthorisedException extends AppException {
  UnauthorisedException([String? message, String? url])
      : super(message ?? "Unauthorised", "Unauthorised: ", url);
}

class InvalidInputException extends AppException {
  InvalidInputException([String? message, String? url])
      : super(message ?? "Invalid Input", "Invalid Input: ", url);
}

class NotFoundException extends AppException {
  NotFoundException([String? message, String? url])
      : super(message ?? "Not Found", "Not Found: ", url);
}

class ServerException extends AppException {
  ServerException([String? message, String? url])
      : super(message ?? "Server Error", "Server Error: ", url);
}
