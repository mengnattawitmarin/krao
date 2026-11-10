import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krao/app_state.dart';
import 'package:krao/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  testWidgets('ครั้งแรกเปิดหน้าแนะนำ', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(FakeBridge());
    await state.init();
    await tester.pumpWidget(KraoApp(state: state));
    await tester.pump();
    expect(find.textContaining('เกราะ ช่วยตรวจ'), findsOneWidget);
  });

  testWidgets('สแกนพบแอปดูดเงิน → หน้าหลักเตือนห้ามเปิดแอปธนาคาร', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final bad = app('com.fake.pea',
        label: 'PEA Smart Plus',
        installer: null,
        a11yOffered: true,
        a11yEnabled: true,
        perms: ['READ_SMS'],
        daysAgo: 0);
    final state = AppState(FakeBridge(apps: [app('com.ok.notes'), bad]));
    await state.init();
    await tester.pumpWidget(KraoApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text('ห้ามเปิดแอปธนาคารตอนนี้'), findsOneWidget);
    expect(state.checkup!.highRiskApps, 1);

    // ไปแท็บสแกนแอป
    await tester.tap(find.text('สแกนแอป').last);
    await tester.pumpAndSettle();
    expect(find.text('PEA Smart Plus'), findsOneWidget);
  });

  testWidgets('แท็บถูกแฮ็กแสดงปุ่มโทร 1441', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final state = AppState(FakeBridge());
    await state.init();
    await tester.pumpWidget(KraoApp(state: state));
    await tester.pumpAndSettle();
    state.goTab(2);
    await tester.pumpAndSettle();
    expect(find.text('โทร 1441 อายัดบัญชีด่วน'), findsOneWidget);
    expect(find.byType(ListView), findsWidgets);
  });
}
