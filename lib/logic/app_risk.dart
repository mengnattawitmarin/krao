// ให้คะแนนความเสี่ยงของแอปแต่ละตัวจากสัญญาณที่ระบบเปิดให้อ่าน
// เกณฑ์ออกแบบจากรูปแบบ "แอปดูดเงิน" ในไทย: ติดตั้งจากไฟล์ + ขอสิทธิ์ช่วยการเข้าถึง
// + อ่าน SMS/แสดงทับแอปอื่น + ชื่อเลียนแบบหน่วยงาน/ธนาคาร
// คะแนน: ≥ 60 = อันตราย, ≥ 25 = น่าสงสัย, ต่ำกว่านั้น = ปกติ

import '../models.dart';

enum RiskLevel { low, medium, high }

/// ร้านค้าแอปที่เชื่อถือได้ — ต้องตรงกับ TRUSTED_STORES ใน native/android/kotlin/Guard.kt
const trustedStores = <String, String>{
  'com.android.vending': 'Google Play',
  'com.google.android.feedback': 'Google Play',
  'com.sec.android.app.samsungapps': 'Galaxy Store',
  'com.huawei.appmarket': 'AppGallery',
  'com.xiaomi.market': 'Xiaomi GetApps',
  'com.xiaomi.mipicks': 'Xiaomi GetApps',
  'com.heytap.market': 'OPPO App Market',
  'com.oppo.market': 'OPPO App Market',
  'com.bbk.appstore': 'vivo App Store',
  'com.vivo.appstore': 'vivo App Store',
  'com.amazon.venezia': 'Amazon Appstore',
};

/// คำที่มิจฉาชีพชอบใช้ตั้งชื่อแอปปลอม (เทียบแบบไม่สนตัวพิมพ์)
const lookalikeKeywords = <String>[
  'กรมที่ดิน', 'ที่ดิน', 'สรรพากร', 'การไฟฟ้า', 'ไฟฟ้า', 'ประปา', 'ประกันสังคม',
  'กรมการขนส่ง', 'ขนส่ง', 'ทางรัฐ', 'เป๋าตัง', 'ธนาคาร', 'ไปรษณีย์', 'ตำรวจ', 'ศุลกากร',
  'กรุงไทย', 'กสิกร', 'ไทยพาณิชย์', 'ออมสิน', 'กรุงศรี', 'กรุงเทพ', 'ธ.ก.ส', 'บำนาญ', 'เงินดิจิทัล',
  'pea', 'mea', 'dlt', 'thaid', 'paotang', 'bank', 'k plus', 'kplus', 'scb', 'krungthai',
  'krungsri', 'gsb', 'mymo', 'ttb', 'truemoney', 'thailand post', 'kerry', 'flash express',
  'police', 'customs', 'revenue', 'government', 'gov',
];

class RiskFactor {
  final String title; // ภาษาคน
  final String detail; // อธิบายผลกระทบ
  final int points;
  final String? action; // target ของ Bridge.open
  const RiskFactor(this.title, this.detail, this.points, {this.action});
}

class AppRisk {
  final AppInfo app;
  final int score;
  final List<RiskFactor> factors;
  const AppRisk(this.app, this.score, this.factors);

  RiskLevel get level => levelFor(score);

  /// แอปที่ควบคุมหน้าจอได้อยู่ตอนนี้และเสี่ยง → ไม่ควรเปิดแอปธนาคาร
  bool get threatensBanking => level == RiskLevel.high && (app.a11yEnabled || app.overlayAllowed);
}

RiskLevel levelFor(int score) =>
    score >= 60 ? RiskLevel.high : (score >= 25 ? RiskLevel.medium : RiskLevel.low);

bool isSideloaded(AppInfo a) => a.installer == null || !trustedStores.containsKey(a.installer);

String installSourceText(AppInfo a) {
  if (a.system) return 'มากับเครื่อง';
  final store = trustedStores[a.installer];
  if (store != null) return store;
  if (a.installer == null) return 'ไม่ทราบที่มา (ติดตั้งจากไฟล์)';
  return 'ติดตั้งผ่าน ${a.installer}';
}

String? lookalikeMatch(String label) {
  final l = label.toLowerCase();
  for (final k in lookalikeKeywords) {
    if (k.length <= 3) {
      // คำสั้น เช่น "gov" "scb" ต้องเป็นคำแยก ไม่ใช่ส่วนหนึ่งของคำอื่น
      if (RegExp('(^|[^a-z])${RegExp.escape(k)}([^a-z]|\$)').hasMatch(l)) return k;
    } else if (l.contains(k)) {
      return k;
    }
  }
  return null;
}

