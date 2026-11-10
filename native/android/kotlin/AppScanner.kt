package th.krao.krao

import android.app.AppOpsManager
import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.provider.Telephony
import android.view.accessibility.AccessibilityManager
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest

/**
 * อ่านข้อมูลแอปที่ติดตั้งทั้งหมด (ต้องมี QUERY_ALL_PACKAGES)
 * ไม่แตะข้อมูลภายในของแอปอื่น — อ่านเฉพาะสิ่งที่ระบบเปิดให้ทุกแอปความปลอดภัยอ่านได้
 */
object AppScanner {

    /** สิทธิ์ที่น่าสนใจทางความปลอดภัย (ส่งกลับเฉพาะตัวที่แอปขอ) */
    private val watchedPermissions = setOf(
        "android.permission.READ_SMS",
        "android.permission.RECEIVE_SMS",
        "android.permission.SEND_SMS",
        "android.permission.RECEIVE_MMS",
        "android.permission.READ_CALL_LOG",
        "android.permission.PROCESS_OUTGOING_CALLS",
        "android.permission.CALL_PHONE",
        "android.permission.READ_CONTACTS",
        "android.permission.RECORD_AUDIO",
        "android.permission.CAMERA",
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.ACCESS_BACKGROUND_LOCATION",
        "android.permission.SYSTEM_ALERT_WINDOW",
        "android.permission.REQUEST_INSTALL_PACKAGES",
        "android.permission.REQUEST_DELETE_PACKAGES",
        "android.permission.QUERY_ALL_PACKAGES",
        "android.permission.READ_PHONE_STATE",
        "android.permission.READ_EXTERNAL_STORAGE",
        "android.permission.MANAGE_EXTERNAL_STORAGE",
        "android.permission.PACKAGE_USAGE_STATS",
        "android.permission.BIND_ACCESSIBILITY_SERVICE",
        "android.permission.BIND_DEVICE_ADMIN",
        "android.permission.BIND_NOTIFICATION_LISTENER_SERVICE",
        "android.permission.FOREGROUND_SERVICE",
        "android.permission.RECEIVE_BOOT_COMPLETED",
        "android.permission.WRITE_SETTINGS",
        "android.permission.USE_FULL_SCREEN_INTENT",
    )

