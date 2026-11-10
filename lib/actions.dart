import 'package:flutter/material.dart';

import 'app_state.dart';
import 'data/emergency.dart';
import 'widgets.dart';

/// รวมการกดปุ่ม "แก้ตอนนี้" ทุกที่ไว้ที่เดียว
Future<void> runAction(BuildContext context, String target, {String? package}) async {
  final s = AppScope.of(context);
  switch (target) {
    case 'scan':
      s.goTab(1);
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    case 'dial1441':
      await callNumber(context, const Hotline('ศูนย์ AOC', '1441'));
      return;
    case 'web':
      await s.bridge.open('web', number: 'https://www.thaipoliceonline.go.th');
      return;
  }
  final ok = await s.bridge.open(target, package: package);
  if (!ok && context.mounted) toast(context, 'เปิดหน้าตั้งค่านี้ไม่ได้ในเครื่องรุ่นนี้ — เปิดหน้าตั้งค่าหลักให้แทน');
}

Future<void> callNumber(BuildContext context, Hotline h) async {
  final s = AppScope.of(context);
  final yes = await confirm(context, 'โทร ${prettyNumber(h.number)}?', h.name, ok: 'โทร');
  if (yes) await s.bridge.open('dial', number: h.number);
}
