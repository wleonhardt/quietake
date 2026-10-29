package cam.quietake.app

import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Private, capture-queue-owned conversion. Compatible recordings stay byte-identical. */
@androidx.annotation.OptIn(UnstableApi::class)
class VideoPreparation(private val context: Context) {
    private val directory = File(context.cacheDir, "video-preparation").apply {
        // A killed export must not leave an extra plaintext copy after restart.
        deleteRecursively()
        mkdirs()
    }
    private var transformer: Transformer? = null
    private var output: File? = null
    private var pending: MethodChannel.Result? = null

    private fun compatible(file: File): Boolean {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(file.path)
            val types = (0 until extractor.trackCount).map {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)
            }
            return MimeTypes.VIDEO_H264 in types && MimeTypes.AUDIO_AAC in types
        } finally {
            extractor.release()
        }
    }

    /** [pendingPath] is the Dart-owned private capture directory, passed over the channel. */
    fun prepare(path: String, pendingPath: String, result: MethodChannel.Result) {
        if (pending != null) {
            // Dart serializes captures; a second call would orphan the first future.
            result.error("busy", "Another video is still being prepared", null)
            return
        }
        try {
            val input = File(path).canonicalFile
            val pendingDirectory = File(pendingPath).canonicalFile
            // dataDir is /data/user/0/<pkg>, a symlink to /data/data/<pkg>; compare canonical forms.
            require(pendingDirectory.path.startsWith(File(context.applicationInfo.dataDir).canonicalPath + File.separator))
            require(input.path.startsWith(context.cacheDir.canonicalPath + File.separator) ||
                input.path.startsWith(pendingDirectory.path + File.separator))
            if (compatible(input)) {
                result.success(input.path)
                return
            }
            pending = result
            val target = File.createTempFile("video-", ".mp4", directory)
            output = target
            transformer = Transformer.Builder(context)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        try {
                            check(compatible(target))
                            finish(true)
                        } catch (_: Exception) {
                            finish(false)
                        }
                    }

                    override fun onError(composition: Composition, exportResult: ExportResult, exception: ExportException) {
                        // The code names the failing stage; the user message stays generic.
                        android.util.Log.w("Quietake", "Video preparation failed: ${exception.errorCodeName}")
                        finish(false)
                    }
                })
                .build()
            transformer!!.start(EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(input))).build(), target.path)
        } catch (_: Exception) {
            if (pending != null) finish(false)
            else result.error("video_preparation", "Could not prepare TV-compatible video", null)
        }
    }

    private fun finish(success: Boolean) {
        val result = pending ?: return
        pending = null
        if (!success) transformer?.cancel()
        transformer = null
        val file = output
        output = null
        if (success) {
            result.success(file!!.path)
        } else {
            file?.delete()
            result.error("video_preparation", "Could not prepare TV-compatible video", null)
        }
    }

    fun close() {
        finish(false)
    }
}
