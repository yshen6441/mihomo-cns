package com.nebula.libclash_vpn_service;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

public class LibclashVpnServicePlugin implements MethodCallHandler {
    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(
                registrar.messenger(), "libclash_vpn_service");
        channel.setMethodCallHandler(new LibclashVpnServicePlugin());
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        switch (call.method) {
            case "getAppGroupDirectory":
                result.success(null);
                break;
            case "getSystemVersion":
                result.success(android.os.Build.VERSION.RELEASE);
                break;
            case "getState":
                result.success("disconnected");
                break;
            case "clashiApiConnections":
                result.success("{}");
                break;
            case "clashiApiTraffic":
                result.success("{\"up\":0,\"down\":0}");
                break;
            case "prepareConfig":
            case "installService":
            case "uninstallService":
            case "setAlwaysOn":
            case "stop":
                result.success(null);
                break;
            case "start":
            case "restart":
                result.success("{\"type\":\"error\",\"err\":{\"code\":-1,\"message\":\"not supported on Android\"}}");
                break;
            case "getABIs":
                result.success("[]");
                break;
            case "isRunAsAdmin":
            case "getSystemProxyEnable":
            case "autoStartIsActive":
            case "isServiceAuthorized":
                result.success(false);
                break;
            case "setExcludeFromRecents":
            case "hideDockIcon":
            case "firewallAddApp":
            case "firewallAddPorts":
            case "setSystemProxy":
            case "cleanSystemProxy":
            case "autoStartCreate":
            case "autoStartDelete":
            case "authorizeService":
                result.success(null);
                break;
            default:
                result.notImplemented();
        }
    }
}
