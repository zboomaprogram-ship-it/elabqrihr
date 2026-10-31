package com.zbooma.elabqrihr

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Native Android WorkManager scheduler implementing Feature 012 Task T062.
 *
 * Requirements:
 * 1. Register one unique network-constrained job per authenticated identity.
 * 2. Stable unique work name format: `background_sync_{tenantId}_{userId}`.
 * 3. Connected network constraint (requires unmetered or metered network).
 * 4. KEEP or REPLACE existing work policy to prevent multiple duplicates.
 * 5. Prohibit background location tracking.
 */
object BackgroundSyncPlugin : MethodChannel.MethodCallHandler {
    private const val channelName = "com.zbooma.elabqrihr/background_sync"
    private const val qaApplicationId = "com.zbooma.elabqrihr.qa"
    private lateinit var context: Context

    fun attach(messenger: BinaryMessenger, applicationContext: Context) {
        context = applicationContext
        MethodChannel(messenger, channelName).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scheduleForIdentity" -> {
                val tenantId = call.argument<String>("tenantId")
                val userId = call.argument<String>("userId")
                if (tenantId.isNullOrBlank() || userId.isNullOrBlank()) {
                    result.error("INVALID_IDENTITY", "tenantId and userId are required", null)
                    return
                }
                try {
                    enqueueForIdentity(context, tenantId, userId)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SCHEDULER_ERROR", "Failed to schedule WorkManager job", null)
                }
            }
            "cancelForIdentity" -> {
                val tenantId = call.argument<String>("tenantId")
                val userId = call.argument<String>("userId")
                if (tenantId.isNullOrBlank() || userId.isNullOrBlank()) {
                    result.error("INVALID_IDENTITY", "tenantId and userId are required", null)
                    return
                }
                try {
                    cancelForIdentity(context, tenantId, userId)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SCHEDULER_ERROR", "Failed to cancel WorkManager job", null)
                }
            }
            "enqueueOnceForQa" -> {
                val tenantId = call.argument<String>("tenantId")
                val userId = call.argument<String>("userId")
                val delaySeconds = call.argument<Int>("initialDelaySeconds") ?: 15
                if (tenantId.isNullOrBlank() || userId.isNullOrBlank()) {
                    result.error("INVALID_IDENTITY", "tenantId and userId are required", null)
                    return
                }
                if (!isQaDebugPackage(context)) {
                    result.error("QA_ONLY", "Test replay is unavailable in production", null)
                    return
                }
                if (delaySeconds !in 0..120) {
                    result.error("INVALID_DELAY", "QA replay delay must be at most 120 seconds", null)
                    return
                }
                try {
                    enqueueOnceForQa(context, tenantId, userId, delaySeconds.toLong())
                    result.success(true)
                } catch (_: Exception) {
                    result.error("SCHEDULER_ERROR", "Failed to enqueue isolated QA replay", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    fun workName(tenantId: String, userId: String): String =
        "background_sync_${tenantId}_${userId}"

    fun qaReplayWorkName(tenantId: String, userId: String): String =
        "background_sync_qa_once_${tenantId}_${userId}"

    fun inputDataForIdentity(tenantId: String, userId: String) = workDataOf(
        BackgroundSyncWorker.TENANT_ID_KEY to tenantId,
        BackgroundSyncWorker.USER_ID_KEY to userId,
    )

    fun enqueueForIdentity(applicationContext: Context, tenantId: String, userId: String) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val syncRequest = PeriodicWorkRequestBuilder<BackgroundSyncWorker>(
            15, TimeUnit.MINUTES,
        )
            .setInputData(inputDataForIdentity(tenantId, userId))
            .setConstraints(constraints)
            .build()

        WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
            workName(tenantId, userId),
            ExistingPeriodicWorkPolicy.KEEP,
            syncRequest
        )
    }

    fun cancelForIdentity(applicationContext: Context, tenantId: String, userId: String) {
        WorkManager.getInstance(applicationContext)
            .cancelUniqueWork(workName(tenantId, userId))
    }

    fun enqueueOnceForQa(
        applicationContext: Context,
        tenantId: String,
        userId: String,
        initialDelaySeconds: Long = 15,
    ) {
        require(isQaDebugPackage(applicationContext)) {
            "One-time replay is restricted to the debug QA package"
        }
        require(initialDelaySeconds in 0..120)
        val request = OneTimeWorkRequestBuilder<BackgroundSyncWorker>()
            .setInputData(inputDataForIdentity(tenantId, userId))
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build(),
            )
            .setInitialDelay(initialDelaySeconds, TimeUnit.SECONDS)
            .build()
        WorkManager.getInstance(applicationContext).enqueueUniqueWork(
            qaReplayWorkName(tenantId, userId),
            ExistingWorkPolicy.KEEP,
            request,
        )
    }

