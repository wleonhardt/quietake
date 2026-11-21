package cam.quietake.app

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager

/**
 * Chooses a tile label that follows the plain launcher entry (decision 029): while
 * the plain entry is enabled, the tiles drop the app name. The system still shows
 * the manifest label in the tile picker, which an app cannot change at run time.
 */
object TileLabel {
    fun plainEntryOn(context: Context): Boolean =
        context.packageManager.getComponentEnabledSetting(
            ComponentName(context, "cam.quietake.app.NeutralAlias")
        ) == PackageManager.COMPONENT_ENABLED_STATE_ENABLED

    fun pick(context: Context, normal: Int, plain: Int): String =
        context.getString(if (plainEntryOn(context)) plain else normal)
}
