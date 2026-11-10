import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _Slide {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> points;
  const _Slide(this.icon, this.color, this.title, this.points);
}

const _slides = <_Slide>[
  _Slide(Icons.shield, K.teal, 'เกราะ ช่วยตรวจและเตือนภัยบนมือถือ', [
    'สแกนหาแอปดูดเงิน แอปแฝง และแอปสอดแนม',
    'เตือนทันทีเมื่อมีแอปแปลกได้สิทธิ์ควบคุมหน้าจอ',
    'ตรวจการตั้งค่าเครื่องที่เปิดช่องให้คนร้าย',
    'ขั้นตอนรับมือเมื่อถูกแฮ็ก/ถูกดูดเงิน พร้อมเบอร์ธนาคาร',
  ]),
  _Slide(Icons.info_outline, K.amber, 'สิ่งที่แอปทำไม่ได้', [
    'ไม่มีแอปไหนกันได้ทุกอย่าง 100% — เกราะตรวจได้เท่าที่ Android เปิดให้',
    'ไม่ลบแอปให้เองโดยไม่ถาม คุณเป็นคนกดยืนยันเสมอ',
    'มัลแวร์ที่ฝังมากับเฟิร์มแวร์เครื่อง ตรวจไม่ได้',
    'ผลสแกนเป็นการประเมิน ไม่ใช่คำรับรองว่าเครื่องปลอดภัย',
  ]),
  _Slide(Icons.lock_outline, K.green, 'ข้อมูลของคุณไม่ออกจากเครื่อง', [
    'ทุกการตรวจทำในมือถือ ไม่มีบัญชีผู้ใช้ ไม่มีโฆษณา ไม่มีตัวติดตาม',
    'เกราะต้องอ่านรายชื่อแอปในเครื่องเพื่อสแกน — ใช้เพื่อการนี้เท่านั้น',
    'ขออนุญาตแจ้งเตือน เพื่อเตือนคุณเมื่อมีแอปอันตรายเข้ามา',
  ]),
];

class _OnboardingPageState extends State<OnboardingPage> {
  final _pc = PageController();
  int _i = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) {
                final s = _slides[i];
                return ListView(padding: const EdgeInsets.fromLTRB(24, 48, 24, 24), children: [
                  Icon(s.icon, size: 72, color: s.color),
                  const SizedBox(height: 24),
                  Text(s.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.3)),
                  const SizedBox(height: 20),
                  for (final p in s.points)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Icon(Icons.check_circle, size: 18, color: s.color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(p, style: const TextStyle(fontSize: 16, height: 1.45))),
                      ]),
                    ),
                ]);
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _i ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _i ? K.teal : K.line,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: () {
                  if (last) {
                    AppScope.of(context).finishOnboarding();
                  } else {
                    _pc.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                  }
                },
                child: Text(last ? 'เริ่มสแกนเครื่อง' : 'ถัดไป', style: const TextStyle(fontSize: 17)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
