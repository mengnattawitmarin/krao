package th.krao.krao

import android.app.KeyguardManager
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.os.Build
import android.provider.Settings
import java.io.File

/** อ่านสถานะความปลอดภัยของเครื่อง (ไม่ต้องขอสิทธิ์พิเศษ) */
object DeviceInspector {

    private val suPaths = listOf(
        "/system/bin/su", "/system/xbin/su", "/sbin/su", "/su/bin/su",
        "/system/sd/xbin/su", "/data/local/xbin/su", "/data/local/bin/su", "/data/local/su",
        "/system/app/Superuser.apk", "/data/adb/magisk",
    )

    fun status(ctx: Context): Map<String, Any?> {
        val km = ctx.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val dpm = ctx.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val enc = try { dpm.storageEncryptionStatus } catch (ignored: Exception) { -1 }
        val encrypted = enc == DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE ||
            enc == DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE_PER_USER ||
            enc == DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE_DEFAULT_KEY
        val suFound = suPaths.any { p -> try { File(p).exists() } catch (ignored: Exception) { false } }
        val testKeys = Build.TAGS?.contains("test-keys") == true
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "release" to Build.VERSION.RELEASE,
            "sdk" to Build.VERSION.SDK_INT,
            "securityPatch" to Build.VERSION.SECURITY_PATCH,
            "secureLock" to km.isDeviceSecure,
            "adb" to globalOn(ctx, Settings.Global.ADB_ENABLED),
            "devOptions" to globalOn(ctx, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED),
            "rooted" to (suFound || testKeys),
            "encryption" to (if (enc < 0) null else encrypted),
            "a11yEnabled" to AppScanner.accessibilityEnabled(ctx).toList(),
            "adminActive" to AppScanner.adminActive(ctx).toList(),
            "guardScheduled" to GuardScheduler.isScheduled(ctx),
            "batteryUnrestricted" to batteryUnrestricted(ctx),
        )
    }

    private fun globalOn(ctx: Context, key: String): Boolean = try {
        Settings.Global.getInt(ctx.contentResolver, key, 0) != 0
    } catch (ignored: Exception) {
        false
    }

    private fun batteryUnrestricted(ctx: Context): Boolean = try {
        val pm = ctx.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
        pm.isIgnoringBatteryOptimizations(ctx.packageName)
    } catch (ignored: Exception) {
        false
    }
}
