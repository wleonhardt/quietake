package cam.quietake.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.work.*
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import okhttp3.HttpUrl.Companion.toHttpUrl
import org.json.JSONObject
import org.json.JSONArray
import java.io.File
import java.security.KeyStore
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Shared by the Activity and WorkManager in the default application process. */
object BackgroundGate {
    val semaphore = Semaphore(1, true)
    @Volatile var transfer: BackgroundTransfer? = null
    @Volatile var lease: String? = null
    val waiting = AtomicInteger(0)
    @Synchronized fun release(token: String?) {
        if (token != null && lease == token) {
            lease = null
            semaphore.release()
        }
    }
}

/** Only ciphertext configuration is stored; WorkManager inputs are empty. */
class BackgroundConfig(private val context: Context) {
    val directory = File(context.noBackupFilesDir, "background-backup").apply { mkdirs() }
    private val file = File(directory, "connection.enc")
    private val alias = "quietake.background.credentials.v1"
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
            generateKey()
        }
    }
    fun read(source: File = file, limit: Int = 65536): JSONObject? {
        if (!source.exists()) return null
        require(source.length() in 29..limit)
        val bytes = source.readBytes()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
        return JSONObject(String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8))
    }
    fun write(config: JSONObject, target: File = file, limit: Int = 65536) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val pending = if (target == file) File(directory, "connection.pending") else File(target.path + ".pending")
        val encrypted = cipher.iv + cipher.doFinal(config.toString().toByteArray(Charsets.UTF_8))
        require(encrypted.size <= limit)
        pending.outputStream().use { it.write(encrypted); it.fd.sync() }
        check(pending.renameTo(target))
    }
    fun receipts(generation: String): MutableSet<String> {
        val values = read(File(directory, "receipts-$generation.enc"), 32 * 1024 * 1024)
            ?.getJSONArray("names") ?: return linkedSetOf()
        require(values.length() <= 100000)
        return (0 until values.length()).map { values.getString(it) }.toCollection(linkedSetOf())
    }
    fun receipts(generation: String, names: Set<String>) = write(
        JSONObject().put("names", JSONArray(names)), File(directory, "receipts-$generation.enc"), 32 * 1024 * 1024)
    fun clear() {
        if (file.exists()) check(file.delete())
        val pending = File(directory, "connection.pending")
        if (pending.exists()) check(pending.delete())
        directory.listFiles()?.filter { it.name.startsWith("receipts-") }?.forEach { check(it.delete()) }
    }
    fun status(value: String) {
        context.getSharedPreferences("background-backup-status", Context.MODE_PRIVATE)
            .edit().putString("state", value).putLong("time", System.currentTimeMillis()).apply()
    }
}

class BackgroundUploadWorker(context: Context, parameters: WorkerParameters) : Worker(context, parameters) {
    @Volatile private var runningTransfer: BackgroundTransfer? = null
    override fun onStopped() { runningTransfer?.cancel() }
    override fun doWork(): Result {
        if (!BackgroundGate.semaphore.tryAcquire()) return Result.retry()
        val store: BackgroundConfig
        try {
            store = BackgroundConfig(applicationContext)
        } catch (_: Exception) {
            BackgroundGate.semaphore.release()
            return Result.retry()
        }
        try {
            if (isStopped) return Result.retry()
            File(store.directory, "catalog.snapshot").delete()
            val config = store.read() ?: return Result.success()
            val vault = File(config.getString("vault"))
            if (BackgroundTransfer.digest(File(config.getString("keyfile"))) != config.getString("identity")) throw BackgroundConflict()
            val signature = BackgroundTransfer.signature(vault)
            if (config.optString("snapshot") == signature) {
                store.status("transferred")
                return Result.success()
            }
            val generation = config.getString("generation")
            val transfer = BackgroundTransfer(
                vault, File(config.getString("keyfile")),
                config.getString("url").toHttpUrl(), config.getString("username"), config.getString("password"),
                config.getString("identity"), config.getString("ownership"),
                File(store.directory, "owned-${config.getString("generation")}"),
                { isStopped || BackgroundGate.waiting.get() > 0 }, { hash ->
                    config.put("ownership", hash)
                    config.put("snapshot", signature)
                    store.write(config)
                },
                store.receipts(generation), { names -> store.receipts(generation, names) },
                store.receipts("$generation-removed"), { names -> store.receipts("$generation-removed", names) },
            )
            BackgroundGate.transfer = transfer
            runningTransfer = transfer
            store.status("uploading")
            transfer.run()
            store.status("transferred")
            return Result.success()
        } catch (_: BackgroundConflict) {
            store.status("reconcile")
            return Result.success() // No immediate retry; foreground reconciliation is required for writes.
        } catch (_: Exception) {
            store.status("pending")
            return Result.retry()
        } finally {
            runningTransfer = null
            BackgroundGate.transfer = null
            BackgroundGate.semaphore.release()
        }
    }
}

