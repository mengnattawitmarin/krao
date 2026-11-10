package th.krao.krao

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager

/** ร้านค้าแอปที่ถือว่าเชื่อถือได้ (แอปจากที่อื่น = ติดตั้งจากไฟล์/ไม่ทราบที่มา) — ต้องตรงกับ lib/logic/app_risk.dart */
val TRUSTED_STORES = setOf(
    "com.android.vending",
    "com.google.android.feedback",
    "com.sec.android.app.samsungapps",
    "com.huawei.appmarket",
    "com.xiaomi.market",
    "com.xiaomi.mipicks",
    "com.heytap.market",
    "com.oppo.market",
    "com.bbk.appstore",
    "com.vivo.appstore",
    "com.amazon.venezia",
)

/** ตั้งงานเบื้องหลังทุก 15 นาที (ขั้นต่ำของ Android) และอยู่รอดหลังรีสตาร์ต */
object GuardScheduler {
    private const val JOB_ID = 4040

    fun schedule(ctx: Context) {
        val js = ctx.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
        if (js.getPendingJob(JOB_ID) != null) return
        val job = JobInfo.Builder(JOB_ID, ComponentName(ctx, GuardJobService::class.java))
            .setPeriodic(15 * 60 * 1000L)
            .setPersisted(true)
            .build()
        js.schedule(job)
    }

    fun isScheduled(ctx: Context): Boolean = try {
        val js = ctx.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
        js.getPendingJob(JOB_ID) != null
    } catch (ignored: Exception) {
        false
    }
}

class GuardJobService : JobService() {
    override fun onStartJob(params: JobParameters?): Boolean {
        Thread {
            try {
                Guard.check(applicationContext, notify = true)
            } catch (ignored: Throwable) {
            }
            jobFinished(params, false)
        }.start()
        return true
    }

    override fun onStopJob(params: JobParameters?): Boolean = true
}

/**
 * เทียบสภาพเครื่องตอนนี้กับรอบก่อน แล้วเตือนเมื่อ:
 * 1) มีแอปใหม่ที่ติดตั้งจากนอกร้านค้า (แดง ถ้ามีความสามารถแบบแอปดูดเงิน)
 * 2) มีแอปเพิ่งได้สิทธิ์ช่วยการเข้าถึง / ผู้ดูแลอุปกรณ์ / อ่านการแจ้งเตือน
 * รอบแรกเก็บเป็นค่าตั้งต้นโดยไม่เตือน
 */
object Guard {
    private const val PREFS = "krao_guard"
    private const val CHANNEL = "krao_alerts"

