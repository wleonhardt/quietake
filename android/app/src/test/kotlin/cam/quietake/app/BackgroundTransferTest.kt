package cam.quietake.app

import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.RecordedRequest
import okhttp3.mockwebserver.SocketPolicy
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.ExecutionException
import java.util.concurrent.TimeUnit

class BackgroundTransferTest {
    private fun takeTransferRequest(server: MockWebServer): RecordedRequest {
        var request = server.takeRequest()
        while (request.method == "HEAD") request = server.takeRequest()
        return request
    }

    private fun fixture(cancelled: () -> Boolean = { false }, committed: (String) -> Unit = {},
                        removed: MutableSet<String> = linkedSetOf(), rememberRemoved: (Set<String>) -> Unit = {},
                        test: (File, MockWebServer, BackgroundTransfer) -> Unit) {
        val root = Files.createTempDirectory("background-test").toFile()
        val server = MockWebServer()
        server.start()
        val vault = File(root, "vault").apply { mkdir() }
        val keyfile = File(root, "vault.keyfile.json").apply { writeText("wrapped fixture") }
        File(vault, "quietake.catalog").writeText("encrypted catalog")
        val transfer = BackgroundTransfer(
            vault, keyfile, server.url("/vault/"), "fixture", "synthetic",
            BackgroundTransfer.digest(keyfile),
            BackgroundTransfer.digest(File(vault, "quietake.catalog")),
            File(root, "owned"), cancelled, committed,
            removed = removed, rememberRemoved = rememberRemoved,
        )
        try { test(vault, server, transfer) }
        finally { server.shutdown(); root.deleteRecursively() }
    }

