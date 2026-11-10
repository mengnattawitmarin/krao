import 'package:flutter/material.dart';

import '../actions.dart';
import '../app_state.dart';
import '../format.dart';
import '../logic/checkup.dart';
import '../theme.dart';
import '../widgets.dart';
import 'app_detail_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = s.checkup;
    final d = s.device;
    final threats = s.bankingThreats;
    return RefreshIndicator(
      onRefresh: s.scan,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        Row(children: [
          const Icon(Icons.shield, color: K.teal, size: 28),
          const SizedBox(width: 8),
          const Text('เกราะ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (d != null) Text('${d.manufacturer} ${d.model}', style: const TextStyle(color: K.muted, fontSize: 12)),
        ]),
        const SizedBox(height: 16),
        if (threats.isNotEmpty) ...[
          Panel(
            border: K.red,
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => AppDetailPage(package: threats.first.app.package))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, color: K.red, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('ห้ามเปิดแอปธนาคารตอนนี้',
                      style: TextStyle(color: K.red, fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    '${threats.map((t) => t.app.label).join(', ')} ควบคุมหน้าจอได้อยู่และมีลักษณะแบบแอปดูดเงิน '
                    'แตะเพื่อถอนสิทธิ์และลบ ถ้าเงินหายแล้ว ไปที่แท็บ "ถูกแฮ็ก?"',
                    style: const TextStyle(height: 1.4),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        Panel(
          child: Column(children: [
            Row(children: [
              ScoreRing(score: c?.score ?? 0, busy: s.scanning || c == null),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    s.scanning ? 'กำลังสแกน…' : (c?.verdict ?? 'ยังไม่ได้สแกน'),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c == null ? K.text : K.forScore(c.score)),
                  ),
                  const SizedBox(height: 6),
                  if (c != null)
                    Text('แอปอันตราย ${c.highRiskApps} · น่าสงสัย ${c.mediumRiskApps}',
                        style: const TextStyle(color: K.muted)),
                  if (s.lastScan != null)
                    Text('สแกนล่าสุด ${ago(s.lastScan!)}', style: const TextStyle(color: K.muted, fontSize: 12)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: s.scanning ? null : s.scan,
                icon: const Icon(Icons.radar),
                label: const Text('สแกนใหม่'),
              ),
            ),
          ]),
        ),
        if (s.error != null) ...[
          const SizedBox(height: 12),
          Panel(border: K.amber, child: Text(s.error!, style: const TextStyle(color: K.amber))),
        ],
        if (c != null && c.problems.isNotEmpty) ...[
          SectionTitle('ต้องแก้ (${c.problems.length})'),
          for (final p in c.problems) _CheckTile(p),
        ],
        if (c != null) ...[
          SectionTitle('ผ่านแล้ว'),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(children: [
              for (final p in c.items.where((i) => i.status == CheckStatus.ok))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    const Icon(Icons.check_circle, color: K.green, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p.title)),
                  ]),
                ),
            ]),
          ),
        ],
        SectionTitle('การเฝ้าระวังอัตโนมัติ'),
        Panel(
          child: Row(children: [
            Icon(d?.guardScheduled == true ? Icons.visibility : Icons.visibility_off,
                color: d?.guardScheduled == true ? K.green : K.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                d?.guardScheduled == true
                    ? 'ทำงานอยู่ — ตรวจทุก ~15 นาที เตือนเมื่อมีแอปใหม่จากนอกร้านค้า หรือแอปได้สิทธิ์ควบคุมหน้าจอ'
                    : 'ยังไม่ทำงาน — กดสแกนใหม่เพื่อเริ่ม',
                style: const TextStyle(height: 1.4),
              ),
            ),
          ]),
        ),
        if (d != null && !d.batteryUnrestricted) ...[
          const SizedBox(height: 8),
          Panel(
            onTap: () => runAction(context, 'battery'),
            child: const Row(children: [
              Icon(Icons.battery_alert, color: K.amber),
              SizedBox(width: 12),
              Expanded(
                child: Text('มือถือบางยี่ห้อหยุดงานเบื้องหลังเพื่อประหยัดแบต แตะเพื่อตั้ง "ไม่จำกัด" ให้เกราะ',
                    style: TextStyle(height: 1.4)),
              ),
              Icon(Icons.chevron_right, color: K.muted),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: K.red, side: const BorderSide(color: K.red)),
            onPressed: () => s.goTab(2),
            icon: const Icon(Icons.sos),
            label: const Text('ถูกแฮ็ก / ถูกดูดเงิน ทำอย่างไร', style: TextStyle(fontSize: 16)),
          ),
        ),
        const Disclaimer('ผลตรวจเป็นการประเมินจากสัญญาณที่ระบบ Android เปิดให้อ่าน ไม่รับประกันว่าเครื่องปลอดภัย 100% '
            'ข้อมูลทั้งหมดประมวลผลในเครื่อง ไม่ถูกส่งออก'),
      ]),
    );
  }
}

class _CheckTile extends StatelessWidget {
  final CheckItem item;
  const _CheckTile(this.item);

  @override
  Widget build(BuildContext context) {
    final color = K.forStatus(item.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        border: item.status == CheckStatus.bad ? color.withValues(alpha: 0.6) : null,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(item.status == CheckStatus.bad ? Icons.error : Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (item.detail.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(item.detail, style: const TextStyle(color: K.muted, height: 1.4)),
              ],
            ]),
          ),
          if (item.id == 'apps')
            TextButton(onPressed: () => AppScope.of(context).goTab(1), child: const Text('ดูแอป'))
          else if (item.action != null)
            TextButton(onPressed: () => runAction(context, item.action!), child: Text(item.actionLabel ?? 'แก้')),
        ]),
      ),
    );
  }
}
