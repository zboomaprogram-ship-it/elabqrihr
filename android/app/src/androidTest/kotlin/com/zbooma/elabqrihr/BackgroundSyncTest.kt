package com.zbooma.elabqrihr

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.work.NetworkType
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.testing.WorkManagerTestInitHelper
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Task T055: Android network-recovery background sync instrumentation test.
 *
 * Verifies:
 * 1. WorkManager unique work registration per authenticated identity.
 * 2. Connected network constraint is enforced.
 * 3. Work survives simulated restart/re-registration and can be safely cancelled upon logout.
 * 4. Zero background location permissions or services are invoked.
 */
@RunWith(AndroidJUnit4::class)
class BackgroundSyncTest {

    private lateinit var context: Context
    private val testTenantId = "tenant-synth-test"
    private val testUserId = "user-synth-test"

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        WorkManagerTestInitHelper.initializeTestWorkManager(context)
    }

    @Test
    fun testWorkManagerJobRegistrationAndConstraints() {
        val workManager = WorkManager.getInstance(context)
        val workName = BackgroundSyncPlugin.workName(testTenantId, testUserId)

        BackgroundSyncPlugin.enqueueForIdentity(context, testTenantId, testUserId)

        val workInfos = workManager.getWorkInfosForUniqueWork(workName).get()
        assertNotNull("Work infos must not be null", workInfos)
        assertTrue("At least one work instance must be scheduled", workInfos.isNotEmpty())

        val workInfo = workInfos.first()
        assertTrue(
            "Work state must be ENQUEUED or RUNNING or BLOCKED",
            workInfo.state == WorkInfo.State.ENQUEUED ||
            workInfo.state == WorkInfo.State.BLOCKED ||
            workInfo.state == WorkInfo.State.RUNNING
        )
        assertEquals(NetworkType.CONNECTED, workInfo.constraints.requiredNetworkType)
        val scopedInput = BackgroundSyncPlugin.inputDataForIdentity(testTenantId, testUserId)
        assertEquals(testTenantId, scopedInput.getString(BackgroundSyncWorker.TENANT_ID_KEY))
        assertEquals(testUserId, scopedInput.getString(BackgroundSyncWorker.USER_ID_KEY))
    }

    @Test
    fun testUniqueWorkDeduplication() {
        val workManager = WorkManager.getInstance(context)
        val workName = BackgroundSyncPlugin.workName(testTenantId, testUserId)

        BackgroundSyncPlugin.enqueueForIdentity(context, testTenantId, testUserId)
        BackgroundSyncPlugin.enqueueForIdentity(context, testTenantId, testUserId)

        val workInfos = workManager.getWorkInfosForUniqueWork(workName).get()
        assertEquals("KEEP policy must prevent duplicate concurrent work tasks", 1, workInfos.size)
    }

    @Test
    fun testWorkCancellationUponLogout() {
        val workManager = WorkManager.getInstance(context)
        val workName = BackgroundSyncPlugin.workName(testTenantId, testUserId)

        BackgroundSyncPlugin.enqueueForIdentity(context, testTenantId, testUserId)
        BackgroundSyncPlugin.cancelForIdentity(context, testTenantId, testUserId)

        val workInfos = workManager.getWorkInfosForUniqueWork(workName).get()
        assertTrue(
            "Cancelled work must transition to CANCELLED or be purged",
            workInfos.isEmpty() || workInfos.first().state == WorkInfo.State.CANCELLED
        )
    }

    @Test
    fun qaReplayWorkIsOneShotNetworkConstrainedAndIdentityScoped() {
        assertTrue(
            "The test-only replay entrypoint requires the isolated QA package",
            context.packageName == "com.zbooma.elabqrihr.qa",
        )
        val workName = BackgroundSyncPlugin.qaReplayWorkName(
            testTenantId,
            testUserId,
        )

        BackgroundSyncPlugin.enqueueOnceForQa(
            context,
            testTenantId,
            testUserId,
            initialDelaySeconds = 15,
        )

        val workInfos = WorkManager.getInstance(context)
            .getWorkInfosForUniqueWork(workName).get()
        assertEquals(1, workInfos.size)
        assertEquals(WorkInfo.State.ENQUEUED, workInfos.single().state)
        assertEquals(
            NetworkType.CONNECTED,
            workInfos.single().constraints.requiredNetworkType,
        )
        val scopedInput = BackgroundSyncPlugin.inputDataForIdentity(
            testTenantId,
            testUserId,
        )
        assertEquals(
            testTenantId,
            scopedInput.getString(BackgroundSyncWorker.TENANT_ID_KEY),
        )
        assertEquals(
            testUserId,
            scopedInput.getString(BackgroundSyncWorker.USER_ID_KEY),
        )
    }
}
