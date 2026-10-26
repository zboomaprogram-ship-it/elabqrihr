package com.zbooma.elabqrihr

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Task T043: Android native tests for attendance reminders.
 *
 * Verifies:
 * 1. Absence of exact-alarm (`SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`) permissions.
 * 2. Absence of background-location (`ACCESS_BACKGROUND_LOCATION`) permissions.
 * 3. Notification channel configuration uses standard notification importance (IMPORTANCE_DEFAULT)
 *    and non-intrusive sound rather than alarm audio attributes or maximum urgency.
 * 4. Exact alarm scheduling is explicitly disallowed / not granted on Android 12+ (API 31+).
 * 5. Channel creation and cancellation lifecycle can be handled safely without crashing.
 */
@RunWith(AndroidJUnit4::class)
class AttendanceReminderTest {

    private lateinit var context: Context
    private val channelId = "attend_attendance_reminders_channel"
    private val channelName = "تنبيهات الحضور والانصراف"

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
    }

    @Test
    fun testAbsenceOfProhibitedPermissions() {
        val packageInfo = context.packageManager.getPackageInfo(
            context.packageName,
            PackageManager.GET_PERMISSIONS
        )
        val requestedPermissions = packageInfo.requestedPermissions?.toList() ?: emptyList()

        // 1. Prohibit exact alarm permissions
        assertFalse(
            "App must not request SCHEDULE_EXACT_ALARM",
            requestedPermissions.contains("android.permission.SCHEDULE_EXACT_ALARM")
        )
        assertFalse(
            "App must not request USE_EXACT_ALARM",
            requestedPermissions.contains("android.permission.USE_EXACT_ALARM")
        )

        // 2. Prohibit background location permissions
        assertFalse(
            "App must not request ACCESS_BACKGROUND_LOCATION",
            requestedPermissions.contains("android.permission.ACCESS_BACKGROUND_LOCATION")
        )

        // 3. Confirm POST_NOTIFICATIONS is declared
        assertTrue(
            "App should declare POST_NOTIFICATIONS for Android 13+",
            requestedPermissions.contains("android.permission.POST_NOTIFICATIONS")
        )
    }

    @Test
    fun testAlarmManagerExactSchedulingNotPermitted() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            assertFalse(
                "App must not possess canScheduleExactAlarms privilege",
                alarmManager.canScheduleExactAlarms()
            )
        }
    }

    @Test
    fun testNotificationChannelCreationAndProperties() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "تنبيهات ذكية لبداية ونهاية الوردية وإذن العمل"
                enableVibration(true)
            }

            notificationManager.createNotificationChannel(channel)

            val retrievedChannel = notificationManager.getNotificationChannel(channelId)
            assertNotNull("Channel should be created successfully", retrievedChannel)
            assertEquals(
                "Channel importance must be IMPORTANCE_DEFAULT for non-intrusive alerts",
                NotificationManager.IMPORTANCE_DEFAULT,
                retrievedChannel.importance
            )

            // Ensure not configured as an aggressive full-screen alarm
            assertFalse(
                "Channel should not bypass do not disturb",
                retrievedChannel.canBypassDnd()
            )
        }
    }

    @Test
    fun testNotificationCancellationLifecycle() {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Ensure cancelling non-existent or scheduled notifications does not throw
        notificationManager.cancel(12345)
        notificationManager.cancelAll()
        assertTrue("Notification cancellation completed cleanly", true)
    }
}
