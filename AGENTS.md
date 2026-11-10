# AGENTS.md — คู่มือส่งต่องานเกราะ KRAO (สำหรับ AI / นักพัฒนา)

> AI ทุกตัวอ่านไฟล์นี้ก่อนเริ่มงาน และ **อัปเดต "สถานะล่าสุด" + "บันทึกการส่งต่อ" ทุกครั้งที่ทำงานเสร็จ**

## โปรเจกต์คืออะไร
**เกราะ (KRAO)** — แอป Android ภาษาไทย ช่วยตรวจและเตือนภัยไซเบอร์บนมือถือ เน้น "แอปดูดเงิน" ที่คนไทยเจอจริง
- เอกสารออกแบบเต็ม (โมดูล M1–M12, แผนรุ่น): https://claude.ai/artifact/6xFxzpbWzk5Vk2e5iZ726G
- เจ้าของ: mengnattawitmarin · ภาษา UI: ไทย · ธีมมืด navy + teal (`lib/theme.dart`)
- แจก APK ผ่าน GitHub Releases (Play Store ไม่อนุญาตตัวบล็อกโฆษณาทั้งระบบ — ดูเอกสารออกแบบ)
- ขอบเขต: **ป้องกันเครื่องของผู้ใช้เองเท่านั้น** ห้ามเพิ่มฟีเจอร์สอดส่อง/ดักข้อมูลคนอื่น/โจมตีกลับ

## สถานะล่าสุด (v0.1 — 2026-11-10)
- ✅ M1 ตรวจสุขภาพเครื่อง (คะแนน 0–100), M2 สแกนแอป + คะแนนความเสี่ยงพร้อมเหตุผล, M3 เฝ้าสิทธิ์อันตราย (งานเบื้องหลังทุก 15 นาที + แจ้งเตือน), M10 โหมดถูกแฮ็ก + เบอร์ธนาคาร 14 แห่ง, หน้าแนะนำ, CI build APK
- ✅ build-1 ผ่าน CI ครบ (analyze, test, build, ตรวจลายเซ็น) — APK 52 MB ที่ Releases
- ⚠️ ยังไม่ทดสอบบนมือถือจริง โดยเฉพาะ: งานเบื้องหลังบน Xiaomi/Oppo/Vivo (ระบบประหยัดแบตอาจฆ่างาน), การอ่าน installer บน Android 8–10
- ยังไม่มี: M4 บล็อกโฆษณา/DNS, M5 ไฟร์วอลล์, M6 ตรวจลิงก์/SMS/QR, M7 กรองสาย, M8 Wi-Fi, M9 รหัสผ่านรั่ว, M11 ข่าวภัย, M12 คู่มือ, ฐานแฮชมัลแวร์

## โครงสร้างโค้ด
```
lib/main.dart                 entry, _Root (onboarding → MainShell), แท็บล่าง 4 แท็บ: หน้าหลัก · สแกนแอป · ถูกแฮ็ก? · ฉัน
lib/app_state.dart            AppState (ChangeNotifier) + AppScope (InheritedNotifier) — scan(), trusted apps, bankingThreats
lib/bridge.dart               Bridge (interface) + ChannelBridge (MethodChannel "krao/native") — เทสต์ใช้ FakeBridge
lib/models.dart               AppInfo, DeviceStatus (fromMap ทนข้อมูลขาด)
lib/logic/app_risk.dart       assessApp/assessAll: คะแนนเสี่ยง + RiskFactor (ภาษาคน), trustedStores, lookalikeKeywords
lib/logic/checkup.dart        runCheckup: คะแนนสุขภาพเครื่อง (มีแอปอันตราย → คะแนนไม่เกิน 49)
lib/data/emergency.dart       ขั้นตอนรับมือ, สัญญาณเตือน, สายด่วน 1441/191/1213, เบอร์ธนาคาร (hotlinesVerified)
lib/actions.dart              runAction(target) — ปุ่ม "แก้ตอนนี้" ทุกปุ่มผ่านที่นี่, callNumber (ยืนยันก่อนโทร)
lib/pages/                    onboarding, home, scan, app_detail, emergency, me
lib/widgets.dart              Panel, SectionTitle, Pill, ScoreRing, Disclaimer, toast, confirm
native/android/kotlin/        MainActivity (channel + openTarget), AppScanner, DeviceInspector, Guard (+GuardScheduler, GuardJobService)
native/android/res/           ไอคอน adaptive (โล่), ไอคอนแจ้งเตือน ic_stat_krao
tool/patch_android.py         หลัง `flutter create` บน CI: คัดลอก Kotlin/res, ใส่สิทธิ์ + service ใน manifest, minSdk 26, เซ็นคีย์ทดสอบ
tool/signing/test.keystore    คีย์ทดสอบ (รหัส kraotest, alias krao) — CI ตรวจ SHA-256 6b291fd4…7f27 ทุก build — ห้ามใช้ขึ้น Play Store
test/                         risk_test (ตรรกะ), widget_test (แอปเปิดได้ + เตือนแอปดูดเงิน), fakes.dart
.github/workflows/build.yml   create → patch → analyze → test → build APK → ตรวจลายเซ็น → Release "build-N"
```
โฟลเดอร์ `android/` **ไม่ commit** (สร้างใหม่ทุก build) — แก้โค้ด native ที่ `native/android/` เท่านั้น

