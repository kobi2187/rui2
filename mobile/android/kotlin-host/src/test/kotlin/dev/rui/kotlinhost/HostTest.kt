package dev.rui.kotlinhost

import android.content.ComponentName
import android.content.pm.PackageManager
import android.view.View
import android.widget.Button
import androidx.test.core.app.ApplicationProvider
import dev.rui.android.RuiActivity
import dev.rui.android.RuiScreens
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

/**
 * The Kotlin side of the integration, on the JVM: what the host shows, the
 * Intent a tap sends, and how RuiActivity is declared. What happens inside
 * libmain.so is not here (Robolectric runs no native code): that is checked on
 * the host by mobile/compare/ and, on a device, by mobile/android/device_check.sh.
 */
@RunWith(RobolectricTestRunner::class)
class HostTest {
    private val context get() = ApplicationProvider.getApplicationContext<android.app.Application>()

    @Test fun screensComeFromThePackagedList() {
        val screens = RuiScreens.list(context)
        assertTrue("build_rui.sh writes assets/rui_screens.txt", screens.isNotEmpty())
        assertEquals("01_hello", screens.first())
    }

    @Test fun tappingAScreenStartsRuiActivityWithIt() {
        val activity = Robolectric.buildActivity(MainActivity::class.java).setup().get()
        val button = activity.window.decorView.findViewWithTag<View>("02_counter") as Button
        button.performClick()
        val started = shadowOf(activity).nextStartedActivity
        assertEquals(RuiActivity::class.java.name, started.component!!.className)
        assertEquals("02_counter", started.getStringExtra(RuiActivity.EXTRA_SCREEN))
    }

    @Test fun everyScreenHasAButton() {
        val activity = Robolectric.buildActivity(MainActivity::class.java).setup().get()
        for (s in RuiScreens.list(context)) {
            assertTrue("button for $s", activity.window.decorView.findViewWithTag<View>(s) is Button)
        }
    }

    @Test fun ruiActivityRunsLibmain() {
        val info = context.packageManager.getActivityInfo(
            ComponentName(context, RuiActivity::class.java), PackageManager.GET_META_DATA)
        assertEquals("main", info.metaData.getString("android.app.lib_name"))
    }

    @Test fun intentCarriesTheme() {
        val i = RuiActivity.intent(context, "03_login", "daylight")
        assertEquals("03_login", i.getStringExtra(RuiActivity.EXTRA_SCREEN))
        assertEquals("daylight", i.getStringExtra(RuiActivity.EXTRA_THEME))
    }
}
