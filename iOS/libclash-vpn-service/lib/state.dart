import 'dart:convert';

enum FlutterVpnServiceState {
  disconnected,
  connecting,
  connected,
  reasserting,
  disconnecting,
  invalid;

  static FlutterVpnServiceState fromName(String? name) {
    switch (name) {
      case "connecting":
        return FlutterVpnServiceState.connecting;
      case "connected":
        return FlutterVpnServiceState.connected;
      case "reasserting":
        return FlutterVpnServiceState.reasserting;
      case "disconnecting":
        return FlutterVpnServiceState.disconnecting;
      case "invalid":
        return FlutterVpnServiceState.invalid;
      default:
        return FlutterVpnServiceState.disconnected;
    }
  }

  String get name {
    switch (this) {
      case FlutterVpnServiceState.connecting:
        return "connecting";
      case FlutterVpnServiceState.connected:
        return "connected";
      case FlutterVpnServiceState.reasserting:
        return "reasserting";
      case FlutterVpnServiceState.disconnecting:
        return "disconnecting";
      case FlutterVpnServiceState.invalid:
        return "invalid";
      default:
        return "disconnected";
    }
  }
}

enum VpnServiceWaitType {
  error,
  done,
  timeout,
  errorcode;

  static VpnServiceWaitType fromName(String? name) {
    switch (name) {
      case "done":
        return VpnServiceWaitType.done;
      case "timeout":
        return VpnServiceWaitType.timeout;
      case "errorcode":
        return VpnServiceWaitType.errorcode;
      default:
        return VpnServiceWaitType.error;
    }
  }
}

class VpnServiceResultError {
  final int code;
  final String message;

  const VpnServiceResultError(this.code, this.message);

  VpnServiceResultError.error(String message)
      : code = -1,
        message = message;

  Map<String, dynamic> toJson() {
    return {
      "code": code,
      "message": message,
    };
  }

  static VpnServiceResultError? fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return VpnServiceResultError(
      json["code"] as int? ?? -1,
      json["message"] as String? ?? "",
    );
  }

  static VpnServiceResultError? fromDynamic(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is String) {
      return VpnServiceResultError.error(json);
    }
    if (json is Map) {
      return fromJson(json.cast<String, dynamic>());
    }
    return null;
  }
}

class VpnServiceWaitResult {
  final VpnServiceWaitType type;
  final VpnServiceResultError? err;

  VpnServiceWaitResult({required this.type, this.err});

  VpnServiceWaitResult.done()
      : type = VpnServiceWaitType.done,
        err = null;

  VpnServiceWaitResult.timeout()
      : type = VpnServiceWaitType.timeout,
        err = null;

  VpnServiceWaitResult.error(VpnServiceResultError error)
      : type = VpnServiceWaitType.error,
        err = error;

  Map<String, dynamic> toJson() {
    return {
      "type": type.name,
      "err": err?.toJson(),
    };
  }

  static VpnServiceWaitResult fromJson(Map<String, dynamic> json) {
    return VpnServiceWaitResult(
      type: VpnServiceWaitType.fromName(json["type"] as String?),
      err: VpnServiceResultError.fromJson(
        (json["err"] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }
}

class VpnServiceConfig {
  int control_port = 0;
  String base_dir = "";
  String work_dir = "";
  String cache_dir = "";
  String core_path = "";
  String core_path_patch = "";
  String core_path_patch_final = "";
  String log_path = "";
  String err_path = "";
  String id = "";
  String version = "";
  String name = "";
  String secret = "";
  String install_refer = "";
  bool prepare = false;
  bool wake_lock = false;
  bool auto_connect_at_boot = false;
  bool include_all_networks = false;
  bool exclude_local_networks = false;
  bool exclude_cellular_services = false;
  bool exclude_apns = false;
  bool exclude_device_communication = false;
  bool enforce_routes = false;
  bool auto_route_use_sub_ranges_by_default = false;

  Map<String, dynamic> toJson() {
    return {
      "control_port": control_port,
      "base_dir": base_dir,
      "work_dir": work_dir,
      "cache_dir": cache_dir,
      "core_path": core_path,
      "core_path_patch": core_path_patch,
      "core_path_patch_final": core_path_patch_final,
      "log_path": log_path,
      "err_path": err_path,
      "id": id,
      "version": version,
      "name": name,
      "secret": secret,
      "install_refer": install_refer,
      "prepare": prepare,
      "wake_lock": wake_lock,
      "auto_connect_at_boot": auto_connect_at_boot,
      "include_all_networks": include_all_networks,
      "exclude_local_networks": exclude_local_networks,
      "exclude_cellular_services": exclude_cellular_services,
      "exclude_apns": exclude_apns,
      "exclude_device_communication": exclude_device_communication,
      "enforce_routes": enforce_routes,
      "auto_route_use_sub_ranges_by_default": auto_route_use_sub_ranges_by_default,
    };
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  void fromJson(Map<String, dynamic> json) {
    control_port = json["control_port"] as int? ?? 0;
    base_dir = json["base_dir"] as String? ?? "";
    work_dir = json["work_dir"] as String? ?? "";
    cache_dir = json["cache_dir"] as String? ?? "";
    core_path = json["core_path"] as String? ?? "";
    core_path_patch = json["core_path_patch"] as String? ?? "";
    core_path_patch_final = json["core_path_patch_final"] as String? ?? "";
    log_path = json["log_path"] as String? ?? "";
    err_path = json["err_path"] as String? ?? "";
    id = json["id"] as String? ?? "";
    version = json["version"] as String? ?? "";
    name = json["name"] as String? ?? "";
    secret = json["secret"] as String? ?? "";
    install_refer = json["install_refer"] as String? ?? "";
    prepare = json["prepare"] as bool? ?? false;
    wake_lock = json["wake_lock"] as bool? ?? false;
    auto_connect_at_boot = json["auto_connect_at_boot"] as bool? ?? false;
    include_all_networks = json["include_all_networks"] as bool? ?? false;
    exclude_local_networks = json["exclude_local_networks"] as bool? ?? false;
    exclude_cellular_services =
        json["exclude_cellular_services"] as bool? ?? false;
    exclude_apns = json["exclude_apns"] as bool? ?? false;
    exclude_device_communication =
        json["exclude_device_communication"] as bool? ?? false;
    enforce_routes = json["enforce_routes"] as bool? ?? false;
    auto_route_use_sub_ranges_by_default =
        json["auto_route_use_sub_ranges_by_default"] as bool? ?? false;
  }

  static VpnServiceConfig? fromJsonString(String content) {
    try {
      dynamic json = jsonDecode(content);
      if (json is Map) {
        VpnServiceConfig config = VpnServiceConfig();
        config.fromJson(json.cast<String, dynamic>());
        return config;
      }
    } catch (_) {}
    return null;
  }
}