## กฎการตรวจที่สำคัญ (อย่าเปลี่ยนโดยไม่มีเหตุผล)
- แหล่งติดตั้งที่เชื่อถือ: `trustedStores` (Dart) **ต้องตรงกับ** `TRUSTED_STORES` ใน `Guard.kt`
- อันตราย ≥ 60, น่าสงสัย ≥ 25 · แอปมากับเครื่องไม่ให้คะแนน · สัญญาณจะหนักขึ้นมากเมื่อแอปติดตั้งจากนอกร้านค้า
- "ฉันรู้จักแอปนี้" ลดได้แค่เหลือ "น่าสงสัย" (ไม่หายไป เผื่อถูกมิจฉาชีพหลอกให้กด)
- งานเบื้องหลัง (Guard.check) รอบแรกเก็บค่าตั้งต้น ไม่เตือน; เตือนแอปใหม่เฉพาะที่มาจากนอกร้านค้า

## กติกาการแก้โค้ด
1. UI ภาษาไทย ใช้ภาษาที่พ่อแม่อ่านเข้าใจ ศัพท์เทคนิคพับไว้ใน "รายละเอียดทางเทคนิค"
2. ทุกคำเตือนต้องมีปุ่มลงมือ (`action` → `runAction`) ; ข้อมูลประเมินต้องมี `Disclaimer`
3. ข้อมูลผู้ใช้อยู่ในเครื่องเท่านั้น ห้ามเพิ่ม analytics/โฆษณา/SDK ติดตาม ; การส่งอะไรออกเน็ตต้องขอความยินยอม
4. เบอร์โทรใหม่ต้องตรวจจากแหล่งทางการ + แก้ `hotlinesVerified`
5. สิทธิ์/บริการ native ใหม่ → แก้ `tool/patch_android.py` ; logic ใหม่ → เพิ่มเทสต์ ; ใช้ `withValues(alpha:)`
6. Commit ขึ้น `main` → CI build APK (~8–10 นาที) ดูที่ Actions / Releases

## รันบนเครื่อง (ต้องมี Flutter + Android SDK)
```bash
flutter create --org th.krao --project-name krao --platforms android . && python3 tool/patch_android.py
flutter pub get && flutter test && flutter run
```

## งานถัดไป (ตามเอกสารออกแบบ)
1. แก้ error จาก build แรก + ทดสอบบนมือถือจริง (ติดตั้งแอปทดสอบที่ขอ Accessibility → ต้องเตือนแดง)
2. v0.2 เกราะเครือข่าย: VpnService DNS (M4) + ไฟร์วอลล์รายแอป (M5) + บอทอัปเดตรายการบล็อก `data/`
3. v0.3 ตรวจลิงก์/ข้อความ/QR (M6), กรองสาย (M7), Wi-Fi (M8)
4. v0.4 ฐานแฮชมัลแวร์ + stalkerware (M2), รหัสผ่านรั่ว (M9), ข่าวภัย JSON (M11), คู่มือ (M12)
5. หน้าสอนปิดประหยัดแบตตามยี่ห้อ; แจ้งเตือนเมื่องานเบื้องหลังหยุด

## บันทึกการส่งต่อ (เพิ่มรายการใหม่ไว้บนสุด)
| วันที่ | ผู้ทำ | ทำอะไร | ค้าง/ข้อควรรู้ |
|---|---|---|---|
| 2026-11-10 | Claude (claude.ai) | v0.1 "กันแอปดูดเงิน": M1 M2 M3 M10 + หน้าแนะนำ + CI + คีย์ทดสอบ | build-1 ผ่านตั้งแต่รอบแรก; ยังไม่ทดสอบบนมือถือจริง |
