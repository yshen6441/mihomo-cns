import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'proxy_manager.dart';
import 'state.dart';

typedef VpnServiceStateChangedHandler = void Function(
  FlutterVpnServiceState state,
  Map<String, String> params,
);

class FlutterVpnService {
  static const MethodChannel _channel = MethodChannel('libclash_vpn_service');
  static const EventChannel _stateChannel =
      EventChannel('libclash_vpn_service/state');

  static bool _listening = false;
  static FlutterVpnServiceState _currentState =
      FlutterVpnServiceState.disconnected;
  static final List<VpnServiceStateChangedHandler> _stateHandlers = [];

  static Future<FlutterVpnServiceState> get currentState async {
    try {
      final name = await _channel.invokeMethod<String>('getState');
      _currentState = FlutterVpnServiceState.fromName(name);
    } catch (_) {}
    return _currentState;
  }

  static void onStateChanged(VpnServiceStateChangedHandler handler) {
    _stateHandlers.add(handler);
    _ensureListening();
  }

  static void _ensureListening() {
    if (_listening) {
      return;
    }
    _listening = true;
    _stateChannel.receiveBroadcastStream().listen((event) {
      Map<String, dynamic> data = (event as Map?)?.cast<String, dynamic>() ?? {};
      FlutterVpnServiceState state =
          FlutterVpnServiceState.fromName(data["state"] as String?);
      _currentState = state;
      Map<String, String> params =
          (data["params"] as Map?)?.cast<String, String>() ?? {};
      for (var handler in List.of(_stateHandlers)) {
        try {
          handler(state, params);
        } catch (_) {}
      }
    }, onError: (_) {});
  }

  static Future<Directory?> getAppGroupDirectory(String groupId) async {
    try {
      final path = await _channel.invokeMethod<String>('getAppGroupDirectory', {
        "groupId": groupId,
      });
      if (path == null || path.isEmpty) {
        return null;
      }
      return Directory(path);
    } catch (_) {
      return null;
    }
  }

  static Future<String> getSystemVersion() async {
    try {
      return await _channel.invokeMethod<String>('getSystemVersion') ?? "";
    } catch (_) {
      return "";
    }
  }

  static Future<String> clashiApiConnections(bool showTraffic) async {
    try {
      return await _channel.invokeMethod<String>('clashiApiConnections', {
        "showTraffic": showTraffic,
      }) ?? "{}";
    } catch (_) {
      return "{}";
    }
  }

  static Future<String> clashiApiTraffic() async {
    try {
      return await _channel.invokeMethod<String>('clashiApiTraffic') ??
          '{"up":0,"down":0}';
    } catch (_) {
      return '{"up":0,"down":0}';
    }
  }

  static Future<VpnServiceResultError?> installService() async {
    try {
      final json = await _channel.invokeMethod<dynamic>('installService');
      return VpnServiceResultError.fromDynamic(json);
    } catch (_) {
      return null;
    }
  }

  static Future<VpnServiceResultError?> uninstallService() async {
    try {
      final json = await _channel.invokeMethod<dynamic>('uninstallService');
      return VpnServiceResultError.fromDynamic(json);
    } catch (_) {
      return null;
    }
  }

  static Future<void> prepareConfig({
    required VpnServiceConfig config,
    required String tunnelServicePath,
    required String configFilePath,
    required bool systemExtension,
    required String bundleIdentifier,
    required String controlKind,
    required String uiServerAddress,
    required String uiLocalizedDescription,
    required List<int> excludePorts,
  }) async {
    await _channel.invokeMethod<void>('prepareConfig', {
      "config": config.toJson(),
      "tunnelServicePath": tunnelServicePath,
      "configFilePath": configFilePath,
      "systemExtension": systemExtension,
      "bundleIdentifier": bundleIdentifier,
      "controlKind": controlKind,
      "uiServerAddress": uiServerAddress,
      "uiLocalizedDescription": uiLocalizedDescription,
      "excludePorts": excludePorts,
    });
  }

  static Future<VpnServiceWaitResult> start(Duration timeout) async {
    return _wait('start', timeout);
  }

  static Future<VpnServiceWaitResult> restart(Duration timeout) async {
    return _wait('restart', timeout);
  }

  static Future<VpnServiceWaitResult> _wait(
    String method,
    Duration timeout,
  ) async {
    try {
      final json = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        method,
        {"timeout": timeout.inMilliseconds},
      );
      return VpnServiceWaitResult.fromJson(json?.cast<String, dynamic>() ?? {});
    } catch (err) {
      return VpnServiceWaitResult.error(VpnServiceResultError.error(
        err.toString(),
      ));
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  static Future<void> setAlwaysOn(bool enable) async {
    try {
      await _channel.invokeMethod<void>('setAlwaysOn', {"enable": enable});
    } catch (_) {}
  }

  static Future<String?> setExcludeFromRecents(bool enable) async {
    try {
      await _channel.invokeMethod<void>('setExcludeFromRecents', {
        "enable": enable,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<void> hideDockIcon(bool hide) async {
    try {
      await _channel.invokeMethod<void>('hideDockIcon', {"hide": hide});
    } catch (_) {}
  }

  static Future<String> getABIs() async {
    try {
      return await _channel.invokeMethod<String>('getABIs') ?? "[]";
    } catch (_) {
      return "[]";
    }
  }

  static Future<bool> isRunAsAdmin() async {
    try {
      return await _channel.invokeMethod<bool>('isRunAsAdmin') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> firewallAddApp(String path, String name) async {
    try {
      await _channel.invokeMethod<void>('firewallAddApp', {
        "path": path,
        "name": name,
      });
    } catch (_) {}
  }

  static Future<void> firewallAddPorts(List<int> ports, String name) async {
    try {
      await _channel.invokeMethod<void>('firewallAddPorts', {
        "ports": ports,
        "name": name,
      });
    } catch (_) {}
  }

  static Future<void> setSystemProxy(ProxyOption options) async {
    try {
      await _channel.invokeMethod<void>('setSystemProxy', options.toJson());
    } catch (_) {}
  }

  static Future<void> cleanSystemProxy() async {
    try {
      await _channel.invokeMethod<void>('cleanSystemProxy');
    } catch (_) {}
  }

  static Future<bool> getSystemProxyEnable(ProxyOption options) async {
    try {
      return await _channel.invokeMethod<bool>('getSystemProxyEnable',
              options.toJson()) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> autoStartCreate(
    String name,
    String path, {
    String? processArgs,
    bool runElevated = false,
  }) async {
    try {
      await _channel.invokeMethod<void>('autoStartCreate', {
        "name": name,
        "path": path,
        "processArgs": processArgs,
        "runElevated": runElevated,
      });
    } catch (_) {}
  }

  static Future<void> autoStartDelete(String name) async {
    try {
      await _channel.invokeMethod<void>('autoStartDelete', {"name": name});
    } catch (_) {}
  }

  static Future<bool> autoStartIsActive(String name) async {
    try {
      return await _channel.invokeMethod<bool>('autoStartIsActive', {
        "name": name,
      }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isServiceAuthorized(String servicePath) async {
    try {
      return await _channel.invokeMethod<bool>('isServiceAuthorized', {
        "servicePath": servicePath,
      }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<VpnServiceResultError?> authorizeService(
    String servicePath,
    String password,
  ) async {
    try {
      final json = await _channel.invokeMethod<dynamic>('authorizeService', {
        "servicePath": servicePath,
        "password": password,
      });
      return VpnServiceResultError.fromDynamic(json);
    } catch (_) {
      return null;
    }
  }
}
