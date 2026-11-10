#!/usr/bin/env python3
"""ปรับโฟลเดอร์ android/ ที่ `flutter create` สร้างใหม่บน CI ให้เป็นแอปเกราะ

ทำ 4 อย่าง (ถ้าหาจุดที่จะแก้ไม่เจอจะหยุดพร้อม error ชัด ๆ ไม่ build แอปพัง ๆ ออกไป):
1. คัดลอกโค้ด Kotlin จาก native/android/kotlin/ ไปทับ (แก้บรรทัด package ให้ตรงกับที่ flutter สร้าง)
2. คัดลอก resource (ไอคอน) จาก native/android/res/
3. AndroidManifest.xml: สิทธิ์, JobService, ชื่อแอป "เกราะ"
4. app/build.gradle(.kts): minSdk 26 + เซ็นด้วยคีย์ทดสอบ tool/signing/test.keystore

รัน: python3 tool/patch_android.py   (จากรากโปรเจกต์ หลัง flutter create)
"""
import pathlib
import re
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ANDROID = ROOT / "android"
APP = ANDROID / "app"
NATIVE = ROOT / "native" / "android"

PERMISSIONS = [
    "android.permission.QUERY_ALL_PACKAGES",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.REQUEST_DELETE_PACKAGES",
    "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
]

SERVICES = """
        <service
            android:name=".GuardJobService"
            android:permission="android.permission.BIND_JOB_SERVICE"
            android:exported="false" />
"""

SIGNING_KTS = """
    signingConfigs {
        create("kraoTest") {
            storeFile = rootProject.file("../tool/signing/test.keystore")
            storePassword = "kraotest"
            keyAlias = "krao"
            keyPassword = "kraotest"
        }
    }
"""

SIGNING_GROOVY = """
    signingConfigs {
        kraoTest {
            storeFile rootProject.file("../tool/signing/test.keystore")
            storePassword "kraotest"
            keyAlias "krao"
            keyPassword "kraotest"
        }
    }
"""


def fail(msg: str) -> None:
    print(f"::error::patch_android: {msg}")
    sys.exit(1)


def copy_kotlin() -> None:
    mains = list((APP / "src" / "main").rglob("MainActivity.kt"))
    if not mains:
        fail("ไม่พบ MainActivity.kt — รัน flutter create ก่อน")
    target_dir = mains[0].parent
    m = re.search(r"^package\s+([\w.]+)", mains[0].read_text(), re.M)
    if not m:
        fail("อ่าน package ของ MainActivity.kt ไม่ได้")
    pkg = m.group(1)
    for src in sorted((NATIVE / "kotlin").glob("*.kt")):
        code = re.sub(r"^package\s+[\w.]+", f"package {pkg}", src.read_text(), count=1, flags=re.M)
        (target_dir / src.name).write_text(code)
        print(f"kotlin: {src.name} → {target_dir.relative_to(ROOT)} (package {pkg})")


def copy_res() -> None:
    res_src = NATIVE / "res"
    res_dst = APP / "src" / "main" / "res"
    for f in res_src.rglob("*"):
        if f.is_file():
            dst = res_dst / f.relative_to(res_src)
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(f, dst)
            print(f"res: {dst.relative_to(ROOT)}")


def patch_manifest() -> None:
    path = APP / "src" / "main" / "AndroidManifest.xml"
    xml = path.read_text()
    perms = "".join(
        f'    <uses-permission android:name="{p}" />\n' for p in PERMISSIONS if p not in xml
    )
    if "<application" not in xml:
        fail("ไม่พบ <application ใน AndroidManifest.xml")
    xml = xml.replace("<application", perms + "    <application", 1) if perms else xml
    xml, n = re.subn(r'android:label="[^"]*"', 'android:label="เกราะ"', xml, count=1)
    if n == 0:
        fail("ไม่พบ android:label")
    if "GuardJobService" not in xml:
        if "</application>" not in xml:
            fail("ไม่พบ </application>")
        xml = xml.replace("</application>", SERVICES + "    </application>", 1)
    path.write_text(xml)
    print("manifest: สิทธิ์ + GuardJobService + ชื่อแอป")


def patch_gradle() -> None:
    kts = APP / "build.gradle.kts"
    groovy = APP / "build.gradle"
    if kts.exists():
        path, signing, use = kts, SIGNING_KTS, 'signingConfig = signingConfigs.getByName("kraoTest")'
        min_re, min_new = r"minSdk\s*=\s*[^\n]+", "minSdk = 26"
    elif groovy.exists():
        path, signing, use = groovy, SIGNING_GROOVY, "signingConfig signingConfigs.kraoTest"
        min_re, min_new = r"minSdk(?:Version)?\s+[^\n]+", "minSdkVersion 26"
    else:
        fail("ไม่พบ app/build.gradle(.kts)")
    g = path.read_text()
    g, n = re.subn(min_re, min_new, g, count=1)
    if n == 0:
        fail("ไม่พบ minSdk ใน " + path.name)
    if "kraoTest" not in g:
        g, n = re.subn(r"(\nandroid\s*\{\n)", r"\1" + signing.replace("\\", "\\\\"), g, count=1)
        if n == 0:
            fail("ไม่พบบล็อก android { ใน " + path.name)
        g, n = re.subn(r"signingConfig\s*=?\s*signingConfigs\.(getByName\(\"debug\"\)|debug)", use, g)
        if n == 0:
            fail("ไม่พบบรรทัด signingConfig ของ release ใน " + path.name)
    path.write_text(g)
    print(f"gradle: {path.name} minSdk 26 + เซ็นด้วย tool/signing/test.keystore")


if __name__ == "__main__":
    if not ANDROID.exists():
        fail("ยังไม่มีโฟลเดอร์ android/ — รัน flutter create --platforms android . ก่อน")
    copy_kotlin()
    copy_res()
    patch_manifest()
    patch_gradle()
    print("patch_android: เสร็จ")
