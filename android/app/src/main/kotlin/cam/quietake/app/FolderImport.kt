package cam.quietake.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Lists one chosen folder and copies single files, read-only, into private storage. */
class FolderImport(private val activity: Activity) {
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var tree: Uri? = null
    @Volatile private var closed = false
    @Volatile private var cancelled = false
    val requestCode = 7303

    fun pick(result: MethodChannel.Result) {
        if (pending != null) { result.error("busy", "Folder import already open", null); return }
        pending = result
        cancelled = false
        try {
            activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), requestCode)
        } catch (_: Exception) {
            pending = null
            result.error("picker", "Could not open Files", null)
        }
    }

    fun result(code: Int, data: Intent?) {
        val callback = pending ?: return
        val uri = data?.data
        if (code != Activity.RESULT_OK || uri == null) {
            pending = null
            callback.success(null)
            return
        }
        tree = uri
        worker.execute {
            val entries = try { list(uri) } catch (_: Throwable) { null }
            activity.runOnUiThread {
                if (closed) return@runOnUiThread
                pending = null
                if (entries == null) callback.error("list", "Could not read this folder", null)
                else callback.success(mapOf("identity" to uri.toString(), "entries" to entries))
            }
        }
    }

    /** Direct children that are files; subfolders are not walked. */
    private fun list(root: Uri): List<Map<String, String>> {
        val parent = DocumentsContract.getTreeDocumentId(root)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(root, parent)
        val entries = mutableListOf<Map<String, String>>()
        activity.contentResolver.query(
            children,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            ),
            null, null, null,
        )?.use {
            while (it.moveToNext()) {
                if (it.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) continue
                entries.add(mapOf("id" to it.getString(0), "name" to it.getString(1)))
                // One more than the Dart limit so it can refuse the folder.
                if (entries.size > 10001) break
            }
        }
        return entries
    }

    fun copy(id: String, directory: String, result: MethodChannel.Result) {
        val root = tree
        if (root == null || closed) { result.error("closed", "Choose the folder again", null); return }
        worker.execute {
            var file: File? = null
            try {
                val name = id.substringAfterLast('/')
                val extension = name.substringAfterLast('.', "").lowercase()
                if (extension !in listOf("jpg", "jpeg", "png", "mp4")) throw IllegalArgumentException("type")
                val dir = File(directory).apply { mkdirs() }
                file = File.createTempFile("item-", ".$extension", dir)
                val limit = if (extension == "mp4") 512L * 1024 * 1024 else 32L * 1024 * 1024
                var count = 0L
                val uri = DocumentsContract.buildDocumentUriUsingTree(root, id)
                activity.contentResolver.openInputStream(uri)!!.use { input ->
                    file.outputStream().use { output ->
                        val buffer = ByteArray(64 * 1024)
                        while (true) {
                            check(!closed && !cancelled && !Thread.currentThread().isInterrupted)
                            val n = input.read(buffer)
                            if (n < 0) break
                            count += n
                            check(count <= limit)
                            output.write(buffer, 0, n)
                        }
                    }
                }
                val path = file.path
                activity.runOnUiThread { result.success(path) }
            } catch (_: Throwable) {
                file?.delete()
                activity.runOnUiThread { result.error("copy", "Could not copy this file", null) }
            }
        }
    }

    fun cancel() { cancelled = true }

    fun release(result: MethodChannel.Result) {
        tree = null
        result.success(null)
    }

    fun close() {
        closed = true
        worker.shutdownNow()
        pending?.error("closed", "Import interrupted. Choose the folder again.", null)
        pending = null
    }
}
