import 'package:board_service/src/base.dart';

import 'v2board_models.dart';

class V2BoardClient extends BaseBoardClient {
  String version = "";

  V2BoardClient({
    required super.baseUrl,
    required super.baseDomains,
    required super.id,
    required super.persistent,
  });

  void setVersion(String version) {
    this.version = version;
  }

  static int getPasswordMinLen() => 8;

  static bool validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return false;
    }
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<LoginResponse> login(LoginRequest request) async {
    final result = await requestJson(
      'POST',
      '/api/v1/passport/auth/login',
      body: request.toJson(),
    );
    final response = LoginResponse(
      result.statusCode,
      result.json,
      result.text,
    );
    if (response.ok) {
      final token = response.token;
      if (token != null && token.isNotEmpty) {
        setAuthToken(token);
        persistent.updateLoginAuthData(id, account, token);
      }
    }
    return response;
  }

  Future<LoginResponse> loginByToken(String token) async {
    setAuthToken(token);
    persistent.updateLoginAuthData(id, account, token);
    return LoginResponse.ok();
  }

  Future<SubscribeResponse> getSubscribe() async {
    final result = await requestJson(
      'GET',
      '/api/v1/user/plan/subscribe',
    );
    return SubscribeResponse(
      result.statusCode,
      result.json,
      result.text,
    );
  }

  Future<UserInfoResponse> getUserInfo() async {
    final result = await requestJson(
      'GET',
      '/api/v1/user/info',
    );
    return UserInfoResponse(
      result.statusCode,
      result.json,
      result.text,
    );
  }

  Future<void> logout() async {
    setAuthToken("");
  }
}
