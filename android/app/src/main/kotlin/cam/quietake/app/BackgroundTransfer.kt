package cam.quietake.app

import okhttp3.Call
import okhttp3.Credentials
import okhttp3.HttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.Response
import okio.BufferedSink
import java.io.File
import java.io.IOException
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.TimeUnit

class BackgroundConflict : IOException("Foreground backup reconciliation required")

/** Ciphertext only. The caller owns the process gate and encrypted configuration. */
class BackgroundTransfer(
    private val vault: File,
    private val keyfile: File,
    private val base: HttpUrl,
    username: String,
    password: String,
    private val identity: String,
    private var ownership: String,
    private val owned: File,
    private val cancelled: () -> Boolean,
    private val committed: (String) -> Unit,
    private val confirmed: MutableSet<String> = linkedSetOf(),
    private val remember: (Set<String>) -> Unit = {},
    private val removed: MutableSet<String> = linkedSetOf(),
    private val rememberRemoved: (Set<String>) -> Unit = {},
) {
    private val auth = Credentials.basic(username, password, Charsets.UTF_8)
    private val client = OkHttpClient.Builder()
        .followRedirects(false).followSslRedirects(false)
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS).writeTimeout(30, TimeUnit.SECONDS)
        .build()
    private val deadline = System.nanoTime() + TimeUnit.MINUTES.toNanos(8)
    @Volatile private var active: Call? = null
    @Volatile private var interrupted = false
    private val catalog get() = File(vault, "quietake.catalog")
    private var etag: String? = null

    companion object {
        fun digest(file: File, check: () -> Unit = {}): String = file.inputStream().use { input ->
            val hash = MessageDigest.getInstance("SHA-256")
            val buffer = ByteArray(65536)
            while (true) {
                check()
                val count = input.read(buffer)
                if (count < 0) break
                hash.update(buffer, 0, count)
            }
            hash.digest().joinToString("") { "%02x".format(it) }
        }
        fun signature(vault: File): String {
            val hash = MessageDigest.getInstance("SHA-256")
            val files = vault.listFiles()?.filter {
                regular(it) &&
                    (it.name.endsWith(".shtr") || it.name == "quietake.catalog")
            }.orEmpty() + File(vault, ".deletions").listFiles()?.filter {
                regular(it) && it.name.endsWith(".del")
            }.orEmpty()
            for (file in files.sortedBy { it.path }) {
                hash.update("${file.name}\u0000${file.length()}\u0000${file.lastModified()}\n".toByteArray(Charsets.UTF_8))
            }
            return hash.digest().joinToString("") { "%02x".format(it) }
        }
        private val temporary = Regex("\\.quietake-upload-[0-9a-f-]{36}")
        /** Same rule as Dart checkedFileName: one path segment, nothing else. */
        fun validName(name: String): Boolean =
            name.isNotEmpty() && name != "." && name != ".." &&
                name.none { it == '/' || it == '\\' || it == '\u0000' }
        private fun regular(file: File): Boolean = file.isFile &&
            file.canonicalFile == File(file.parentFile!!.canonicalFile, file.name)
    }

    fun cancel() { interrupted = true; active?.cancel() }

    private fun check() {
        if (interrupted || cancelled() || System.nanoTime() >= deadline) throw IOException("Background backup paused")
    }

    private fun checkIdentity() {
        check()
        if (!keyfile.isFile || digest(keyfile) != identity) throw BackgroundConflict()
    }

    private fun url(name: String) = base.newBuilder().addPathSegment(name).build()
    private fun deleted(name: String) =
        regular(File(vault, ".deletions/${name.removeSuffix(".shtr")}.del"))

    private fun request(method: String, name: String, body: RequestBody? = null,
                        headers: Map<String, String> = emptyMap()): Response {
        checkIdentity()
        val builder = Request.Builder().url(url(name)).header("Authorization", auth).method(method, body)
        headers.forEach { (name, value) -> builder.header(name, value) }
        val call = client.newCall(builder.build())
        active = call
        call.timeout().timeout(maxOf(1L, deadline - System.nanoTime()), TimeUnit.NANOSECONDS)
        if (interrupted || cancelled()) call.cancel()
        return call.execute()
    }

    private fun remoteDigest(name: String, limit: Long): String? = request("GET", name).use { response ->
        if (response.code == 404) return null
        if (!response.isSuccessful) throw IOException("NAS read unavailable")
        if (name == "quietake.catalog") etag = response.header("ETag")
        val hash = MessageDigest.getInstance("SHA-256")
        var total = 0L
        response.body.byteStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) {
                check()
                val count = input.read(buffer)
                if (count < 0) break
                total += count
                if (total > limit) throw BackgroundConflict()
                hash.update(buffer, 0, count)
            }
        }
        hash.digest().joinToString("") { "%02x".format(it) }
    }

    private fun remove(name: String) {
        request("DELETE", name).use {
            if (!it.isSuccessful && it.code != 404) throw IOException("NAS removal pending")
        }
    }

    private fun ownedNames(): MutableSet<String> =
        if (!owned.exists()) mutableSetOf()
        else owned.readLines().onEach { require(temporary.matches(it)) }.toMutableSet()

    private fun saveOwned(names: Set<String>) {
        owned.parentFile!!.mkdirs()
        val pending = File(owned.path + ".pending")
        pending.outputStream().use { it.write(names.joinToString("\n").toByteArray()); it.fd.sync() }
        check(pending.renameTo(owned))
    }

    private fun upload(name: String, file: File, catalogEtag: String? = null): Boolean {
        val names = ownedNames()
        val stage = ".quietake-upload-${UUID.randomUUID()}"
        names.add(stage)
        saveOwned(names) // Record ownership before exposing even encrypted partial bytes.
        try {
            val body = object : RequestBody() {
                override fun contentType() = "application/octet-stream".toMediaType()
                override fun contentLength() = file.length()
                override fun writeTo(sink: BufferedSink) {
                    file.inputStream().use { input ->
                        val bytes = ByteArray(65536)
                        while (true) {
                            check()
                            val count = input.read(bytes)
                            if (count < 0) break
                            sink.write(bytes, 0, count)
                        }
                    }
                }
            }
            request("PUT", stage, body).use {
                if (!it.isSuccessful) throw IOException("NAS upload pending")
            }
            if (name.endsWith(".shtr") && deleted(name)) return false
            val headers = mutableMapOf("Destination" to url(name).toString(),
                "Overwrite" to if (catalogEtag == null) "F" else "T")
            if (catalogEtag != null) headers["If"] = "<${url(name)}> ([$catalogEtag])"
            request("MOVE", stage, headers = headers).use {
                // Only a failed precondition means the NAS changed under us; a 423
                // recovery lease or a 5xx is retried like any other transport fault.
                if (it.code == 412 || it.code == 409) throw BackgroundConflict()
                if (!it.isSuccessful) throw IOException("NAS move pending")
            }
            names.remove(stage)
            saveOwned(names)
            return true
        } finally {
            // A stopped/failed job retains its owned name for the next safe pass.
            if (stage in names && !cancelled()) {
                try { remove(stage); names.remove(stage); saveOwned(names) }
                catch (_: IOException) { }
            }
        }
    }

    fun run(): Int {
        try {
            checkIdentity()
            if (!regular(catalog) || catalog.length() > 4 * 1024 * 1024) throw BackgroundConflict()
            val localHash = digest(catalog, ::check)
            val remoteHash = remoteDigest("quietake.catalog", 4 * 1024 * 1024)
            if (remoteHash == null || remoteHash != ownership && remoteHash != localHash) throw BackgroundConflict()
            // A legacy collection is a read-only migration source, even if a
            // matching new catalog was copied into it after foreground setup.
            for (legacy in listOf("tucklight.catalog", "tucklight.recovery.json")) {
                request("HEAD", legacy).use { response ->
                    if (response.isSuccessful) throw BackgroundConflict()
                    if (response.code != 404) throw IOException("Could not exclude legacy backup metadata")
                }
            }
            for (name in ownedNames().toList()) {
                remove(name)
                val names = ownedNames(); names.remove(name); saveOwned(names)
            }
            var uploaded = 0
            val files = vault.listFiles()?.filter { regular(it) && it.name.endsWith(".shtr") }
                ?: throw IOException("Vault unavailable")
            for (file in files.sortedByDescending { it.lastModified() }) {
                check()
                if (deleted(file.name)) continue
                if (file.name in confirmed) continue
                val hash = remoteDigest(file.name, file.length())
                if (hash != null && hash != digest(file, ::check)) throw BackgroundConflict()
                if (hash == null && upload(file.name, file)) uploaded++
                if (deleted(file.name)) remove(file.name)
                else {
                    confirmed.add(file.name)
                    if (confirmed.size > 100000) confirmed.remove(confirmed.first())
                    remember(confirmed)
                }
            }
            // Decision 012 keeps the markers; a receipt per removed name stops the
            // DELETE from being repeated on every later pass.
            File(vault, ".deletions").listFiles()?.filter { regular(it) && it.name.endsWith(".del") }
                ?.map { it.name.removeSuffix(".del") }?.filter(::validName)
                ?.map { "$it.shtr" }?.filter { it !in removed }
                ?.forEach {
                    remove(it)
                    removed.add(it)
                    if (removed.size > 100000) removed.remove(removed.first())
                    rememberRemoved(removed)
                }
            // Catalog uses atomic local replacement; copy late to avoid mixed revisions.
            val snapshot = File(owned.parentFile, "catalog.snapshot")
            try {
                catalog.copyTo(snapshot, overwrite = true)
                if (snapshot.length() > 4 * 1024 * 1024) throw BackgroundConflict()
                val hash = digest(snapshot, ::check)
                if (hash != remoteHash) {
                    // Destination ETag makes a concurrent remote change fail closed.
                    val tag = etag?.takeIf { it.startsWith('"') && it.endsWith('"') }
                        ?: throw BackgroundConflict()
                    upload("quietake.catalog", snapshot, tag)
                }
                checkIdentity()
                ownership = hash
                committed(hash)
            } finally { snapshot.delete() }
            return uploaded
        } finally {
            active = null
            client.dispatcher.cancelAll()
            client.connectionPool.evictAll()
        }
    }
}
