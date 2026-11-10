// ตรวจสุขภาพความปลอดภัยของเครื่อง → คะแนน 0–100
// แต่ละข้อมีน้ำหนัก ผ่าน = ได้เต็ม, เฝ้าระวัง = ได้ครึ่ง, ไม่ผ่าน = 0, ไม่ทราบ = ตัดออกจากตัวหาร

import '../models.dart';
import 'app_risk.dart';

enum CheckStatus { ok, warn, bad, unknown }

class CheckItem {
  final String id;
  final String title;
  final String detail;
  final CheckStatus status;
  final int weight;
  final String? action; // target ของ Bridge.open
  final String? actionLabel;
  const CheckItem(this.id, this.title, this.detail, this.status, this.weight, {this.action, this.actionLabel});

  double get earned => switch (status) {
        CheckStatus.ok => weight.toDouble(),
        CheckStatus.warn => weight / 2,
        _ => 0.0,
      };
}

class CheckupResult {
  final int score;
  final List<CheckItem> items;
  final int highRiskApps;
  final int mediumRiskApps;
  const CheckupResult(this.score, this.items, this.highRiskApps, this.mediumRiskApps);

  List<CheckItem> get problems =>
      items.where((i) => i.status == CheckStatus.bad || i.status == CheckStatus.warn).toList()
        ..sort((a, b) {
          final s = a.status.index.compareTo(b.status.index); // bad (2) หลัง warn (1) → กลับด้าน
          return s != 0 ? -s : b.weight.compareTo(a.weight);
        });

  String get verdict {
    if (highRiskApps > 0) return 'พบแอปอันตราย ต้องจัดการทันที';
    if (score >= 85) return 'ปลอดภัยดี';
    if (score >= 65) return 'พอใช้ มีจุดที่ควรแก้';
    return 'เสี่ยง ควรแก้ตามรายการด้านล่าง';
  }
}

