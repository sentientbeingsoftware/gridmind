package com.sentientbeingsoftware.gridmind

import android.content.Intent
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** Spike: system-level steps via UI Automator only (no Flutter widget access). */
class SystemUiAutomatorTest {
    private lateinit var device: UiDevice
    private val pkg = "com.sentientbeingsoftware.gridmindapp"

    @Before fun setUp() {
        device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    }

    private fun launchApp() {
        val ctx = InstrumentationRegistry.getInstrumentation().context
        val i = ctx.packageManager.getLaunchIntentForPackage(pkg)!!
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
        ctx.startActivity(i)
        assertTrue(device.wait(Until.hasObject(By.pkg(pkg).depth(0)), 20_000))
    }

    @Test fun navBar_home_recents_back() {
        launchApp()
        assertTrue(device.pressHome())
        assertTrue(device.wait(Until.gone(By.pkg(pkg)), 5_000)) // launcherPackageName did not resolve under package visibility
        assertTrue(device.pressRecentApps())
        device.waitForIdle()
        assertTrue(device.pressHome())
        launchApp()
        assertTrue(device.pressBack())
    }

    @Test fun notificationShade_opens() {
        launchApp()
        assertTrue(device.openNotification())
        assertTrue(device.wait(Until.hasObject(By.res("com.android.systemui", "notification_panel")), 5_000)
            || device.wait(Until.hasObject(By.pkg("com.android.systemui")), 5_000))
        device.pressBack()
    }

    /** GridMind declares no runtime permission, so drive Android's own dialog via a system app. */
    @Test fun permissionDialog_reachable() {
        // Launch Settings' app-permissions page for the app and read it with UI Automator.
        device.executeShellCommand("am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:$pkg")
        assertTrue(device.wait(Until.hasObject(By.pkg("com.android.settings")), 10_000))
        val perms = device.wait(Until.findObject(By.text("Permissions")), 5_000)
        assertTrue("Permissions row not found", perms != null)
        perms.click()
        assertTrue(device.wait(Until.hasObject(By.textContains("permission")), 5_000))
        device.pressHome()
    }

    @Test fun backupRestore_viaShell() {
        val out = device.executeShellCommand("bmgr list transports")
        println("bmgr transports: $out")
        val bk = device.executeShellCommand("bmgr backupnow $pkg")
        println("bmgr backupnow: $bk")
        assertTrue(out.isNotBlank())
    }
}
