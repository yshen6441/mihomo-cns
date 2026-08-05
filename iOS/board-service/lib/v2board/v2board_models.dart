import '../src/base.dart';

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() {
    return {
      "email": email,
      "password": password,
    };
  }
}

class BoardResponse extends BoardResponseBase {
  BoardResponse(super.statusCode, super.json, super.text);

  bool get status {
    final json = this.json;
    if (json == null) {
      return false;
    }
    return json['status'] == true || json['status'] == 'true';
  }

  @override
  bool get ok => statusCode == 200 && status;
}

class LoginResponse extends BoardResponse {
  LoginResponse(super.statusCode, super.json, super.text);

  LoginResponse.ok() : super(200, {'status': true}, '');

  String? get token {
    final json = this.json;
    final data = json?['data'];
    if (data is Map) {
      final authData = data['auth_data'];
      if (authData is String) {
        return authData;
      }
      final token = data['token'];
      if (token is String) {
        return token;
      }
    }
    return null;
  }
}

class SubscribeData {
  final String subscribeUrl;

  SubscribeData.fromJson(Map<String, dynamic> json)
      : subscribeUrl = json['subscribe_url'] as String? ?? "";
}

class SubscribeResponse extends BoardResponse {
  SubscribeResponse(super.statusCode, super.json, super.text);

  SubscribeData? get data {
    final json = this.json;
    final d = json?['data'];
    if (d is Map) {
      return SubscribeData.fromJson(d.cast<String, dynamic>());
    }
    return null;
  }

  String? get subscribeUrl {
    final json = this.json;
    final data = json?['data'];
    if (data is Map) {
      final url = data['subscribe_url'];
      if (url is String) {
        return url;
      }
    }
    return null;
  }
}

class UserInfoResponse extends BoardResponse {
  UserInfoResponse(super.statusCode, super.json, super.text);

  int? get planId {
    final json = this.json;
    final data = json?['data'];
    if (data is Map) {
      return data['plan_id'] as int?;
    }
    return null;
  }
}
