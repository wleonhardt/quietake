package cam.quietake.app

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Receives one `.quietake-share` file that another app opened with Quietake
 * (decision 031). The bundle is already encrypted with its own passphrase, so
 * keeping the bounded private copy while the vault is locked reveals nothing.
 * The Dart side asks for it only after unlock, and a stale copy from an earlier
 * process is deleted at startup. Whether the file really is a share bundle is
 * checked by the bundle reader, not here.
 */
class IncomingShare(private val activity: Activity) {
    private val directory = File(activity.cacheDir, "quietake-incoming").apply { deleteRecursively() }
    private val worker = Executors.newSingleThreadExecutor()
    private val file = File(directory, "incoming.quietake-share")
    /** Copies started and not yet finished; two quick opens must both finish before Dart looks. */
    private var copies = 0
    private var waiting = mutableListOf<MethodChannel.Result>()

    /** Starts a bounded copy for a VIEW intent that carries a content or file URI. */
    fun accept(intent: Intent) {
        val uri = intent.data ?: return
        if (uri.scheme != "content") return
        intent.data = null
        intent.action = null
        copies++
        worker.execute {
            var ok = false
            try {
                directory.mkdirs()
                val part = File(directory, "incoming.part")
                var count = 0L
                activity.contentResolver.openInputStream(uri)!!.use { input ->
                    part.outputStream().use { output ->
                        val buffer = ByteArray(64 * 1024)
                        while (true) {
                            val n = input.read(buffer)
                            if (n < 0) break
                            count += n
                            check(count <= LIMIT)
                            output.write(buffer, 0, n)
                        }
                    }
                }
                file.delete()
                ok = part.renameTo(file)
                if (!ok) part.delete()
            } catch (_: Throwable) {
                File(directory, "incoming.part").delete()
            }
            activity.runOnUiThread {
                copies--
                if (copies == 0) {
                    val ready = file.isFile
                    waiting.forEach { it.success(ready) }
                    waiting = mutableListOf()
                }
            }
        }
    }

    /** True once a copy is ready; waits for a copy that is still running. */
    fun available(result: MethodChannel.Result) {
        if (copies > 0) waiting.add(result) else result.success(file.isFile)
    }

    /** Moves the copy into the import folder so the normal cleanup removes it. */
    fun take(into: File, result: MethodChannel.Result) {
        if (!file.isFile) { result.success(emptyList<Any>()); return }
        into.mkdirs()
        val target = File(into, "incoming.quietake-share")
        target.delete()
        if (file.renameTo(target)) {
            result.success(listOf(mapOf("name" to "incoming.quietake-share", "path" to target.path)))
        } else {
            result.success(listOf(mapOf("name" to "Shared file", "error" to "Could not open the received file.")))
        }
    }

    fun close() { worker.shutdownNow() }

    companion object { const val LIMIT = 513L * 1024 * 1024 }
}
