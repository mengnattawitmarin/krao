import 'package:flutter/material.dart';

import '../actions.dart';
import '../app_state.dart';
import '../data/emergency.dart';
import '../theme.dart';
import '../widgets.dart';

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  final _done = <int>{};

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final risky = s.risks.where((r) => r.score >= 60 && !s.trusted.contains(r.app.package)).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
      const Text('ถูกแฮ็ก / ถูกดูดเงิน', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: K.red)),
      const SizedBox(height: 4),
      const Text('ทำตามลำดับ ยิ่งเร็วยิ่งมีโอกาสได้เงินคืน', style: TextStyle(color: K.muted)),
      const SizedBox(height: 12),
      Semantics(
        button: true,
        label: 'โทรแจ้ง 1441 ศูนย์อายัดบัญชี',
        child: SizedBox(
          height: 64,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: K.red),
            onPressed: () => callNumber(context, helpHotlines.first),
            icon: const Icon(Icons.call, size: 28),
            label: const Text('โทร 1441 อายัดบัญชีด่วน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
      if (risky.isNotEmpty) ...[
        const SizedBox(height: 12),
        Panel(
          border: K.red,
          child: Text('แอปที่น่าจะเป็นต้นเหตุ: ${risky.map((r) => r.app.label).join(', ')}',
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
        ),
      ],
      const SectionTitle('ขั้นตอนรับมือ'),
      for (var i = 0; i < emergencySteps.length; i++) _step(context, i, emergencySteps[i]),
      const SectionTitle('สัญญาณว่าอาจโดนแล้ว'),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final w in warningSigns)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('•  ', style: TextStyle(color: K.amber)),
                Expanded(child: Text(w, style: const TextStyle(height: 1.4))),
              ]),
            ),
        ]),
      ),
      const SectionTitle('สายด่วน'),
      for (final h in helpHotlines) _hotline(context, h),
      SectionTitle('ธนาคาร (แจ้งอายัดบัญชี/บัตร)', trailing: const Text(hotlinesVerified, style: TextStyle(color: K.muted, fontSize: 12))),
      for (final h in bankHotlines) _hotline(context, h),
      const Disclaimer('เบอร์รวบรวมจากข้อมูลเผยแพร่ของธนาคาร ถ้าโทรไม่ติดให้ดูเบอร์หลังบัตร ATM หรือเว็บธนาคาร '
          'ธนาคารและเจ้าหน้าที่รัฐจะไม่ให้คุณติดตั้งแอปหรือโอนเงินเพื่อ "ตรวจสอบบัญชี"'),
    ]);
  }

  Widget _step(BuildContext context, int i, EmergencyStep st) {
    final done = _done.contains(i);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => done ? _done.remove(i) : _done.add(i)),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: done ? K.green : K.panel2,
              child: done
                  ? const Icon(Icons.check, size: 18, color: K.bg)
                  : Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800, color: K.text)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(st.title,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? K.muted : K.text)),
              const SizedBox(height: 4),
              Text(st.detail, style: const TextStyle(color: K.muted, height: 1.4)),
              if (st.action != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: OutlinedButton(
                    onPressed: () => runAction(context, st.action!),
                    child: Text(st.actionLabel ?? 'ทำเลย'),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _hotline(BuildContext context, Hotline h) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Panel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: () => callNumber(context, h),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(h.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (h.note.isNotEmpty) Text(h.note, style: const TextStyle(color: K.muted, fontSize: 12)),
              ]),
            ),
            Text(prettyNumber(h.number), style: const TextStyle(fontWeight: FontWeight.w800, color: K.teal, fontSize: 16)),
            const SizedBox(width: 8),
            Semantics(label: 'โทร ${h.name}', child: const Icon(Icons.call, color: K.teal)),
          ]),
        ),
      );
}
