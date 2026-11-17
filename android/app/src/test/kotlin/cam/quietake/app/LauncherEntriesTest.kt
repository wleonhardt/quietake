package cam.quietake.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory

class LauncherEntriesTest {
    private val android = "http://schemas.android.com/apk/res/android"

    @Test
    fun switchingNeverTouchesTheActivityItself() {
        for (neutral in listOf(true, false)) {
            val (enable, disable) = LauncherEntries.switchTo(neutral)
            assertFalse(enable.endsWith(".MainActivity"))
            assertFalse(disable.endsWith(".MainActivity"))
        }
        assertEquals(LauncherEntries.NEUTRAL to LauncherEntries.NORMAL, LauncherEntries.switchTo(true))
        assertEquals(LauncherEntries.NORMAL to LauncherEntries.NEUTRAL, LauncherEntries.switchTo(false))
    }

    /** Tiles and "Open with" start MainActivity, so only aliases may carry the launcher filter. */
    @Test
    fun onlyTheTwoAliasesAreLauncherEntries() {
        val manifest = sequenceOf("src/main/AndroidManifest.xml", "app/src/main/AndroidManifest.xml")
            .map(::File).first { it.exists() }
        val document = DocumentBuilderFactory.newInstance().apply { isNamespaceAware = true }
            .newDocumentBuilder().parse(manifest)
        val launchers = mutableMapOf<String, String>()
        for (tag in listOf("activity", "activity-alias")) {
            val nodes = document.getElementsByTagName(tag)
            for (i in 0 until nodes.length) {
                val element = nodes.item(i) as org.w3c.dom.Element
                val categories = element.getElementsByTagName("category")
                val launcher = (0 until categories.length).any {
                    (categories.item(it) as org.w3c.dom.Element)
                        .getAttributeNS(android, "name") == "android.intent.category.LAUNCHER"
                }
                if (launcher) {
                    launchers["cam.quietake.app" + element.getAttributeNS(android, "name")] =
                        tag + ":" + element.getAttributeNS(android, "enabled")
                }
            }
        }
        assertEquals(
            mapOf(
                LauncherEntries.NORMAL to "activity-alias:",
                LauncherEntries.NEUTRAL to "activity-alias:false",
            ),
            launchers,
        )
    }
}
