package cam.quietake.app

import android.app.Activity
import android.content.Intent
import android.provider.DocumentsContract
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/** Files providers see only the encrypted ZIP; selected sources are read-only. */
class PortableFiles(private val activity: Activity) {
    private val root = File(activity.cacheDir, "quietake-backup")
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var output: File? = null
    @Volatile private var cancelled = false
    @Volatile private var closed = false
    val pickCode = 7304
    val saveCode = 7305

    init { root.deleteRecursively() }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "cancel") { cancelled = true; result.success(null); return }
        if (pending != null) { result.error("busy", "Backup operation still open", null); return }
        if (call.method == "clear") {
            if (root.exists() && !root.deleteRecursively()) result.error("storage", "Could not clear backup copies", null)
            else result.success(null)
            return
        }
        try {
            root.mkdirs()
            cancelled = false
            when (call.method) {
                "pick" -> {
                    pending = result
                    activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        type = "application/zip"
                        addCategory(Intent.CATEGORY_OPENABLE)
                    }, pickCode)
                }
                "save" -> {
                    val source = File(call.argument<String>("path")!!)
                    require(source.canonicalPath.startsWith(root.canonicalPath + File.separator))
                    require(source.length() in 22..MAX_BYTES)
                    output = source
                    pending = result
                    activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        type = "application/zip"
                        addCategory(Intent.CATEGORY_OPENABLE)
                        putExtra(Intent.EXTRA_TITLE, "Quietake-backup.zip")
                    }, saveCode)
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            pending = null
            output = null
            result.error("backup", "Could not open Files", null)
        }
    }

    fun result(code: Int, resultCode: Int, data: Intent?) {
        val callback = pending ?: return
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pending = null; output = null
            callback.success(if (code == saveCode) false else null)
            return
        }
        val uri = data.data!!
        val target = if (code == pickCode) File(root, "${UUID.randomUUID()}.zip") else null
        val source = output
        executor.execute {
            try {
                val input = if (code == pickCode) activity.contentResolver.openInputStream(uri)!! else source!!.inputStream()
                var size = 0L
                input.use { from ->
                    val sink = if (code == pickCode) target!!.outputStream() else activity.contentResolver.openOutputStream(uri, "wt")!!
                    sink.use { to ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        check(!cancelled)
                        val count = from.read(buffer)
                        if (count < 0) break
                        size += count
                        require(size <= MAX_BYTES)
                        to.write(buffer, 0, count)
                    }
                    to.flush()
                } }
                main.post {
                    if (closed) return@post
                    pending = null; output = null
                    callback.success(if (code == pickCode) target!!.path else true)
                }
            } catch (_: Throwable) {
                target?.delete()
                // "wt" truncated the chosen destination; do not leave a partial backup there.
                if (code == saveCode) try { DocumentsContract.deleteDocument(activity.contentResolver, uri) } catch (_: Exception) { }
                main.post {
                    if (closed) return@post
                    pending = null; output = null
                    callback.error("backup", "Could not copy encrypted backup. Check storage and retry.", null)
                }
            }
        }
    }

    /** Fails any open call so Dart never waits on a destroyed activity. */
    fun close() {
        closed = true
        cancelled = true
        executor.shutdown()
        pending?.error("closed", "Backup interrupted. Try again.", null)
        pending = null
        output = null
    }
    companion object { const val MAX_BYTES = 2L * 1024 * 1024 * 1024 }
}