    fun scan(ctx: Context): List<Map<String, Any?>> {
        val pm = ctx.packageManager
        val own = ctx.packageName
        val a11yOffered = accessibilityOffered(ctx)
        val a11yEnabled = accessibilityEnabled(ctx)
        val adminOffered = adminOffered(pm)
        val adminActive = adminActive(ctx)
        val listeners = notificationListeners(ctx)
        val defaultSms = try { Telephony.Sms.getDefaultSmsPackage(ctx) } catch (ignored: Exception) { null }
        val apps = pm.getInstalledApplications(0)
        val out = ArrayList<Map<String, Any?>>(apps.size)
        for (ai in apps) {
            val pkg = ai.packageName
            if (pkg == own) continue
            val info = packageInfo(pm, pkg) ?: continue
            val requested = info.requestedPermissions?.toList() ?: emptyList()
            val isSystem = (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            val updatedSystem = (ai.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
            out.add(
                mapOf(
                    "package" to pkg,
                    "label" to safeLabel(pm, ai),
                    "versionName" to (info.versionName ?: ""),
                    "installer" to installer(pm, pkg),
                    "firstInstall" to info.firstInstallTime,
                    "lastUpdate" to info.lastUpdateTime,
                    "system" to (isSystem && !updatedSystem),
                    "updatedSystem" to updatedSystem,
                    "hasLauncher" to (pm.getLaunchIntentForPackage(pkg) != null),
                    "permissions" to requested.filter { watchedPermissions.contains(it) },
                    "a11yOffered" to a11yOffered.contains(pkg),
                    "a11yEnabled" to a11yEnabled.contains(pkg),
                    "adminOffered" to adminOffered.contains(pkg),
                    "adminActive" to adminActive.contains(pkg),
                    "notifListener" to listeners.contains(pkg),
                    "overlayAllowed" to (requested.contains("android.permission.SYSTEM_ALERT_WINDOW") &&
                        opAllowed(ctx, AppOpsManager.OPSTR_SYSTEM_ALERT_WINDOW, ai.uid, pkg)),
                    "canInstallApps" to (requested.contains("android.permission.REQUEST_INSTALL_PACKAGES") &&
                        opAllowed(ctx, "android:request_install_packages", ai.uid, pkg)),
                    "defaultSms" to (pkg == defaultSms),
                    "certSha256" to certSha256(info),
                    "targetSdk" to ai.targetSdkVersion,
                    "debuggable" to ((ai.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0),
                ),
            )
        }
        return out
    }

    @Suppress("DEPRECATION")
    private fun packageInfo(pm: PackageManager, pkg: String): PackageInfo? {
        val flags = PackageManager.GET_PERMISSIONS or
            (if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES)
        return try {
            pm.getPackageInfo(pkg, flags)
        } catch (ignored: Exception) {
            null
        }
    }

    private fun safeLabel(pm: PackageManager, ai: ApplicationInfo): String =
        try { pm.getApplicationLabel(ai).toString() } catch (ignored: Exception) { ai.packageName }

    @Suppress("DEPRECATION")
    fun installer(pm: PackageManager, pkg: String): String? = try {
        if (Build.VERSION.SDK_INT >= 30) pm.getInstallSourceInfo(pkg).installingPackageName
        else pm.getInstallerPackageName(pkg)
    } catch (ignored: Exception) {
        null
    }

    @Suppress("DEPRECATION")
    private fun certSha256(info: PackageInfo): String? {
        val sigs = if (Build.VERSION.SDK_INT >= 28) {
            val si = info.signingInfo ?: return null
            if (si.hasMultipleSigners()) si.apkContentsSigners else si.signingCertificateHistory
        } else {
            info.signatures
        }
        val first = sigs?.firstOrNull() ?: return null
        return hex(MessageDigest.getInstance("SHA-256").digest(first.toByteArray()))
    }

    fun accessibilityOffered(ctx: Context): Set<String> = try {
        val am = ctx.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        am.installedAccessibilityServiceList.mapNotNull { it.resolveInfo?.serviceInfo?.packageName }.toSet()
    } catch (ignored: Exception) {
        emptySet()
    }

    fun accessibilityEnabled(ctx: Context): Set<String> =
        componentPackages(Settings.Secure.getString(ctx.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES))

    fun notificationListeners(ctx: Context): Set<String> =
        componentPackages(Settings.Secure.getString(ctx.contentResolver, "enabled_notification_listeners"))

    private fun componentPackages(raw: String?): Set<String> {
        if (raw.isNullOrBlank()) return emptySet()
        return raw.split(':')
            .mapNotNull { ComponentName.unflattenFromString(it.trim())?.packageName }
            .toSet()
    }

    private fun adminOffered(pm: PackageManager): Set<String> = try {
        pm.queryBroadcastReceivers(Intent(DeviceAdminReceiver.ACTION_DEVICE_ADMIN_ENABLED), 0)
            .mapNotNull { it.activityInfo?.packageName }
            .toSet()
    } catch (ignored: Exception) {
        emptySet()
    }

    fun adminActive(ctx: Context): Set<String> = try {
        val dpm = ctx.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        (dpm.activeAdmins ?: emptyList()).map { it.packageName }.toSet()
    } catch (ignored: Exception) {
        emptySet()
    }

    @Suppress("DEPRECATION")
    private fun opAllowed(ctx: Context, op: String, uid: Int, pkg: String): Boolean = try {
        val aom = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= 29) aom.unsafeCheckOpNoThrow(op, uid, pkg)
        else aom.checkOpNoThrow(op, uid, pkg)
        mode == AppOpsManager.MODE_ALLOWED
    } catch (ignored: Exception) {
        false
    }

    /** SHA-256 ของไฟล์ APK หลัก (ใช้เทียบฐานมัลแวร์ในรุ่นถัดไป) */
    fun apkSha256(ctx: Context, pkg: String): String? {
        val path = try { ctx.packageManager.getApplicationInfo(pkg, 0).sourceDir } catch (ignored: Exception) { return null }
        val md = MessageDigest.getInstance("SHA-256")
        FileInputStream(File(path)).use { input ->
            val buf = ByteArray(64 * 1024)
            while (true) {
                val n = input.read(buf)
                if (n <= 0) break
                md.update(buf, 0, n)
            }
        }
        return hex(md.digest())
    }

    private fun hex(bytes: ByteArray): String = bytes.joinToString("") { "%02x".format(it) }
}
