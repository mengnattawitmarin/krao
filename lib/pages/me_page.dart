import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../actions.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

const appVersion = '0.1.0';

class MePage extends StatelessWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final d = s.device;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
      const Text('ฉัน', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      if (d != null)
        Text('${d.manufacturer} ${d.model} · Android ${d.release}', style: const TextStyle(color: K.muted)),
      const SectionTitle('การเฝ้าระวังเบื้องหลัง'),
      Panel(
        child: Column(children: [
          _row(Icons.visibility, 'งานตรวจทุก ~15 นาที', d?.guardScheduled == true ? 'ทำงานอยู่' : 'ยังไม่เริ่ม',
              d?.guardScheduled == true ? K.green : K.amber),
          const Divider(height: 20),
          _row(Icons.battery_charging_full, 'ยกเว้นการประหยัดแบต',
              d?.batteryUnrestricted == true ? 'ตั้งแล้ว' : 'ยังไม่ได้ตั้ง', d?.batteryUnrestricted == true ? K.green : K.amber,
              onTap: () => runAction(context, 'battery')),
          const Divider(height: 20),
          _row(Icons.notifications_active_outlined, 'อนุญาตการแจ้งเตือน', 'แตะเพื่อขอสิทธิ์อีกครั้ง', K.muted,
              onTap: () => s.bridge.requestNotifications()),
        ]),
      ),
      const SectionTitle('รุ่นนี้ทำอะไรได้บ้าง (v0.1)'),
      const Panel(
        child: Text(
          '• สแกนแอปที่ติดตั้ง ให้คะแนนความเสี่ยงพร้อมเหตุผล\n'
          '• เฝ้าสิทธิ์อันตราย: ช่วยการเข้าถึง, ผู้ดูแลอุปกรณ์, อ่านการแจ้งเตือน\n'
          '• เตือนเมื่อมีแอปใหม่จากนอกร้านค้า\n'
          '• ตรวจการตั้งค่าเครื่อง (รหัสล็อก, แพตช์, USB debugging, root)\n'
          '• ขั้นตอนรับมือเมื่อถูกแฮ็ก + เบอร์ธนาคาร\n\n'
          'รุ่นถัดไป: บล็อกโฆษณา/ตัวติดตาม, ไฟร์วอลล์รายแอป, ตรวจลิงก์/SMS/QR หลอก, กรองสายมิจฉาชีพ',
          style: TextStyle(height: 1.5),
        ),
      ),
      const SectionTitle('ความเป็นส่วนตัว'),
      const Panel(
        child: Text(
          'เกราะประมวลผลทุกอย่างในเครื่อง ไม่มีบัญชีผู้ใช้ ไม่มีโฆษณา ไม่มี analytics และไม่ส่งรายชื่อแอปหรือข้อมูลใดออกจากมือถือ '
          'ข้อมูลที่เก็บ: ผลการตั้งค่าและรายชื่อแอปที่คุณกด "รู้จัก" (ลบได้โดยล้างข้อมูลแอป)',
          style: TextStyle(height: 1.5),
        ),
      ),
      const SectionTitle('อื่น ๆ'),
      Panel(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('ดูหน้าแนะนำอีกครั้ง'),
            onTap: () async {
              final p = await SharedPreferences.getInstance();
              await p.setBool('onboarded', false);
              s.onboarded = false;
              s.goTab(0);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('เกี่ยวกับ'),
            subtitle: const Text('เกราะ KRAO v$appVersion · ทดสอบ'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'เกราะ KRAO',
              applicationVersion: appVersion,
              applicationLegalese: 'ผู้ช่วยตรวจและเตือนภัยไซเบอร์บนมือถือ ผลตรวจเป็นการประเมิน ไม่รับประกันความปลอดภัย 100%',
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _row(IconData icon, String title, String value, Color color, {VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        child: Row(children: [
          Icon(icon, color: K.muted),
          const SizedBox(width: 12),
          Expanded(child: Text(title)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          if (onTap != null) const Icon(Icons.chevron_right, color: K.muted),
        ]),
      );
}
