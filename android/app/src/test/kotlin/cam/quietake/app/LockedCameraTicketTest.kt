package cam.quietake.app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LockedCameraTicketTest {
    @Test
    fun aTicketWorksOnceAndOnlyForItsHolder() {
        assertFalse("nothing issued yet", LockedCameraTicket.redeem("guess"))
        assertFalse(LockedCameraTicket.redeem(null))
        val ticket = LockedCameraTicket.issue()
        assertFalse("a wrong value also spends the ticket", LockedCameraTicket.redeem("guess"))
        assertFalse(LockedCameraTicket.redeem(ticket))
        val second = LockedCameraTicket.issue()
        assertNotEquals(ticket, second)
        assertTrue(LockedCameraTicket.redeem(second))
        assertFalse("used once", LockedCameraTicket.redeem(second))
    }
}
