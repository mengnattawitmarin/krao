import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bridge.dart';
import 'logic/app_risk.dart';
import 'logic/checkup.dart';
import 'models.dart';

/// state กลางของแอป — ทุกอย่างอยู่ในเครื่อง ไม่มีการส่งข้อมูลออก
class AppState extends ChangeNotifier {
  final Bridge bridge;
  AppState(this.bridge);

  bool ready = false;
  bool onboarded = false;
  bool scanning = false;
  String? error;
  DateTime? lastScan;
  DeviceStatus? device;
  List<AppInfo> apps = const [];
  List<AppRisk> risks = const [];
  CheckupResult? checkup;
  Set<String> trusted = {}; // แอปที่ผู้ใช้กด "ฉันรู้จักแอปนี้"

  int tab = 0;
  void goTab(int i) {
    tab = i;
    notifyListeners();
  }

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    onboarded = p.getBool('onboarded') ?? false;
    trusted = (p.getStringList('trusted') ?? const []).toSet();
    ready = true;
    notifyListeners();
    if (onboarded) await scan();
  }

  Future<void> finishOnboarding() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('onboarded', true);
    onboarded = true;
    notifyListeners();
    try {
      await bridge.requestNotifications();
      await bridge.startGuard();
    } catch (_) {}
    await scan();
  }

  Future<void> scan() async {
    if (scanning) return;
    scanning = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([bridge.deviceStatus(), bridge.scanApps()]);
      device = results[0] as DeviceStatus;
      apps = results[1] as List<AppInfo>;
      _recompute();
      lastScan = DateTime.now();
      if (!(device?.guardScheduled ?? true)) {
        try {
          await bridge.startGuard();
        } catch (_) {}
      }
    } catch (e) {
      error = 'สแกนไม่สำเร็จ ลองใหม่อีกครั้ง ($e)';
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  void _recompute() {
    final all = assessAll(apps);
    // แอปที่ผู้ใช้ยืนยันว่ารู้จัก: ลดเหลือ "น่าสงสัย" สูงสุด (ไม่หายไป เผื่อกดผิด)
    risks = all.map((r) {
      if (!trusted.contains(r.app.package) || r.score < 25) return r;
      return AppRisk(r.app, r.score > 59 ? 59 : r.score, r.factors);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final d = device;
    checkup = d == null ? null : runCheckup(d, apps.where((a) => !trusted.contains(a.package)).toList());
  }

  Future<void> setTrusted(String pkg, bool value) async {
    if (value) {
      trusted.add(pkg);
    } else {
      trusted.remove(pkg);
    }
    final p = await SharedPreferences.getInstance();
    await p.setStringList('trusted', trusted.toList());
    _recompute();
    notifyListeners();
  }

  List<AppRisk> get bankingThreats => risks.where((r) => r.threatensBanking && !trusted.contains(r.app.package)).toList();
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
