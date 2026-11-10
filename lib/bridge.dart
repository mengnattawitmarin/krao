// ตัวกลางเรียกโค้ด Android (MethodChannel "krao/native")
// หน้าจอและ state ใช้ Bridge เสมอ เพื่อให้เทสต์ใส่ FakeBridge แทนได้

import 'package:flutter/services.dart';

import 'models.dart';

abstract class Bridge {
  Future<DeviceStatus> deviceStatus();
  Future<List<AppInfo>> scanApps();
  Future<String?> hashApk(String package);

  /// เปิดหน้าตั้งค่า/แอปอื่น — target ดู MainActivity.openTarget
  Future<bool> open(String target, {String? package, String? number});
  Future<void> startGuard();
  Future<void> requestNotifications();
}

class ChannelBridge implements Bridge {
  static const _ch = MethodChannel('krao/native');

  @override
  Future<DeviceStatus> deviceStatus() async {
    final m = await _ch.invokeMethod<Map<Object?, Object?>>('deviceStatus');
    return DeviceStatus.fromMap(m ?? const {});
  }

  @override
  Future<List<AppInfo>> scanApps() async {
    final list = await _ch.invokeMethod<List<Object?>>('scanApps');
    return (list ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(AppInfo.fromMap)
        .toList();
  }

  @override
  Future<String?> hashApk(String package) => _ch.invokeMethod<String>('hashApk', {'package': package});

  @override
  Future<bool> open(String target, {String? package, String? number}) async {
    try {
      final ok = await _ch.invokeMethod<bool>('open', {'target': target, 'package': package, 'number': number});
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> startGuard() => _ch.invokeMethod('startGuard');

  @override
  Future<void> requestNotifications() => _ch.invokeMethod('requestNotifications');
}
