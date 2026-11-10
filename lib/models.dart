/// ข้อมูลที่ได้จากฝั่ง Android (lib/bridge.dart → native/android/kotlin)
library;

class AppInfo {
  final String package;
  final String label;
  final String versionName;
  final String? installer;
  final DateTime firstInstall;
  final DateTime lastUpdate;
  final bool system;
  final bool updatedSystem;
  final bool hasLauncher;
  final List<String> permissions;
  final bool a11yOffered;
  final bool a11yEnabled;
  final bool adminOffered;
  final bool adminActive;
  final bool notifListener;
  final bool overlayAllowed;
  final bool canInstallApps;
  final bool defaultSms;
  final String? certSha256;
  final int targetSdk;
  final bool debuggable;

  const AppInfo({
    required this.package,
    required this.label,
    this.versionName = '',
    this.installer,
    required this.firstInstall,
    required this.lastUpdate,
    this.system = false,
    this.updatedSystem = false,
    this.hasLauncher = true,
    this.permissions = const [],
    this.a11yOffered = false,
    this.a11yEnabled = false,
    this.adminOffered = false,
    this.adminActive = false,
    this.notifListener = false,
    this.overlayAllowed = false,
    this.canInstallApps = false,
    this.defaultSms = false,
    this.certSha256,
    this.targetSdk = 0,
    this.debuggable = false,
  });

  bool has(String permission) => permissions.contains('android.permission.$permission');

  static DateTime _time(Object? v) =>
      DateTime.fromMillisecondsSinceEpoch(v is int ? v : (v is num ? v.toInt() : 0));

  factory AppInfo.fromMap(Map<Object?, Object?> m) => AppInfo(
        package: (m['package'] ?? '') as String,
        label: (m['label'] ?? m['package'] ?? '') as String,
        versionName: (m['versionName'] ?? '') as String,
        installer: m['installer'] as String?,
        firstInstall: _time(m['firstInstall']),
        lastUpdate: _time(m['lastUpdate']),
        system: m['system'] == true,
        updatedSystem: m['updatedSystem'] == true,
        hasLauncher: m['hasLauncher'] != false,
        permissions: ((m['permissions'] as List?) ?? const []).whereType<String>().toList(),
        a11yOffered: m['a11yOffered'] == true,
        a11yEnabled: m['a11yEnabled'] == true,
        adminOffered: m['adminOffered'] == true,
        adminActive: m['adminActive'] == true,
        notifListener: m['notifListener'] == true,
        overlayAllowed: m['overlayAllowed'] == true,
        canInstallApps: m['canInstallApps'] == true,
        defaultSms: m['defaultSms'] == true,
        certSha256: m['certSha256'] as String?,
        targetSdk: (m['targetSdk'] as num?)?.toInt() ?? 0,
        debuggable: m['debuggable'] == true,
      );
}

class DeviceStatus {
  final String manufacturer;
  final String model;
  final String release;
  final int sdk;
  final String securityPatch; // "YYYY-MM-DD"
  final bool secureLock;
  final bool adb;
  final bool devOptions;
  final bool rooted;
  final bool? encryption;
  final bool guardScheduled;
  final bool batteryUnrestricted;

  const DeviceStatus({
    this.manufacturer = '',
    this.model = '',
    this.release = '',
    required this.sdk,
    required this.securityPatch,
    required this.secureLock,
    this.adb = false,
    this.devOptions = false,
    this.rooted = false,
    this.encryption,
    this.guardScheduled = false,
    this.batteryUnrestricted = false,
  });

  DateTime? get patchDate => DateTime.tryParse(securityPatch);

  factory DeviceStatus.fromMap(Map<Object?, Object?> m) => DeviceStatus(
        manufacturer: (m['manufacturer'] ?? '') as String,
        model: (m['model'] ?? '') as String,
        release: (m['release'] ?? '') as String,
        sdk: (m['sdk'] as num?)?.toInt() ?? 0,
        securityPatch: (m['securityPatch'] ?? '') as String,
        secureLock: m['secureLock'] == true,
        adb: m['adb'] == true,
        devOptions: m['devOptions'] == true,
        rooted: m['rooted'] == true,
        encryption: m['encryption'] as bool?,
        guardScheduled: m['guardScheduled'] == true,
        batteryUnrestricted: m['batteryUnrestricted'] == true,
      );
}
