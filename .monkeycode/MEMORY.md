# User Instruction Memory

This file records user instructions, preferences, and teachings for reference in future interactions.

## Format

### User Instruction Entry
User instruction entries should follow this format:

[User Instruction Summary]
- Date: [YYYY-MM-DD]
- Context: [Mentioned scenario or time]
- Instructions:
  - [Content of user teaching or instruction, described line by line]

### Project Knowledge Entry
Entries discovered by the Agent during task execution should follow this format:

[Project Knowledge Summary]
- Date: [YYYY-MM-DD]
- Context: Discovered by Agent while performing [specific task description]
- Category: [Operations & Deployment|Build Methods|Testing Methods|Troubleshooting & Debugging|Workflow & Collaboration|Environment Configuration]
- Instructions:
  - [Specific knowledge points, described line by line]

## Deduplication Strategy
- Before adding a new entry, check for similar or identical instructions.
- If a duplicate is found, skip the new entry or merge it with the existing one.
- When merging, update the context or date information.
- This helps avoid redundant entries and keeps the memory file tidy.

## Entries

[Project Knowledge Summary]
- Date: 2026-08-05
- Context: Discovered by Agent while building clashmi iOS IPA (越狱直装) for mihomo-cns repo
- Category: Build Methods
- Instructions:
  - Flutter 本机 SDK 下载解压后首次运行报错 "dart-sdk/bin/dart: No such file or directory"：Flutter tar 发行版不含 dart-sdk，首次运行才会下载；若 stamp 残留会导致跳过下载。修复：手动下载 `https://storage.googleapis.com/dart-archive/channels/stable/release/<DART版本>/sdk/dartsdk-linux-x64-release.zip` 解压到 `/opt/flutter/bin/cache/dart-sdk` 并 `touch engine-dart-sdk.stamp`
  - clashmi（iOS/clashmi）要求 `sdk >=3.12.2` / `flutter >=3.35.0`；最新 stable 3.44.8（Dart 3.12.2）可满足。3.41.9 的 Dart 3.11.5 不满足
  - Linux 解压 Flutter 后用 root 运行需 `export FLUTTER_ALLOW_ROOT=1`；国内网络用 `PUB_HOSTED_URL=https://pub.flutter-io.cn` 和 `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`
  - Flutter pubspec 的 android 插件声明必须含 `package:` 字段，否则 pub get 报 "Invalid android plugin specification"
  - Dart record 位置字段用 `$1/$2/$3` 访问，命名 record 才有 `item1/item2/item3`；Karing/clashmi 私有 API 返回 `({String item1, String item2, String item3})`
  - `http.IOClient` 在 `package:http/io_client.dart`，需 import 后直接用 `IOClient()`（http 1.x 不从 `package:http/http.dart` 导出）
  - iOS 越狱 ipa 构建链路：gomobile bind -target=ios 生成 Libclash.xcframework → flutter build ios --no-codesign → ldid 签名所有 Mach-O → zip Payload

[Project Knowledge Summary]
- Date: 2026-08-09
- Context: Discovered by Agent while building rootless iOS jailbreak deb for mihomo-cns
- Category: Build Methods
- Instructions:
  - 用户偏好：不再要 iOS 越狱直装 ipa，改为 rootless deb（Sileo/dpkg 安装）
  - rootless deb 规范：Architecture 用 `iphoneos-arm64`（rootful 是 iphoneos-arm，roothide 是 iphoneos-arm64e），文件装在 `/var/jb/` 下，deb 用 ar 手工构造（成员顺序 debian-binary + control.tar.gz + data.tar.gz），postinst 调 `/var/jb/usr/bin/uicache -p` 注册 app
  - 打包入口：iOS/clashmi/scripts/package_rootless_deb.sh（输入已签名 .app，输出 rootless deb，版本自动读 Info.plist）
  - 完整构建链路：iOS/clashmi/scripts/build_rootless_deb.sh 在 mac 上执行 gomobile bind iOS/libclash（mihomo-cns 核心，含 cns 协议）→ flutter build ios --no-codesign → ldid 签名（复用 ipa workflow 的 entitlements 逻辑）→ deb 打包；CI 入口 .github/workflows/build-ios-deb.yml