    @Test fun legacyMetadataBlocksBackgroundWrites() = fixture { vault, server, transfer ->
        File(vault, ".deletions").mkdir()
        File(vault, ".deletions/one.del").writeText("")
        val writes = mutableListOf<String>()
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                if (request.method !in listOf("GET", "HEAD")) writes.add(request.method!!)
                return MockResponse().setBody(if (request.method == "GET") "encrypted catalog" else "")
            }
        }
        assertThrows(BackgroundConflict::class.java) { transfer.run() }
        assertTrue(writes.isEmpty())
    }

    @Test fun wrongOwnershipNeverWrites() = fixture { vault, server, transfer ->
        File(vault, "one.shtr").writeText("encrypted capture")
        server.enqueue(MockResponse().setBody("foreign catalog"))
        assertThrows(BackgroundConflict::class.java) { transfer.run() }
        assertEquals(1, server.requestCount)
        assertEquals("GET", takeTransferRequest(server).method)
    }

    @Test fun missingCaptureUsesStagingAndNoOverwriteMove() = fixture { vault, server, transfer ->
        val bytes = "encrypted capture"
        File(vault, "one.shtr").writeText(bytes)
        server.enqueue(MockResponse().setBody("encrypted catalog"))
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy catalog.
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy recovery envelope.
        server.enqueue(MockResponse().setResponseCode(404))
        server.enqueue(MockResponse().setResponseCode(201))
        server.enqueue(MockResponse().setResponseCode(201))
        // Catalog already matches, so it is not replaced.
        assertEquals(1, transfer.run())
        takeTransferRequest(server)
        assertEquals("GET", takeTransferRequest(server).method)
        val put = takeTransferRequest(server)
        assertEquals("PUT", put.method)
        assertTrue(put.path!!.contains(".quietake-upload-"))
        assertEquals(bytes, put.body.readUtf8())
        val move = takeTransferRequest(server)
        assertEquals("MOVE", move.method)
        assertEquals("F", move.getHeader("Overwrite"))
        assertTrue(move.getHeader("Destination")!!.endsWith("/vault/one.shtr"))
        assertEquals(bytes, File(vault, "one.shtr").readText())
    }

    @Test fun moveFailureOtherThanPreconditionIsRetried() = fixture { vault, server, transfer ->
        File(vault, "one.shtr").writeText("encrypted capture")
        server.enqueue(MockResponse().setBody("encrypted catalog"))
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy catalog.
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy recovery envelope.
        server.enqueue(MockResponse().setResponseCode(404))
        server.enqueue(MockResponse().setResponseCode(201))
        server.enqueue(MockResponse().setResponseCode(423)) // Recovery lease held: not a conflict.
        server.enqueue(MockResponse().setResponseCode(204)) // Remove only owned staging.
        val error = assertThrows(IOException::class.java) { transfer.run() }
        assertFalse(error is BackgroundConflict)
        assertEquals("encrypted capture", File(vault, "one.shtr").readText())
    }

    @Test fun removedReceiptStopsRepeatedDeletes() {
        val receipts = mutableListOf<Set<String>>()
        fixture(rememberRemoved = { receipts.add(it.toSet()) }) { vault, server, transfer ->
            File(vault, ".deletions").mkdir()
            File(vault, ".deletions/one.del").writeText("")
            server.enqueue(MockResponse().setBody("encrypted catalog"))
            server.enqueue(MockResponse().setResponseCode(404)) // No legacy catalog.
            server.enqueue(MockResponse().setResponseCode(404)) // No legacy recovery envelope.
            server.enqueue(MockResponse().setResponseCode(204))
            assertEquals(0, transfer.run())
            assertEquals(4, server.requestCount)
            assertEquals(listOf(setOf("one.shtr")), receipts)
        }
        fixture(removed = mutableSetOf("one.shtr")) { vault, server, transfer ->
            File(vault, ".deletions").mkdir()
            File(vault, ".deletions/one.del").writeText("")
            server.enqueue(MockResponse().setBody("encrypted catalog"))
            server.enqueue(MockResponse().setResponseCode(404))
            server.enqueue(MockResponse().setResponseCode(404))
            assertEquals(0, transfer.run())
            assertEquals(3, server.requestCount) // The marker is kept; no DELETE repeats.
            assertTrue(File(vault, ".deletions/one.del").exists())
        }
    }

    @Test fun deletionMarkerNamesAreValidatedBeforeAnyRequest() = fixture { vault, server, transfer ->
        File(vault, ".deletions").mkdir()
        File(vault, ".deletions/...del").writeText("") // would address ".." on the NAS
        server.enqueue(MockResponse().setBody("encrypted catalog"))
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy catalog.
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy recovery envelope.
        assertEquals(0, transfer.run())
        assertEquals(3, server.requestCount)
        assertFalse(BackgroundTransfer.validName(".."))
        assertTrue(BackgroundTransfer.validName("2026-01-01T00-00-00.000Z.jpg"))
    }

    @Test fun sameNameConflictPreservesBothCopies() = fixture { vault, server, transfer ->
        File(vault, "one.shtr").writeText("local ciphertext")
        server.enqueue(MockResponse().setBody("encrypted catalog"))
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy catalog.
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy recovery envelope.
        server.enqueue(MockResponse().setBody("other ciphertext"))
        assertThrows(BackgroundConflict::class.java) { transfer.run() }
        assertEquals(4, server.requestCount)
        assertEquals("local ciphertext", File(vault, "one.shtr").readText())
    }

    @Test fun changedKeyfileBlocksBeforeNetwork() = fixture { vault, server, transfer ->
        File(vault.parentFile, "vault.keyfile.json").writeText("new identity")
        assertThrows(BackgroundConflict::class.java) { transfer.run() }
        assertEquals(0, server.requestCount)
    }

    @Test fun ignoresRecoveryFilesPartialsAndDirectories() = fixture { vault, server, transfer ->
        File(vault, "one.shtr.part").writeText("partial")
        File(vault, "quietake.recovery.json").writeText("encrypted recovery envelope")
        File(vault, ".recovery-uploads.json").writeText("owned staging record")
        File(vault, ".quietake-recovery-fixture").writeText("encrypted staged envelope")
        File(vault, "directory.shtr").mkdir()
        server.enqueue(MockResponse().setBody("encrypted catalog"))
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy catalog.
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy recovery envelope.
        assertEquals(0, transfer.run())
        assertEquals(3, server.requestCount)
    }

    @Test fun localJournalIsOnlyDeletionAuthority() = fixture { vault, server, transfer ->
        File(vault, ".deletions").mkdir()
        File(vault, ".deletions/one.del").writeText("")
        server.enqueue(MockResponse().setBody("encrypted catalog"))
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy catalog.
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy recovery envelope.
        server.enqueue(MockResponse().setResponseCode(204))
        assertEquals(0, transfer.run())
        takeTransferRequest(server)
        val deletion = takeTransferRequest(server)
        assertEquals("DELETE", deletion.method)
        assertTrue(deletion.path!!.endsWith("/one.shtr"))
        assertTrue(File(vault, ".deletions/one.del").exists())
    }

    @Test fun missingCatalogCannotEstablishOwnership() = fixture { _, server, transfer ->
        server.enqueue(MockResponse().setResponseCode(404))
        assertThrows(BackgroundConflict::class.java) { transfer.run() }
        assertEquals(1, server.requestCount)
    }

    @Test fun redirectsNeverForwardCredentialsOrWrite() = fixture { _, server, transfer ->
        server.enqueue(MockResponse().setResponseCode(302).setHeader("Location", "/untrusted/"))
        assertThrows(java.io.IOException::class.java) { transfer.run() }
        assertEquals(1, server.requestCount)
    }

    @Test fun stoppedWorkDoesNotContactNas() = fixture(cancelled = { true }) { _, server, transfer ->
        assertThrows(java.io.IOException::class.java) { transfer.run() }
        assertEquals(0, server.requestCount)
    }

    @Test fun foregroundCancellationBetweenRequestsPersists() = fixture { _, server, transfer ->
        server.enqueue(MockResponse().setBody("encrypted catalog"))
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy catalog.
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy recovery envelope.
        transfer.cancel()
        assertThrows(java.io.IOException::class.java) { transfer.run() }
        assertEquals(0, server.requestCount)
    }

    @Test fun symlinkCaptureIsNeverUploaded() = fixture { vault, server, transfer ->
        val outside = File(vault.parentFile, "unrelated").apply { writeText("private unrelated file") }
        Files.createSymbolicLink(File(vault, "link.shtr").toPath(), outside.toPath())
        server.enqueue(MockResponse().setBody("encrypted catalog"))
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy catalog.
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy recovery envelope.
        assertEquals(0, transfer.run())
        assertEquals(3, server.requestCount)
        assertEquals("private unrelated file", outside.readText())
    }

    @Test fun catalogReplacementRequiresDestinationEtag() = fixture { vault, server, transfer ->
        File(vault, "quietake.catalog").writeText("new encrypted catalog")
        server.enqueue(MockResponse().setBody("encrypted catalog").setHeader("ETag", "\"old\""))
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy catalog.
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy recovery envelope.
        server.enqueue(MockResponse().setResponseCode(201))
        server.enqueue(MockResponse().setResponseCode(204))
        assertEquals(0, transfer.run())
        takeTransferRequest(server); takeTransferRequest(server)
        val move = takeTransferRequest(server)
        assertEquals("MOVE", move.method)
        assertEquals("T", move.getHeader("Overwrite"))
        assertTrue(move.getHeader("If")!!.contains("([\"old\"])"))
    }

    @Test fun changedDestinationPreservesCatalogAndRetriesFromForeground() = fixture { vault, server, transfer ->
        File(vault, "quietake.catalog").writeText("new encrypted catalog")
        server.enqueue(MockResponse().setBody("encrypted catalog").setHeader("ETag", "\"old\""))
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy catalog.
        server.enqueue(MockResponse().setResponseCode(404)) // No legacy recovery envelope.
        server.enqueue(MockResponse().setResponseCode(201))
        server.enqueue(MockResponse().setResponseCode(412))
        server.enqueue(MockResponse().setResponseCode(204)) // Remove only owned staging.
        assertThrows(BackgroundConflict::class.java) { transfer.run() }
        assertEquals("new encrypted catalog", File(vault, "quietake.catalog").readText())
        assertEquals(6, server.requestCount)
    }

    @Test fun deletionArrivingDuringPutNeverFinalizesCapture() = fixture { vault, server, transfer ->
        File(vault, "one.shtr").writeText("encrypted capture")
        val methods = mutableListOf<String>()
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                methods.add(request.method!!)
                return when (request.method) {
                    "HEAD" -> MockResponse().setResponseCode(404)
                    "GET" -> if (request.path!!.endsWith("catalog")) MockResponse().setBody("encrypted catalog")
                             else MockResponse().setResponseCode(404)
                    "PUT" -> {
                        File(vault, ".deletions").mkdir()
                        File(vault, ".deletions/one.del").writeText("")
                        MockResponse().setResponseCode(201)
                    }
                    else -> MockResponse().setResponseCode(204)
                }
            }
        }
        assertEquals(0, transfer.run())
        assertFalse(methods.contains("MOVE"))
        assertTrue(methods.contains("DELETE"))
        assertEquals("encrypted capture", File(vault, "one.shtr").readText())
    }

    @Test fun identityChangedDuringPutBlocksMove() = fixture { vault, server, transfer ->
        File(vault, "one.shtr").writeText("encrypted capture")
        val methods = mutableListOf<String>()
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                methods.add(request.method!!)
                return when (request.method) {
                    "HEAD" -> MockResponse().setResponseCode(404)
                    "GET" -> if (request.path!!.endsWith("catalog")) MockResponse().setBody("encrypted catalog")
                             else MockResponse().setResponseCode(404)
                    "PUT" -> {
                        File(vault.parentFile, "vault.keyfile.json").writeText("new identity")
                        MockResponse().setResponseCode(201)
                    }
                    else -> MockResponse().setResponseCode(204)
                }
            }
        }
        assertThrows(BackgroundConflict::class.java) { transfer.run() }
        assertFalse(methods.contains("MOVE"))
        assertEquals("encrypted capture", File(vault, "one.shtr").readText())
    }

    @Test fun activeHttpCancellationPreservesOriginalAndOwnedRetryRecord() = fixture { vault, server, transfer ->
        File(vault, "one.shtr").writeText("encrypted capture")
        val entered = CountDownLatch(1)
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse = when (request.method) {
                    "HEAD" -> MockResponse().setResponseCode(404)
                "GET" -> if (request.path!!.endsWith("catalog")) MockResponse().setBody("encrypted catalog")
                         else MockResponse().setResponseCode(404)
                else -> {
                    entered.countDown()
                    MockResponse().setSocketPolicy(SocketPolicy.NO_RESPONSE)
                }
            }
        }
        val executor = Executors.newSingleThreadExecutor()
        try {
            val result = executor.submit<Int> { transfer.run() }
            assertTrue(entered.await(3, TimeUnit.SECONDS))
            transfer.cancel()
            val failure = assertThrows(ExecutionException::class.java) { result.get(3, TimeUnit.SECONDS) }
            assertTrue(failure.cause is java.io.IOException)
            assertEquals("encrypted capture", File(vault, "one.shtr").readText())
            assertTrue(File(vault.parentFile, "owned").readText().startsWith(".quietake-upload-"))
        } finally { transfer.cancel(); executor.shutdownNow() }
    }

    @Test fun captureArrivingAfterEnumerationIsUploadedOnNextPass() = fixture { vault, server, transfer ->
        File(vault, "first.shtr").writeText("first encrypted capture")
        val remote = mutableMapOf("quietake.catalog" to "encrypted catalog".toByteArray())
        val requests = mutableListOf<String>()
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                val name = request.requestUrl!!.pathSegments.last()
                requests.add("${request.method}:$name")
                return when (request.method) {
                    "HEAD" -> MockResponse().setResponseCode(404)
                    "GET" -> remote[name]?.let { MockResponse().setBody(okio.Buffer().write(it)) }
                             ?: MockResponse().setResponseCode(404)
                    "PUT" -> {
                        remote[name] = request.body.readByteArray()
                        File(vault, "second.shtr").writeText("late encrypted capture")
                        MockResponse().setResponseCode(201)
                    }
                    "MOVE" -> {
                        val destination = request.getHeader("Destination")!!.substringAfterLast('/')
                        remote[destination] = remote.remove(name)!!
                        MockResponse().setResponseCode(201)
                    }
                    else -> MockResponse().setResponseCode(204)
                }
            }
        }
        assertEquals(1, transfer.run())
        assertFalse(remote.containsKey("second.shtr"))
        requests.clear()
        assertEquals(1, transfer.run())
        assertFalse("Confirmed transfers must not starve new captures with repeated video downloads",
            requests.contains("GET:first.shtr"))
        assertEquals("late encrypted capture", String(remote["second.shtr"]!!))
        assertEquals("first encrypted capture", String(remote["first.shtr"]!!))
    }
}
