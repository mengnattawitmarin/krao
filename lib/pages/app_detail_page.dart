import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../actions.dart';
import '../app_state.dart';
import '../format.dart';
import '../logic/app_risk.dart';
import '../theme.dart';
import '../widgets.dart';

class AppDetailPage extends StatefulWidget {
  final String package;
  const AppDetailPage({super.key, required this.package});

  @override
  State<AppDetailPage> createState() => _AppDetailPageState();
}

class _AppDetailPageState extends State<AppDetailPage> {
  String? _hash;
  bool _hashing = false;

  Future<void> _computeHash() async {
    setState(() => _hashing = true);
    try {
      final h = await AppScope.of(context).bridge.hashApk(widget.package);
      if (mounted) setState(() => _hash = h ?? 'อ่านไฟล์ไม่ได้');
    } catch (e) {
      if (mounted) setState(() => _hash = 'คำนวณไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _hashing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final found = s.risks.where((r) => r.app.package == widget.package);
    if (found.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('ไม่พบแอปนี้แล้ว (อาจถูกถอนการติดตั้งไปแล้ว)')),
      );
    }
    final r = found.first;
    final a = r.app;
    final color = K.forLevel(r.level);
    final trusted = s.trusted.contains(a.package);

    return Scaffold(
      appBar: AppBar(
        title: Text(a.label),
        actions: [IconButton(tooltip: 'สแกนใหม่', onPressed: s.scan, icon: const Icon(Icons.refresh))],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Panel(
          border: r.level == RiskLevel.high ? color : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Pill(K.levelText(r.level), color),
              const SizedBox(width: 8),
              Text('คะแนนเสี่ยง ${r.score}/100', style: const TextStyle(color: K.muted)),
            ]),
            const SizedBox(height: 12),
            _kv('ที่มา', installSourceText(a)),
            _kv('ติดตั้งเมื่อ', thaiDate(a.firstInstall)),
            _kv('อัปเดตล่าสุด', thaiDate(a.lastUpdate)),
            if (a.versionName.isNotEmpty) _kv('เวอร์ชัน', a.versionName),
            _kv('ชื่อแพ็กเกจ', a.package),
          ]),
        ),
        if (r.level == RiskLevel.high) ...[
          const SizedBox(height: 12),
          Panel(
            border: K.red,
            child: const Text(
              'ถ้าคุณไม่ได้ตั้งใจติดตั้งแอปนี้ หรือมีคนโทรมาบอกให้ติดตั้ง:\n'
              '1) อย่าเปิดแอปธนาคาร  2) ถอนสิทธิ์ที่ระบุด้านล่าง  3) ถอนการติดตั้ง  4) ถ้าเงินหาย ไปแท็บ "ถูกแฮ็ก?"',
              style: TextStyle(height: 1.5),
            ),
          ),
        ],
        SectionTitle(r.factors.isEmpty ? 'ไม่พบสัญญาณเสี่ยง' : 'ทำไมถึงเสี่ยง'),
        for (final f in r.factors)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(f.points >= 20 ? Icons.error : Icons.info_outline,
                    color: f.points >= 20 ? K.red : (f.points >= 10 ? K.amber : K.muted)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(f.detail, style: const TextStyle(color: K.muted, height: 1.4)),
                  ]),
                ),
                if (f.action != null)
                  TextButton(
                    onPressed: () => runAction(context, f.action!, package: a.package),
                    child: const Text('ถอนสิทธิ์'),
                  ),
              ]),
            ),
          ),
        if (r.factors.isEmpty)
          const Disclaimer('แอปนี้มาจากร้านค้าที่เชื่อถือได้และไม่มีสิทธิ์ที่มักถูกใช้โจมตี'),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: r.level == RiskLevel.high ? K.red : null),
            onPressed: () async {
              if (a.adminActive) {
                final go = await confirm(context, 'ต้องถอนสิทธิ์ผู้ดูแลก่อน',
                    'แอปนี้เป็นผู้ดูแลอุปกรณ์ ระบบจะไม่ยอมให้ถอนการติดตั้งจนกว่าจะปิดสิทธิ์นี้ (ตั้งค่า → ความปลอดภัย → แอปผู้ดูแลอุปกรณ์)',
                    ok: 'ไปปิดสิทธิ์');
                if (go && context.mounted) await runAction(context, 'device_admin');
                return;
              }
              await runAction(context, 'uninstall', package: a.package);
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('ถอนการติดตั้ง'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => runAction(context, 'app', package: a.package),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('ข้อมูลแอปในตั้งค่า (บังคับหยุด / สิทธิ์)'),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: trusted,
          onChanged: (v) => s.setTrusted(a.package, v),
          title: const Text('ฉันรู้จักแอปนี้และตั้งใจติดตั้งเอง'),
          subtitle: const Text('ลดระดับเตือนลงเป็น "น่าสงสัย" — อย่ากดถ้ามีคนอื่นบอกให้ติดตั้ง'),
        ),
        ExpansionTile(
          title: const Text('รายละเอียดทางเทคนิค'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _mono('ใบรับรองผู้พัฒนา (SHA-256)', a.certSha256 ?? '-'),
            _mono('Target SDK', '${a.targetSdk}'),
            _mono('สิทธิ์ที่น่าสนใจ', a.permissions.isEmpty ? '-' : a.permissions.map((p) => p.split('.').last).join('\n')),
            if (_hash != null) _mono('แฮชไฟล์ APK (SHA-256)', _hash!),
            if (_hash == null)
              TextButton.icon(
                onPressed: _hashing ? null : _computeHash,
                icon: _hashing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.fingerprint),
                label: const Text('คำนวณแฮชไฟล์ APK'),
              ),
          ],
        ),
      ]),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 96, child: Text(k, style: const TextStyle(color: K.muted))),
          Expanded(child: SelectableText(v)),
        ]),
      );

  Widget _mono(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(k, style: const TextStyle(color: K.muted, fontSize: 12))),
            IconButton(
              tooltip: 'คัดลอก',
              iconSize: 18,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: v));
                toast(context, 'คัดลอกแล้ว');
              },
              icon: const Icon(Icons.copy),
            ),
          ]),
          SelectableText(v, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ]),
      );
}
