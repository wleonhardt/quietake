package cam.quietake.app

import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import io.flutter.plugin.common.MethodChannel

/** Reaches the running activity's privacy channel; empty while no activity exists. */
object LockBridge {
    @Volatile var channel: MethodChannel? = null
}

/**
 * Quick Settings tile that locks the running app at once. It holds no secret and
 * shows no vault state. With no running app there is nothing unlocked to lock.
 */
class LockTileService : TileService() {
    override fun onStartListening() {
        qsTile?.let {
            it.state = Tile.STATE_INACTIVE
            it.updateTile()
        }
    }

    override fun onClick() {
        LockBridge.channel?.invokeMethod("lockNow", null)
    }
}
