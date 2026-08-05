abstract final class AppUrlUtilsPrivate {
  static String signQueryParams(
    String version,
    String bodyLen,
    Map<dynamic, dynamic> params,
  ) {
    return "";
  }

  static Future<String> signQueryParams2(
    String version,
    Map<dynamic, dynamic> params, {
    String bodyLen = "0",
  }) async {
    return "";
  }
}

abstract final class BoardProviderPrivate {
  static ({String item1, String item2, String item3}) getBycodeUrlAndBody({
    required String app,
    required String version,
    required String did,
    required String code,
  }) {
    return (item1: "", item2: "", item3: "");
  }

  static ({String item1, String item2, String item3})
      getNotifyIntegrationUrlAndBody({
    required String app,
    required String version,
    required String did,
    required String url,
    required String type,
  }) {
    return (item1: "", item2: "", item3: "");
  }

  static ({String item1, String item2, String item3}) getNoticePushUrlAndBody({
    required String app,
    required String version,
    required String did,
    required String pid,
  }) {
    return (item1: "", item2: "", item3: "");
  }
}

abstract final class ProfileProxyProviderPrivate {
  static ({String item1, String item2, String item3}) getProviderProxyUrlAndBody({
    required String app,
    required String version,
    required String did,
    required String boardProviderId,
    required String url,
    required String userAgent,
    required Map<String, String> xhwidHeaders,
  }) {
    return (item1: "", item2: "", item3: "");
  }
}
