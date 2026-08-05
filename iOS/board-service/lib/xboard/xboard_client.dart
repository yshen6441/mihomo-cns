import '../src/base.dart';
import 'xboard_models.dart';

class XboardClient extends BaseBoardClient {
  XboardClient({
    required super.baseUrl,
    required super.baseDomains,
    required super.id,
    required super.persistent,
  });

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
