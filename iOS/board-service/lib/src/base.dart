import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../board_session_persistent.dart';

String kDefaultUserAgent =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

class BoardHttpClient {
  static http.Client create({String? proxyUrl}) {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    if (proxyUrl != null && proxyUrl.isNotEmpty) {
      client.findProxy = (uri) {
        if (uri.scheme == 'http' || uri.scheme == 'https') {
          return 'PROXY $proxyUrl;DIRECT';
        }
        return 'DIRECT';
      };
    }
    return IOClient(client);
  }
}

class BoardResponseBase {
  final int statusCode;
  final Map<String, dynamic>? json;
  final String text;

  BoardResponseBase(this.statusCode, this.json, this.text);

  bool get ok => false;

  String getFullMessage() {
    final json = this.json;
    if (json != null) {
      final message = json['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
      final errors = json['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) {
          return '${first.first}';
        }
        return '$errors';
      }
      final data = json['data'];
      if (data is Map) {
        final dataErrors = data['errors'];
        if (dataErrors is Map && dataErrors.isNotEmpty) {
          final first = dataErrors.values.first;
          if (first is List && first.isNotEmpty) {
            return '${first.first}';
          }
          return '$dataErrors';
        }
        final dataMessage = data['message'];
        if (dataMessage is String && dataMessage.isNotEmpty) {
          return dataMessage;
        }
      }
    }
    if (statusCode != 200) {
      return 'HTTP $statusCode';
    }
    return '';
  }
}

class JsonResult {
  final int statusCode;
  final Map<String, dynamic>? json;
  final String text;

  JsonResult(this.statusCode, this.json, this.text);
}

abstract class BaseBoardClient {
  String baseUrl;
  List<String> baseDomains;
  String id;
  BoardSessionPersistent persistent;
  String? proxyUrl;
  String userAgent = kDefaultUserAgent;
  Duration timeout = const Duration(seconds: 10);
  String account = "";
  String authToken = "";
  Map<String, String> botHeaders = {};
  List<String> botCookies = [];

  BaseBoardClient({
    required this.baseUrl,
    required this.baseDomains,
    required this.id,
    required this.persistent,
  });

  void setAccount(String account) {
    this.account = account;
  }

  void setAuthToken(String token) {
    authToken = token;
  }

  void setHeadersAndCookiesForBot(
    Map<String, String> headers,
    List<String> cookies,
  ) {
    botHeaders = headers;
    botCookies = cookies;
  }

  Map<String, String>? getAuthHeaders() {
    if (authToken.isEmpty) {
      return null;
    }
    return {"Authorization": "Bearer $authToken"};
  }

  Map<String, String>? getAuthCookies() => null;

  Map<String, String>? getAuthLocalStorage() => null;

  Future<http.Response> request(
    String method,
    String path, {
    Map<String, String>? headers,
    Object? body,
    Map<String, dynamic>? query,
    bool formEncode = false,
  }) async {
    final client = BoardHttpClient.create(proxyUrl: proxyUrl);
    try {
      var uri = Uri.parse(baseUrl + path);
      if (query != null && query.isNotEmpty) {
        uri = uri.replace(queryParameters: query.map(
          (key, value) => MapEntry(key, '$value'),
        ));
      }
      final baseHeaders = <String, String>{
        'User-Agent': userAgent,
        'Accept': 'application/json, text/plain, */*',
        if (!formEncode) 'Content-Type': 'application/json',
        ...?getAuthHeaders(),
        ...?headers,
      };
      if (botCookies.isNotEmpty) {
        baseHeaders['Cookie'] = botCookies.join('; ');
      }

      final encoded = body == null
          ? null
          : (body is String ? body : (formEncode ? body : jsonEncode(body)));

      late http.Response resp;
      switch (method) {
        case 'GET':
          resp = await client
              .get(uri, headers: baseHeaders)
              .timeout(timeout);
        case 'POST':
          resp = await client
              .post(uri, headers: baseHeaders, body: encoded)
              .timeout(timeout);
        case 'PUT':
          resp = await client
              .put(uri, headers: baseHeaders, body: encoded)
              .timeout(timeout);
        case 'DELETE':
          resp = await client
              .delete(uri, headers: baseHeaders)
              .timeout(timeout);
        default:
          throw UnsupportedError("unsupported method $method");
      }
      return resp;
    } finally {
      client.close();
    }
  }

  Future<JsonResult> requestJson(
    String method,
    String path, {
    Map<String, String>? headers,
    Object? body,
    Map<String, dynamic>? query,
    bool formEncode = false,
  }) async {
    final resp = await request(
      method,
      path,
      headers: headers,
      body: body,
      query: query,
      formEncode: formEncode,
    );
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map) {
        json = decoded.cast<String, dynamic>();
      }
    } catch (_) {}
    return JsonResult(resp.statusCode, json, resp.body);
  }
}