CheckupResult runCheckup(DeviceStatus d, List<AppInfo> apps, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final risks = assessAll(apps, now: t);
  final high = risks.where((r) => r.level == RiskLevel.high).length;
  final medium = risks.where((r) => r.level == RiskLevel.medium).length;
  final items = <CheckItem>[];

  items.add(high > 0
      ? CheckItem('apps', 'พบแอปอันตราย $high แอป', 'มีความสามารถแบบแอปดูดเงิน/สอดแนม ดูในแท็บสแกนแอป', CheckStatus.bad, 30)
      : medium > 0
          ? CheckItem('apps', 'มีแอปน่าสงสัย $medium แอป', 'ลองตรวจว่าคุณรู้จักทุกแอปหรือไม่', CheckStatus.warn, 30)
          : const CheckItem('apps', 'ไม่พบแอปอันตราย', 'จากสัญญาณที่ตรวจได้ในเครื่อง', CheckStatus.ok, 30));

  items.add(d.secureLock
      ? const CheckItem('lock', 'ตั้งรหัสล็อกหน้าจอแล้ว', 'คนอื่นหยิบเครื่องไปเปิดไม่ได้', CheckStatus.ok, 15)
      : const CheckItem('lock', 'ยังไม่ได้ตั้งรหัสล็อกหน้าจอ', 'ใครหยิบเครื่องก็เปิดแอปธนาคารและอ่าน OTP ได้',
          CheckStatus.bad, 15, action: 'lock', actionLabel: 'ตั้งรหัส'));

  final patch = d.patchDate;
  if (patch == null) {
    items.add(const CheckItem('patch', 'ไม่ทราบวันที่แพตช์ความปลอดภัย', '', CheckStatus.unknown, 10));
  } else {
    final days = t.difference(patch).inDays;
    final p = '${patch.day}/${patch.month}/${patch.year + 543}';
    items.add(days <= 120
        ? CheckItem('patch', 'แพตช์ความปลอดภัยล่าสุด $p', 'อัปเดตไม่เกิน 4 เดือน', CheckStatus.ok, 10)
        : days <= 400
            ? CheckItem('patch', 'แพตช์ความปลอดภัยเก่า ($p)', 'ลองเช็กอัปเดตระบบ', CheckStatus.warn, 10,
                action: 'update', actionLabel: 'เช็กอัปเดต')
            : CheckItem('patch', 'แพตช์ความปลอดภัยเก่ามาก ($p)',
                'ช่องโหว่ที่รู้จักแล้วยังไม่ถูกปิด ถ้าเครื่องไม่มีอัปเดตแล้ว ควรพิจารณาเปลี่ยนเครื่องสำหรับแอปธนาคาร',
                CheckStatus.bad, 10, action: 'update', actionLabel: 'เช็กอัปเดต'));
  }

  items.add(d.sdk >= 31
      ? CheckItem('os', 'Android ${d.release}', 'ยังได้การปกป้องรุ่นใหม่', CheckStatus.ok, 5)
      : d.sdk >= 28
          ? CheckItem('os', 'Android ${d.release} ค่อนข้างเก่า', 'บางการป้องกันใหม่ใช้ไม่ได้', CheckStatus.warn, 5)
          : CheckItem('os', 'Android ${d.release} เก่ามาก', 'ไม่ได้รับอัปเดตความปลอดภัยแล้ว', CheckStatus.bad, 5));

  items.add(d.adb
      ? const CheckItem('adb', 'เปิดการแก้ไขข้อบกพร่อง USB อยู่', 'เสียบสายกับคอมที่ไม่รู้จักอาจถูกติดตั้งแอปหรือดึงข้อมูล',
          CheckStatus.bad, 10, action: 'developer', actionLabel: 'ปิด')
      : const CheckItem('adb', 'ปิดการแก้ไขข้อบกพร่อง USB', '', CheckStatus.ok, 10));

  items.add(d.devOptions
      ? const CheckItem('dev', 'เปิดตัวเลือกสำหรับนักพัฒนาอยู่', 'ถ้าไม่ได้ใช้ ควรปิด', CheckStatus.warn, 5,
          action: 'developer', actionLabel: 'ปิด')
      : const CheckItem('dev', 'ปิดตัวเลือกสำหรับนักพัฒนา', '', CheckStatus.ok, 5));

  items.add(d.rooted
      ? const CheckItem('root', 'พบร่องรอยการ root เครื่อง', 'แอปใดก็ได้สิทธิ์สูงสุดได้ แอปธนาคารหลายแห่งจะไม่ยอมทำงาน',
          CheckStatus.bad, 10)
      : const CheckItem('root', 'ไม่พบการ root', '', CheckStatus.ok, 10));

  final installers = apps.where((a) => !a.system && a.canInstallApps).toList();
  items.add(installers.isEmpty
      ? const CheckItem('unknown', 'ไม่มีแอปที่ติดตั้งแอปอื่นได้', 'ปิดการติดตั้งจากแหล่งที่ไม่รู้จักอยู่', CheckStatus.ok, 10)
      : CheckItem(
          'unknown',
          'อนุญาตติดตั้งจากแหล่งอื่น ${installers.length} แอป',
          'เช่น ${installers.take(3).map((a) => a.label).join(', ')} — ลิงก์หลอกใช้ช่องนี้ติดตั้งแอปดูดเงิน ปิดไว้ถ้าไม่จำเป็น',
          CheckStatus.warn,
          10,
          action: 'unknown_sources',
          actionLabel: 'ตั้งค่า'));

  items.add(switch (d.encryption) {
    true => const CheckItem('enc', 'ข้อมูลในเครื่องเข้ารหัสแล้ว', '', CheckStatus.ok, 5),
    false => const CheckItem('enc', 'ข้อมูลในเครื่องไม่ได้เข้ารหัส', 'ถ้าเครื่องหาย ข้อมูลอาจถูกอ่านได้', CheckStatus.bad, 5,
        action: 'security', actionLabel: 'ตั้งค่า'),
    null => const CheckItem('enc', 'ไม่ทราบสถานะการเข้ารหัส', '', CheckStatus.unknown, 5),
  });

  final known = items.where((i) => i.status != CheckStatus.unknown);
  final total = known.fold<int>(0, (s, i) => s + i.weight);
  final earned = known.fold<double>(0, (s, i) => s + i.earned);
  var score = total == 0 ? 0 : (earned / total * 100).round();
  if (high > 0 && score > 49) score = 49; // มีแอปอันตราย = ไม่ควรขึ้นสีเขียวเด็ดขาด
  return CheckupResult(score, items, high, medium);
}
