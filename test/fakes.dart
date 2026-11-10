import 'package:krao/bridge.dart';
import 'package:krao/models.dart';

final now = DateTime(2026, 11, 10, 12);

AppInfo app(
  String pkg, {
  String? label,
  String? installer = 'com.android.vending',
  bool system = false,
  bool hasLauncher = true,
  List<String> perms = const [],
  bool a11yOffered = false,
  bool a11yEnabled = false,
  bool adminOffered = false,
  bool adminActive = false,
  bool notifListener = false,
  bool overlayAllowed = false,
  bool canInstallApps = false,
  int daysAgo = 100,
}) =>
    AppInfo(
      package: pkg,
      label: label ?? pkg,
      installer: installer,
      firstInstall: now.subtract(Duration(days: daysAgo)),
      lastUpdate: now.subtract(Duration(days: daysAgo)),
      system: system,
      hasLauncher: hasLauncher,
      permissions: perms.map((p) => 'android.permission.$p').toList(),
      a11yOffered: a11yOffered,
      a11yEnabled: a11yEnabled,
      adminOffered: adminOffered,
      adminActive: adminActive,
      notifListener: notifListener,
      overlayAllowed: overlayAllowed,
      canInstallApps: canInstallApps,
    );

DeviceStatus device({
  bool secureLock = true,
  String patch = '2026-10-01',
  int sdk = 34,
  bool adb = false,
  bool devOptions = false,
  bool rooted = false,
  bool? encryption = true,
}) =>
    DeviceStatus(
      manufacturer: 'Test',
      model: 'Phone',
      release: '14',
      sdk: sdk,
      securityPatch: patch,
      secureLock: secureLock,
      adb: adb,
      devOptions: devOptions,
      rooted: rooted,
      encryption: encryption,
      guardScheduled: true,
      batteryUnrestricted: true,
    );

class FakeBridge implements Bridge {
  DeviceStatus status;
  List<AppInfo> apps;
  final opened = <String>[];
  FakeBridge({DeviceStatus? status, this.apps = const []}) : status = status ?? device();

  @override
  Future<DeviceStatus> deviceStatus() async => status;
  @override
  Future<List<AppInfo>> scanApps() async => apps;
  @override
  Future<String?> hashApk(String package) async => 'abc';
  @override
  Future<bool> open(String target, {String? package, String? number}) async {
    opened.add(target);
    return true;
  }

  @override
  Future<void> startGuard() async {}
  @override
  Future<void> requestNotifications() async {}
}
