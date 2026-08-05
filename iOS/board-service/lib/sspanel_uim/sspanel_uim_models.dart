import '../src/base.dart';

class LoginResponse extends BoardResponseBase {
  LoginResponse(super.statusCode, super.json, super.text);

  bool get ret {
    final json = this.json;
    if (json == null) {
      return false;
    }
    return json['ret'] == true || json['ret'] == 1;
  }

  @override
  bool get ok => statusCode == 200 && ret;

  String? get token {
    final json = this.json;
    final data = json?['data'];
    if (data is Map) {
      final token = data['token'];
      if (token is String) {
        return token;
      }
    }
    return null;
  }

  @override
  String getFullMessage() {
    final json = this.json;
    if (json != null) {
      final msg = json['msg'];
      if (msg is String && msg.isNotEmpty) {
        return msg;
      }
    }
    return super.getFullMessage();
  }
}

class UserProfileData {
  final String item1;
  final String item2;

  UserProfileData.fromJson(Map<String, dynamic> json)
      : item1 = json['item1'] as String? ?? "",
        item2 = json['item2'] as String? ?? "";
}

class UserProfileUrlResponse extends BoardResponseBase {
  UserProfileUrlResponse(super.statusCode, super.json, super.text);

  bool get ret {
    final json = this.json;
    if (json == null) {
      return false;
    }
    return json['ret'] == true || json['ret'] == 1;
  }

  @override
  bool get ok => statusCode == 200 && ret;

  UserProfileData? get data {
    final json = this.json;
    final d = json?['data'];
    if (d is Map) {
      return UserProfileData.fromJson(d.cast<String, dynamic>());
    }
    return null;
  }

  String? get item1 {
    final json = this.json;
    final data = json?['data'];
    if (data is Map) {
      final value = data['item1'];
      if (value is String) {
        return value;
      }
    }
    return null;
  }

  String? get item2 {
    final json = this.json;
    final data = json?['data'];
    if (data is Map) {
      final value = data['item2'];
      if (value is String) {
        return value;
      }
    }
    return null;
  }

  @override
  String getFullMessage() {
    final json = this.json;
    if (json != null) {
      final msg = json['msg'];
      if (msg is String && msg.isNotEmpty) {
        return msg;
      }
    }
    return super.getFullMessage();
  }
}