/** Activity-owned lease; teardown cannot leave the worker permanently blocked. */
class BackgroundUploads(private val context: Context) {
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var closed = false
    @Volatile private var token: String? = null
    companion object {
        private const val ONCE = "quietake-background-once"
        private const val PERIODIC = "quietake-background-periodic"
    }
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        // Cancellation must reach network I/O before waiting for the gate.
        val waiting = call.method == "begin" || call.method == "reset"
        if (waiting) {
            BackgroundGate.waiting.incrementAndGet()
            BackgroundGate.transfer?.cancel()
        }
        executor.execute {
            try {
                val value: Any? = when (call.method) {
                    "begin" -> {
                        check(token == null)
                        BackgroundGate.semaphore.acquire()
                        if (closed) { BackgroundGate.semaphore.release(); error("Closed") }
                        UUID.randomUUID().toString().also { token = it; BackgroundGate.lease = it }
                    }
                    "end" -> {
                        val given = call.argument<String>("lease")
                        check(given == token)
                        BackgroundGate.release(given); token = null; null
                    }
                    "configure" -> {
                        check(token != null && token == call.argument<String>("lease"))
                        configure(call); null
                    }
                    "reset" -> {
                        check(token == null)
                        BackgroundGate.semaphore.acquire()
                        try {
                            BackgroundConfig(context).clear()
                            WorkManager.getInstance(context).cancelUniqueWork(ONCE).result.get()
                            WorkManager.getInstance(context).cancelUniqueWork(PERIODIC).result.get()
                            BackgroundConfig(context).status("disabled")
                        } finally { BackgroundGate.semaphore.release() }
                        null
                    }
                    "status" -> context.getSharedPreferences("background-backup-status", Context.MODE_PRIVATE)
                        .getString("state", "disabled")
                    "request" -> {
                        val store = BackgroundConfig(context)
                        store.read()?.let { store.status("scheduled"); schedule(it, false) }
                        null
                    }
                    else -> error("Unknown background operation")
                }
                main.post { result.success(value) }
            } catch (_: Exception) {
                main.post { result.error("background", "Background backup unavailable", null) }
            } finally {
                if (waiting) BackgroundGate.waiting.decrementAndGet()
            }
        }
    }

    private fun configure(call: MethodCall) {
        val data = JSONObject(call.argument<Map<String, Any>>("config")!!)
        val root = context.dataDir.canonicalFile
        val vault = File(data.getString("vault")).canonicalFile
        val keyfile = File(data.getString("keyfile")).canonicalFile
        require(vault.path.startsWith(root.path + File.separator) && vault.isDirectory)
        require(keyfile.path.startsWith(root.path + File.separator) && keyfile.isFile)
        val parsed = data.getString("url").toHttpUrl()
        require(parsed.isHttps || parsed.host in listOf("127.0.0.1", "localhost"))
        require(parsed.username.isEmpty() && parsed.password.isEmpty() && parsed.query == null && parsed.fragment == null)
        data.put("url", parsed.newBuilder().apply {
            if (!parsed.encodedPath.endsWith('/')) addPathSegment("")
        }.build().toString())
        require(Regex("[a-f0-9]{64}").matches(data.getString("ownership")))
        data.put("vault", vault.path).put("keyfile", keyfile.path)
        data.put("identity", BackgroundTransfer.digest(keyfile))
        val store = BackgroundConfig(context)
        // Preserve locally owned staging cleanup across disconnect/reconnect or
        // passcode rewrap, without retaining a URL, username or credential there.
        val target = data.getString("url") + "\u0000" + data.getString("username")
        data.put("generation", MessageDigest.getInstance("SHA-256")
            .digest(target.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) })
        val confirmed = data.getJSONArray("confirmed")
        require(confirmed.length() <= 100000)
        val names = (0 until confirmed.length()).map { confirmed.getString(it) }.asReversed().toCollection(linkedSetOf())
        store.receipts(data.getString("generation"), names)
        data.remove("confirmed")
        store.write(data)
        store.status("scheduled")
        schedule(data, true)
    }

    private fun schedule(data: JSONObject, periodic: Boolean) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(if (data.optBoolean("mobileData")) NetworkType.CONNECTED else NetworkType.UNMETERED)
            .setRequiresBatteryNotLow(true).build()
        val manager = WorkManager.getInstance(context)
        // REPLACE so a changed mobile-data choice does not keep stale constraints.
        manager.enqueueUniqueWork(ONCE, ExistingWorkPolicy.REPLACE,
            OneTimeWorkRequestBuilder<BackgroundUploadWorker>().setConstraints(constraints)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS).build()).result.get()
        if (periodic) manager.enqueueUniquePeriodicWork(PERIODIC, ExistingPeriodicWorkPolicy.UPDATE,
            PeriodicWorkRequestBuilder<BackgroundUploadWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints).build()).result.get()
    }

    fun close() {
        closed = true
        executor.execute {
            BackgroundGate.release(token)
            token = null
        }
        executor.shutdown()
    }
}
