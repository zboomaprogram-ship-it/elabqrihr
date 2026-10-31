package com.zbooma.elabqrihr

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.work.ListenableWorker
import androidx.work.testing.TestWorkerBuilder
import androidx.work.workDataOf
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.Executor

class BackgroundSyncWorkerTest {
    private val context: Context
        get() = ApplicationProvider.getApplicationContext()

    private fun worker(inputData: androidx.work.Data = androidx.work.Data.EMPTY) =
        TestWorkerBuilder.from<BackgroundSyncWorker>(
            context,
            BackgroundSyncWorker::class.java,
            Executor { command -> command.run() },
        ).setInputData(inputData).build()

    @Test
    fun missingIdentityFailsWithoutStartingReplay() {
        val worker = worker()
        var invoked = false
        worker.runner = object : BackgroundSyncRunner {
            override fun run(context: Context, tenantId: String, userId: String): Boolean {
                invoked = true
                return true
            }
        }

        assertTrue(worker.doWork() is ListenableWorker.Result.Failure)
        assertFalse(invoked)
    }

    @Test
    fun passesScheduledIdentityToReplayAndSucceedsOnCompletion() {
        val worker = worker(
            workDataOf(
                BackgroundSyncWorker.TENANT_ID_KEY to "tenant-qa",
                BackgroundSyncWorker.USER_ID_KEY to "user-qa",
            ),
        )
        var received: Pair<String, String>? = null
        worker.runner = object : BackgroundSyncRunner {
            override fun run(context: Context, tenantId: String, userId: String): Boolean {
                received = tenantId to userId
                return true
            }
        }

        assertTrue(worker.doWork() is ListenableWorker.Result.Success)
        assertEquals("tenant-qa" to "user-qa", received)
    }

    @Test
    fun executorFailureRequestsWorkManagerRetry() {
        val worker = worker(
            workDataOf(
                BackgroundSyncWorker.TENANT_ID_KEY to "tenant-qa",
                BackgroundSyncWorker.USER_ID_KEY to "user-qa",
            ),
        )
        worker.runner = object : BackgroundSyncRunner {
            override fun run(context: Context, tenantId: String, userId: String) = false
        }

        assertTrue(worker.doWork() is ListenableWorker.Result.Retry)
    }

    @Test
    fun headlessFlutterEntrypointCompletesWithoutProductionSideEffectsInQa() {
        assertTrue(
            FlutterHeadlessBackgroundSyncRunner().run(
                context,
                "tenant-headless-test",
                "user-headless-test",
            ),
        )
    }
}