AppRisk assessApp(AppInfo a, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final f = <RiskFactor>[];
  if (a.system) return AppRisk(a, 0, const []);

  final side = isSideloaded(a);
  final sms = a.has('READ_SMS') || a.has('RECEIVE_SMS');

  if (side) {
    f.add(const RiskFactor('ไม่ได้มาจากร้านค้าแอป',
        'แอปที่ติดตั้งจากไฟล์ไม่ผ่านการตรวจของร้านค้า แอปดูดเงินเกือบทั้งหมดมาทางนี้ (ลิงก์ใน LINE/SMS)', 15));
  }
  final look = lookalikeMatch(a.label);
  if (side && look != null) {
    f.add(RiskFactor('ชื่อคล้ายหน่วยงานหรือธนาคาร',
        'ชื่อมีคำว่า "$look" แต่ไม่ได้มาจากร้านค้า — หน่วยงานรัฐและธนาคารจริงไม่ส่งแอปให้ติดตั้งทางลิงก์', 40));
  }
  if (a.a11yEnabled) {
    f.add(RiskFactor('กำลังควบคุมหน้าจอได้ (เปิดช่วยการเข้าถึงอยู่)',
        'อ่านทุกอย่างบนจอและกดแทนคุณได้ รวมถึงโอนเงินในแอปธนาคาร', side ? 45 : 15,
        action: 'accessibility'));
  } else if (a.a11yOffered && side) {
    f.add(const RiskFactor('ขอควบคุมหน้าจอได้',
        'แอปนี้มีบริการช่วยการเข้าถึง ถ้ามีคนบอกให้เปิดสิทธิ์นี้ ห้ามเปิด', 20));
  }
  if (a.adminActive) {
    f.add(RiskFactor('เป็นผู้ดูแลอุปกรณ์', 'ล็อกเครื่อง ล้างข้อมูล หรือกันไม่ให้ถอนแอปได้', side ? 35 : 10,
        action: 'device_admin'));
  } else if (a.adminOffered && side) {
    f.add(const RiskFactor('ขอเป็นผู้ดูแลอุปกรณ์', 'อย่ากดยอมรับถ้าแอปขอสิทธิ์นี้', 10));
  }
  if (sms) {
    f.add(RiskFactor('อ่าน SMS ได้', 'เห็นรหัส OTP ที่ธนาคารส่งมา', a.defaultSms ? 0 : (side ? 20 : 5)));
  }
  if (a.overlayAllowed) {
    f.add(RiskFactor('แสดงทับแอปอื่นได้', 'สร้างหน้าจอปลอมทับแอปธนาคารเพื่อขโมยรหัส', side ? 15 : 3,
        action: 'overlay'));
  }
  if (a.notifListener) {
    f.add(RiskFactor('อ่านการแจ้งเตือนได้', 'เห็นข้อความ OTP และแชตที่เด้งขึ้นมา', side ? 15 : 5,
        action: 'notification_listeners'));
  }
  if (!a.hasLauncher && !a.a11yOffered && !a.notifListener) {
    f.add(RiskFactor('ซ่อนไอคอน', 'ไม่มีไอคอนบนหน้าจอ หาและลบเองได้ยาก', side ? 25 : 5, action: 'app'));
  }
  if (a.canInstallApps) {
    f.add(RiskFactor('ติดตั้งแอปอื่นต่อได้', 'ได้รับอนุญาตให้ติดตั้งแอปจากแหล่งอื่น อาจโหลดมัลแวร์เพิ่ม', side ? 15 : 5,
        action: 'unknown_sources'));
  }
  if (a.has('CALL_PHONE') && a.has('READ_CALL_LOG') && side) {
    f.add(const RiskFactor('โทรออกและอ่านประวัติการโทรได้', 'ใช้โอนสายหรือบล็อกการโทรหาธนาคาร', 10));
  }
  if (a.has('RECORD_AUDIO') && a.has('ACCESS_BACKGROUND_LOCATION') && side) {
    f.add(const RiskFactor('ฟังเสียงและติดตามตำแหน่งตลอดเวลา', 'รูปแบบเดียวกับแอปสอดแนม', 15));
  }
  if (a.debuggable) {
    f.add(const RiskFactor('เป็นแอปรุ่นทดสอบ (debuggable)', 'แอปที่ปล่อยจริงไม่ควรเป็นแบบนี้', 5));
  }
  if (side && t.difference(a.firstInstall).inDays < 7) {
    f.add(const RiskFactor('เพิ่งติดตั้งในสัปดาห์นี้', 'ถ้าจำไม่ได้ว่าติดตั้งเอง ให้สงสัยไว้ก่อน', 5));
  }

  final kept = f.where((x) => x.points > 0).toList()..sort((a, b) => b.points.compareTo(a.points));
  final sum = kept.fold<int>(0, (s, x) => s + x.points);
  final score = sum > 100 ? 100 : sum;
  return AppRisk(a, score, kept);
}

/// เรียง: อันตรายก่อน แล้วตามคะแนน แล้วตามชื่อ
List<AppRisk> assessAll(List<AppInfo> apps, {DateTime? now, bool includeSystem = false}) {
  final list = apps.where((a) => includeSystem || !a.system).map((a) => assessApp(a, now: now)).toList();
  list.sort((a, b) {
    final c = b.score.compareTo(a.score);
    return c != 0 ? c : a.app.label.toLowerCase().compareTo(b.app.label.toLowerCase());
  });
  return list;
}
