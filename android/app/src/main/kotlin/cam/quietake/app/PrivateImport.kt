package cam.quietake.app

import android.app.Activity
import android.content.Intent
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Only app-owned, bounded copies cross the Dart channel. Sources remain read-only. */
class PrivateImport(private val activity: Activity) {
    private class Rejected(message: String) : Exception(message)
    private val directory = File(activity.cacheDir, "quietake-import").apply {
        deleteRecursively()
    }
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    @Volatile private var closed = false
    @Volatile private var cancelled = false
    val requestCode = 7302

    fun pick(result: MethodChannel.Result) {
        if (pending != null) { result.error("busy", "Import already open", null); return }
        pending = result
        cancelled = false
        try {
            directory.deleteRecursively()
            directory.mkdirs()
            activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/jpeg", "image/png", "video/mp4"))
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            }, requestCode)
        } catch (_: Exception) {
            pending = null
            result.error("picker", "Could not open Files", null)
        }
    }

    fun result(code: Int, data: Intent?) {
        val callback = pending ?: return
        if (code != Activity.RESULT_OK || data == null) {
            pending = null
            callback.success(emptyList<Any>())
            return
        }
        val uris = data.clipData?.let { clip ->
            (0 until clip.itemCount).map { clip.getItemAt(it).uri }
        } ?: listOfNotNull(data.data)
        worker.execute {
            var remaining = 512L * 1024 * 1024
            val entries = if (uris.size > 20) listOf(mapOf("name" to "Selection", "error" to "Choose up to 20 files."))
            else uris.map { uri ->
                var name = "Selected file"
                var file: File? = null
                try {
                    check(!closed && !cancelled)
                    activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                        if (it.moveToFirst()) name = it.getString(0) ?: name
                    }
                    val extension = name.substringAfterLast('.', "").lowercase()
                    if (extension !in listOf("jpg", "jpeg", "png", "mp4")) throw Rejected("Use JPEG, PNG or MP4.")
                    val limit = minOf(remaining, if (extension == "mp4") 512L * 1024 * 1024 else 32L * 1024 * 1024)
                    file = File.createTempFile("item-", ".$extension", directory)
                    var count = 0L
                    activity.contentResolver.openInputStream(uri)!!.use { input ->
                        file.outputStream().use { output ->
                            val buffer = ByteArray(64 * 1024)
                            while (true) {
                                check(!closed && !cancelled && !Thread.currentThread().isInterrupted)
                                val n = input.read(buffer)
                                if (n < 0) break
                                count += n
                                if (count > limit) throw Rejected("Import size limit exceeded.")
                                output.write(buffer, 0, n)
                            }
                        }
                    }
                    remaining -= count
                    mapOf("name" to name, "path" to file.path)
                } catch (error: Throwable) {
                    file?.delete()
                    mapOf("name" to name, "error" to if (cancelled) "Cancelled" else if (error is Rejected) error.message else "Could not copy. Check storage and try again.")
                }
            }
            activity.runOnUiThread {
                if (!closed) { pending = null; callback.success(entries) }
            }
        }
    }

    fun cancel() { cancelled = true }

    fun clear(result: MethodChannel.Result) {
        if (pending != null) { result.error("busy", "Import still open", null); return }
        if (directory.exists() && !directory.deleteRecursively()) {
            result.error("storage", "Could not clear temporary import copies", null)
        } else result.success(null)
    }

    fun close() {
        closed = true
        worker.shutdownNow()
        pending?.error("closed", "Import interrupted. Select files again.", null)
        pending = null
    }
}
