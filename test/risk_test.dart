import 'package:flutter_test/flutter_test.dart';
import 'package:krao/logic/app_risk.dart';
import 'package:krao/logic/checkup.dart';
import 'package:krao/models.dart';

import 'fakes.dart';

void main() {
  group('assessApp', () {
    test('แอปปกติจาก Play Store = ปกติ ไม่มีเหตุผล', () {
      final r = assessApp(app('com.example.notes', perms: ['CAMERA']), now: now);
      expect(r.level, RiskLevel.low);
      expect(r.factors, isEmpty);
    });

    test('แอปมากับเครื่องไม่ถูกให้คะแนน', () {
      final r = assessApp(app('com.android.phone', system: true, installer: null, a11yEnabled: true), now: now);
      expect(r.score, 0);
    });

    test('รูปแบบแอปดูดเงิน: ไฟล์ APK + ชื่อกรมที่ดิน + เปิด accessibility + SMS = อันตราย', () {
      final r = assessApp(
        app('com.fake.land',
            label: 'กรมที่ดิน Smart',
            installer: 'com.google.android.packageinstaller',
            a11yOffered: true,
            a11yEnabled: true,
            perms: ['READ_SMS', 'SYSTEM_ALERT_WINDOW'],
            overlayAllowed: true,
            daysAgo: 1),
        now: now,
      );
      expect(r.level, RiskLevel.high);
      expect(r.score, 100);
      expect(r.threatensBanking, isTrue);
      expect(r.factors.first.points, greaterThanOrEqualTo(r.factors.last.points)); // เรียงจากหนักไปเบา
      expect(r.factors.map((f) => f.title), contains('ชื่อคล้ายหน่วยงานหรือธนาคาร'));
    });

    test('ติดตั้งจากไฟล์อย่างเดียว ไม่มีสิทธิ์อันตราย = ปกติ (แต่มีเหตุผล)', () {
      final r = assessApp(app('com.indie.game', installer: null), now: now);
      expect(r.level, RiskLevel.low);
      expect(r.factors, isNotEmpty);
    });

    test('แอปช่วยการเข้าถึงจาก Play Store ที่เปิดใช้อยู่ = ไม่เกินน่าสงสัย', () {
      final r = assessApp(app('com.pw.manager', a11yOffered: true, a11yEnabled: true, overlayAllowed: true), now: now);
      expect(r.level, isNot(RiskLevel.high));
    });

    test('แอปซ่อนไอคอนจากไฟล์ + ผู้ดูแลอุปกรณ์ = อันตราย', () {
      final r = assessApp(app('x.y.z', installer: null, hasLauncher: false, adminActive: true), now: now);
      expect(r.level, RiskLevel.high);
    });

    test('ร้านค้าของผู้ผลิตมือถือถือว่าเชื่อถือได้', () {
      expect(isSideloaded(app('a', installer: 'com.sec.android.app.samsungapps')), isFalse);
      expect(isSideloaded(app('a', installer: 'com.heytap.market')), isFalse);
      expect(isSideloaded(app('a', installer: null)), isTrue);
      expect(isSideloaded(app('a', installer: 'org.telegram.messenger')), isTrue);
    });
  });

  group('lookalikeMatch', () {
    test('จับชื่อภาษาไทยและอังกฤษ', () {
      expect(lookalikeMatch('การไฟฟ้าส่วนภูมิภาค'), isNotNull);
      expect(lookalikeMatch('K PLUS Update'), isNotNull);
      expect(lookalikeMatch('Thai GOV Service'), 'gov');
    });

    test('คำสั้นต้องเป็นคำแยก ไม่จับคำที่บังเอิญมีตัวอักษรตรง', () {
      expect(lookalikeMatch('Peacock TV'), isNull);
      expect(lookalikeMatch('Governor Game'), isNull);
      expect(lookalikeMatch('Calculator'), isNull);
    });
  });

  group('assessAll', () {
    test('ตัดแอประบบและเรียงตามคะแนน', () {
      final list = assessAll([
        app('a.safe'),
        app('b.sys', system: true),
        app('c.bad', installer: null, a11yEnabled: true, a11yOffered: true, adminActive: true),
      ], now: now);
      expect(list.length, 2);
      expect(list.first.app.package, 'c.bad');
    });
  });

  group('runCheckup', () {
    test('เครื่องดี ไม่มีแอปเสี่ยง = 100', () {
      final c = runCheckup(device(), [app('a.safe')], now: now);
      expect(c.score, 100);
      expect(c.problems, isEmpty);
      expect(c.verdict, 'ปลอดภัยดี');
    });

    test('ไม่มีรหัสล็อก + เปิด USB debugging ลดคะแนนและขึ้นในรายการต้องแก้', () {
      final c = runCheckup(device(secureLock: false, adb: true), const [], now: now);
      expect(c.score, lessThan(80));
      expect(c.problems.map((p) => p.id), containsAll(['lock', 'adb']));
      expect(c.problems.first.status, CheckStatus.bad);
    });

    test('มีแอปอันตราย = คะแนนไม่เกิน 49 แม้ตั้งค่าเครื่องดี', () {
      final bad = app('c.bad', label: 'สรรพากร', installer: null, a11yEnabled: true, a11yOffered: true);
      final c = runCheckup(device(), [bad], now: now);
      expect(c.highRiskApps, 1);
      expect(c.score, lessThanOrEqualTo(49));
      expect(c.verdict, contains('อันตราย'));
    });

    test('แพตช์เก่ากว่า 400 วัน = ไม่ผ่าน, ไม่ทราบการเข้ารหัส = ตัดออกจากตัวหาร', () {
      final c = runCheckup(device(patch: '2024-01-01', encryption: null), const [], now: now);
      final patch = c.items.firstWhere((i) => i.id == 'patch');
      expect(patch.status, CheckStatus.bad);
      expect(c.items.firstWhere((i) => i.id == 'enc').status, CheckStatus.unknown);
    });

    test('แอปที่อนุญาตติดตั้งจากแหล่งอื่นถูกนับ', () {
      final c = runCheckup(device(), [app('org.browser', canInstallApps: true)], now: now);
      expect(c.items.firstWhere((i) => i.id == 'unknown').status, CheckStatus.warn);
    });
  });

  group('models', () {
    test('AppInfo.fromMap ทนข้อมูลขาด', () {
      final a = AppInfo.fromMap({'package': 'x', 'firstInstall': 1700000000000, 'permissions': ['a', 1]});
      expect(a.label, 'x');
      expect(a.permissions, ['a']);
      expect(a.hasLauncher, isTrue);
    });

    test('DeviceStatus แปลงวันที่แพตช์', () {
      final d = DeviceStatus.fromMap({'sdk': 34, 'securityPatch': '2026-09-05', 'secureLock': true});
      expect(d.patchDate, DateTime(2026, 9, 5));
      expect(d.encryption, isNull);
    });
  });
}
