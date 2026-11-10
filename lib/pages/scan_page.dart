import 'package:flutter/material.dart';

import '../app_state.dart';
import '../logic/app_risk.dart';
import '../theme.dart';
import '../widgets.dart';
import 'app_detail_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  RiskLevel? _filter;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final all = s.risks;
    int count(RiskLevel l) => all.where((r) => r.level == l).length;
    final q = _q.trim().toLowerCase();
    final list = all.where((r) {
      if (_filter != null && r.level != _filter) return false;
      if (q.isEmpty) return true;
      return r.app.label.toLowerCase().contains(q) || r.app.package.toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: s.scan,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        const Text('สแกนแอป', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          s.scanning ? 'กำลังสแกน…' : 'แอปที่คุณติดตั้ง ${all.length} แอป (ไม่รวมแอปที่มากับเครื่อง)',
          style: const TextStyle(color: K.muted),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            hintText: 'ค้นหาชื่อแอป',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: K.panel,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
          onChanged: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(label: Text('ทั้งหมด ${all.length}'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
          for (final l in RiskLevel.values.reversed)
            ChoiceChip(
              label: Text('${K.levelText(l)} ${count(l)}'),
              selected: _filter == l,
              selectedColor: K.forLevel(l).withValues(alpha: 0.25),
              onSelected: (_) => setState(() => _filter = l),
            ),
        ]),
        const SizedBox(height: 12),
        if (list.isEmpty && !s.scanning)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('ไม่มีแอปในหมวดนี้', style: TextStyle(color: K.muted))),
          ),
        for (final r in list) _AppTile(r, trusted: s.trusted.contains(r.app.package)),
        const Disclaimer('"อันตราย" หมายถึงแอปมีความสามารถแบบเดียวกับแอปดูดเงิน/สอดแนม ไม่ได้แปลว่าเป็นมัลแวร์แน่นอน '
            'แอปจริงบางตัว (เช่น ตัวช่วยการเข้าถึงสำหรับผู้พิการ) ก็ใช้สิทธิ์เหล่านี้ — ถ้ารู้จักแอป กด "ฉันรู้จักแอปนี้" ในหน้ารายละเอียด'),
      ]),
    );
  }
}

class _AppTile extends StatelessWidget {
  final AppRisk r;
  final bool trusted;
  const _AppTile(this.r, {required this.trusted});

  @override
  Widget build(BuildContext context) {
    final color = K.forLevel(r.level);
    final top = r.factors.isEmpty ? installSourceText(r.app) : r.factors.first.title;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: const EdgeInsets.all(14),
        border: r.level == RiskLevel.high ? color.withValues(alpha: 0.7) : null,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppDetailPage(package: r.app.package))),
        child: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              r.app.label.isEmpty ? '?' : r.app.label.characters.first.toUpperCase(),
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.app.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(top, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: K.muted, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Pill(K.levelText(r.level), color),
            if (trusted) const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('รู้จักแล้ว', style: TextStyle(color: K.muted, fontSize: 12)),
            ),
          ]),
        ]),
      ),
    );
  }
}
