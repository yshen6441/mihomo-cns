import '../src/base.dart';
import 'sspanel_uim_models.dart';

class SSPanelUimClient extends BaseBoardClient {
  SSPanelUimClient({
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

  @override
  Map<String, String>? getAuthHeaders() {
    if (authToken.isEmpty) {
      return null;
    }
    return {"Authorization": authToken};
  }

  @override
  Map<String, String>? getAuthLocalStorage() {
    if (authToken.isEmpty) {
      return null;
    }
    return {"token": authToken};
  }

  Future<LoginResponse> login(String email, String password) async {
    final result = await requestJson(
      'POST',
      '/auth/login',
      body: {
        "email": email,
        "password": password,
      },
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
    return LoginResponse(200, {'ret': true}, '');
  }

  Future<UserProfileUrlResponse> getUserProfileUrlAndToken() async {
    final result = await requestJson(
      'POST',
      '/user/profile',
      body: {},
    );
    return UserProfileUrlResponse(
      result.statusCode,
      result.json,
      result.text,
    );
  }

  Future<UserProfileUrlResponse> getSubscribe(String token) async {
    setAuthToken(token);
    return getUserProfileUrlAndToken();
  }

  Future<void> logout() async {
    setAuthToken("");
  }
}
