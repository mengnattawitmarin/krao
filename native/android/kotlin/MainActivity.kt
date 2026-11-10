package th.krao.krao

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * ช่องทางหลักระหว่าง Flutter กับระบบ Android ("krao/native")
 * งานหนัก (สแกนแอป/คำนวณแฮช) ทำบน thread แยก แล้วส่งผลกลับบน main thread
 */
class MainActivity : FlutterActivity() {
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "krao/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deviceStatus" -> background(result) { DeviceInspector.status(this) }
                    "scanApps" -> background(result) { AppScanner.scan(this) }
                    "hashApk" -> {
                        val pkg = call.argument<String>("package")
                        if (pkg == null) result.error("arg", "missing package", null)
                        else background(result) { AppScanner.apkSha256(this, pkg) }
                    }
                    "open" -> {
                        val ok = openTarget(
                            call.argument<String>("target") ?: "",
                            call.argument<String>("package"),
                            call.argument<String>("number"),
                        )
                        result.success(ok)
                    }
                    "startGuard" -> background(result) {
                        GuardScheduler.schedule(this)
                        Guard.check(this, notify = false)
                        true
                    }
                    "guardScheduled" -> result.success(GuardScheduler.isScheduled(this))
                    "requestNotifications" -> {
                        if (Build.VERSION.SDK_INT >= 33) {
                            requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 77)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        Thread {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Throwable) {
                main.post { result.error("native", e.message ?: e.javaClass.simpleName, null) }
            }
        }.start()
    }

    /** เปิดหน้าตั้งค่าของระบบตรงจุดที่ต้องแก้ ถ้าเปิดไม่ได้จะเปิดหน้าตั้งค่าหลักแทน */
    private fun openTarget(target: String, pkg: String?, number: String?): Boolean {
        val pkgUri = if (pkg != null) Uri.parse("package:$pkg") else null
        val intent: Intent = when (target) {
            "app" -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkgUri)
            "uninstall" -> Intent(Intent.ACTION_DELETE, pkgUri)
            "accessibility" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            "security", "device_admin" -> Intent(Settings.ACTION_SECURITY_SETTINGS)
            "developer" -> Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
            "unknown_sources" -> Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
            "overlay" -> Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, pkgUri)
            "notification_listeners" -> Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            "lock" -> Intent(android.app.admin.DevicePolicyManager.ACTION_SET_NEW_PASSWORD)
            "airplane" -> Intent(Settings.ACTION_AIRPLANE_MODE_SETTINGS)
            "update", "about" -> Intent(Settings.ACTION_DEVICE_INFO_SETTINGS)
            "battery" -> Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            "dial" -> Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + (number ?: "")))
            "web" -> Intent(Intent.ACTION_VIEW, Uri.parse(number ?: "https://www.thaipoliceonline.go.th"))
            else -> Intent(Settings.ACTION_SETTINGS)
        }
        return try {
            startActivity(intent)
            true
        } catch (e: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_SETTINGS))
            } catch (ignored: Exception) {
            }
            false
        }
    }
}