    private fun isQaDebugPackage(applicationContext: Context): Boolean =
        applicationContext.packageName == qaApplicationId &&
            applicationContext.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0
}

interface BackgroundSyncRunner {
    fun run(context: Context, tenantId: String, userId: String): Boolean
}

class FlutterHeadlessBackgroundSyncRunner : BackgroundSyncRunner {
    override fun run(context: Context, tenantId: String, userId: String): Boolean {
        val appContext = context.applicationContext
        val loader = FlutterInjector.instance().flutterLoader()
        val mainHandler = Handler(Looper.getMainLooper())
        val finished = CountDownLatch(1)
        val destroyed = CountDownLatch(1)
        val stopping = AtomicBoolean(false)
        var engine: FlutterEngine? = null
        var channel: MethodChannel? = null
        var succeeded = false
        try {
            mainHandler.post {
                try {
                    if (!loader.initialized()) loader.startInitialization(appContext)
                    loader.ensureInitializationCompleteAsync(appContext, null, mainHandler) {
                        if (stopping.get()) {
                            finished.countDown()
                            return@ensureInitializationCompleteAsync
                        }
                        try {
                            val headlessEngine = FlutterEngine(appContext)
                            engine = headlessEngine
                            AttendanceTrustPlugin.attach(
                                headlessEngine.dartExecutor.binaryMessenger,
                                appContext,
                            )
                            val workerChannel = MethodChannel(
                                headlessEngine.dartExecutor.binaryMessenger,
                                "com.zbooma.elabqrihr/background_sync/worker",
                            )
                            channel = workerChannel
                            workerChannel.setMethodCallHandler { call, result ->
                                when (call.method) {
                                    "ready" -> {
                                        workerChannel.invokeMethod(
                                            "run",
                                            mapOf(
                                                "tenantId" to tenantId,
                                                "userId" to userId,
                                            ),
                                        )
                                        result.success(null)
                                    }
                                    "completed" -> {
                                        succeeded = call.argument<Boolean>("success") == true
                                        result.success(null)
                                        finished.countDown()
                                    }
                                    else -> result.notImplemented()
                                }
                            }
                            headlessEngine.dartExecutor.executeDartEntrypoint(
                                DartExecutor.DartEntrypoint(
                                    loader.findAppBundlePath(),
                                    "package:attend_mobile/core/network/headless_background_sync.dart",
                                    "attendBackgroundSyncEntrypoint",
                                ),
                            )
                        } catch (_: Exception) {
                            finished.countDown()
                        }
                    }
                } catch (_: Exception) {
                    finished.countDown()
                }
            }
            return finished.await(8, TimeUnit.MINUTES) && succeeded
        } catch (_: InterruptedException) {
            return false
        } catch (_: Exception) {
            return false
        } finally {
            stopping.set(true)
            mainHandler.post {
                channel?.setMethodCallHandler(null)
                engine?.destroy()
                engine = null
                destroyed.countDown()
            }
            try {
                destroyed.await(5, TimeUnit.SECONDS)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            }
        }
    }
}

/**
 * Runs identity-scoped replay when WorkManager has a network-constrained slot.
 */
class BackgroundSyncWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : Worker(appContext, workerParams) {
    var runner: BackgroundSyncRunner = FlutterHeadlessBackgroundSyncRunner()

    override fun doWork(): Result {
        val tenantId = inputData.getString(TENANT_ID_KEY)
        val userId = inputData.getString(USER_ID_KEY)
        if (tenantId.isNullOrBlank() || userId.isNullOrBlank()) return Result.failure()
        return try {
            if (runner.run(applicationContext, tenantId, userId)) {
                Result.success()
            } else {
                Result.retry()
            }
        } catch (_: Exception) {
            Result.retry()
        }
    }

    companion object {
        const val TENANT_ID_KEY = "sync_tenant_id"
        const val USER_ID_KEY = "sync_user_id"
    }
}