    fun check(ctx: Context, notify: Boolean) {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val pm = ctx.packageManager
        val own = ctx.packageName
        val baseline = !prefs.contains("known_pkgs")

        val installed = pm.getInstalledApplications(0)
        val userApps = installed.filter {
            it.packageName != own &&
                ((it.flags and ApplicationInfo.FLAG_SYSTEM) == 0 || (it.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0)
        }
        val current = userApps.map { it.packageName }.toSet()
        val a11yNow = AppScanner.accessibilityEnabled(ctx) - own
        val adminNow = AppScanner.adminActive(ctx) - own
        val listenersNow = AppScanner.notificationListeners(ctx) - own

        if (!baseline && notify) {
            val known = prefs.getStringSet("known_pkgs", emptySet()) ?: emptySet()
            val a11yOffered = AppScanner.accessibilityOffered(ctx)
            for (ai in userApps) {
                if (known.contains(ai.packageName)) continue
                alertNewApp(ctx, pm, ai, a11yOffered.contains(ai.packageName))
            }
            val a11yBefore = prefs.getStringSet("a11y", emptySet()) ?: emptySet()
            for (pkg in a11yNow - a11yBefore) {
                post(
                    ctx, "a11y:$pkg", true,
                    "${label(pm, pkg)} เพิ่งได้สิทธิ์ควบคุมหน้าจอ",
                    "แอปนี้อ่านหน้าจอและกดแทนคุณได้ ถ้าคุณไม่ได้เปิดเอง: อย่าเปิดแอปธนาคาร ปิดเน็ต แล้วเข้าแอปเกราะเพื่อถอนสิทธิ์",
                )
            }
            val adminBefore = prefs.getStringSet("admin", emptySet()) ?: emptySet()
            for (pkg in adminNow - adminBefore) {
                post(
                    ctx, "admin:$pkg", true,
                    "${label(pm, pkg)} เพิ่งเป็นผู้ดูแลอุปกรณ์",
                    "แอปผู้ดูแลอุปกรณ์ล็อกเครื่องหรือกันไม่ให้ถอนแอปได้ ถ้าไม่ใช่แอปที่ทำงาน/โรงเรียนให้ติดตั้ง ให้ถอนสิทธิ์ทันที",
                )
            }
            val listenersBefore = prefs.getStringSet("listeners", emptySet()) ?: emptySet()
            for (pkg in listenersNow - listenersBefore) {
                post(
                    ctx, "notif:$pkg", false,
                    "${label(pm, pkg)} อ่านการแจ้งเตือนได้แล้ว",
                    "แอปนี้เห็นข้อความ OTP และแชตที่เด้งขึ้นมา ถ้าไม่ได้ตั้งเองให้ปิดสิทธิ์",
                )
            }
        }

        prefs.edit()
            .putStringSet("known_pkgs", current)
            .putStringSet("a11y", a11yNow)
            .putStringSet("admin", adminNow)
            .putStringSet("listeners", listenersNow)
            .putLong("last_check", System.currentTimeMillis())
            .apply()
    }

    private fun alertNewApp(ctx: Context, pm: PackageManager, ai: ApplicationInfo, offersA11y: Boolean) {
        val installer = AppScanner.installer(pm, ai.packageName)
        val sideloaded = installer == null || !TRUSTED_STORES.contains(installer)
        if (!sideloaded) return
        val perms = try {
            pm.getPackageInfo(ai.packageName, PackageManager.GET_PERMISSIONS).requestedPermissions?.toSet() ?: emptySet()
        } catch (ignored: Exception) {
            emptySet<String>()
        }
        val sms = perms.contains("android.permission.READ_SMS") || perms.contains("android.permission.RECEIVE_SMS")
        val overlay = perms.contains("android.permission.SYSTEM_ALERT_WINDOW")
        val name = label(pm, ai.packageName)
        if (offersA11y || sms || overlay) {
            post(
                ctx, "new:${ai.packageName}", true,
                "อันตราย: $name ติดตั้งจากนอกร้านค้า",
                "แอปนี้มีความสามารถแบบเดียวกับแอปดูดเงิน (ควบคุมหน้าจอ/อ่าน SMS/แสดงทับแอปอื่น) ถ้าไม่ได้ตั้งใจติดตั้ง ให้ถอนทันที และห้ามให้สิทธิ์ใด ๆ",
            )
        } else {
            post(
                ctx, "new:${ai.packageName}", false,
                "$name ติดตั้งจากนอกร้านค้า",
                "แอปที่ไม่ได้มาจาก Play Store เสี่ยงกว่าปกติ แตะเพื่อตรวจในแอปเกราะ",
            )
        }
    }

    private fun label(pm: PackageManager, pkg: String): String = try {
        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
    } catch (ignored: Exception) {
        pkg
    }

    /** ไอคอนโล่ขาวดำที่ patch script วางไว้ (ic_stat_krao) — ถ้าไม่มีใช้ไอคอนแอป */
    @android.annotation.SuppressLint("DiscouragedApi")
    private fun smallIcon(ctx: Context): Int {
        val id = ctx.resources.getIdentifier("ic_stat_krao", "drawable", ctx.packageName)
        return if (id != 0) id else ctx.applicationInfo.icon
    }

    private fun post(ctx: Context, key: String, danger: Boolean, title: String, body: String) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "เตือนภัยความปลอดภัย", NotificationManager.IMPORTANCE_HIGH),
            )
        }
        val open = Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val pi = PendingIntent.getActivity(ctx, key.hashCode(), open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val n = Notification.Builder(ctx, CHANNEL)
            .setSmallIcon(smallIcon(ctx))
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setColor(if (danger) 0xFFE5484D.toInt() else 0xFFF5A524.toInt())
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()
        try {
            nm.notify(key.hashCode(), n)
        } catch (ignored: SecurityException) {
            // ผู้ใช้ไม่อนุญาตการแจ้งเตือน — ผลจะแสดงในแอปตอนเปิดแทน
        }
    }
}
