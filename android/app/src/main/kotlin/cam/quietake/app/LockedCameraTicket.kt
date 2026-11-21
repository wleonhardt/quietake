package cam.quietake.app

import java.util.UUID

/**
 * Proof that the camera tile, not another app, asked for the camera over the
 * phone's lock screen (decision 028). The activity is exported for "Open
 * with", so its action alone proves nothing. The tile and the activity share
 * one process; a ticket lives in memory, works once, and any attempt spends it.
 */
object LockedCameraTicket {
    const val EXTRA = "cam.quietake.app.LOCKED_CAMERA_TICKET"
    private var ticket: String? = null

    @Synchronized
    fun issue(): String = UUID.randomUUID().toString().also { ticket = it }

    @Synchronized
    fun redeem(candidate: String?): Boolean {
        val valid = candidate != null && candidate == ticket
        ticket = null
        return valid
    }
}
