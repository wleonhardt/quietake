package cam.quietake.app

import android.content.Intent
import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Bundle
import android.view.WindowManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    private val previews = Executors.newSingleThreadExecutor()
    private val microphoneRequestCode = 7301
    private var microphoneResult: MethodChannel.Result? = null
    private lateinit var privateImport: PrivateImport
    private lateinit var portableFiles: PortableFiles
    private lateinit var videoPreparation: VideoPreparation
    private lateinit var backgroundUploads: BackgroundUploads

    override fun onCreate(savedInstanceState: Bundle?) {
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        backgroundUploads = BackgroundUploads(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quietake/background")
            .setMethodCallHandler(backgroundUploads::handle)
        videoPreparation = VideoPreparation(this)
        privateImport = PrivateImport(this)
        portableFiles = PortableFiles(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quietake/backup")
            .setMethodCallHandler { call, result -> portableFiles.handle(call, result) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quietake/import")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pick" -> privateImport.pick(result)
                    "clear" -> privateImport.clear(result)
                    "cancel" -> { privateImport.cancel(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quietake/camera")
            .setMethodCallHandler { call, result ->
                if (call.method == "prepareVideo") {
                    videoPreparation.prepare(call.argument<String>("path")!!, call.argument<String>("pending")!!, result)
                    return@setMethodCallHandler
                }
                if (call.method != "requestMicrophone") { result.notImplemented(); return@setMethodCallHandler }
                if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                    result.success(true)
                } else if (microphoneResult != null) {
                    result.error("busy", "A microphone request is already open", null)
                } else {
                    microphoneResult = result
                    requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), microphoneRequestCode)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quietake/privacy")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(mapOf(
                        "screenshotProtected" to ((window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE) != 0),
                        "captured" to false, "covered" to false, "backgrounded" to false, "generation" to 0
                    ))
                    "ready" -> result.success(null)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quietake/previews")
            .setMethodCallHandler { call, result ->
                if (call.method != "video") { result.notImplemented(); return@setMethodCallHandler }
                val url = call.argument<String>("url")!!
                previews.execute {
                    val retriever = MediaMetadataRetriever()
                    try {
                        retriever.setDataSource(url, emptyMap())
                        val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: 0L
                        val frame = retriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                            ?: error("Video has no preview frame")
                        val scale = minOf(1.0, 300.0 / maxOf(frame.width, frame.height))
                        val small = Bitmap.createScaledBitmap(frame, maxOf(1, (frame.width * scale).toInt()), maxOf(1, (frame.height * scale).toInt()), true)
                        val bytes = ByteArrayOutputStream()
                        small.compress(Bitmap.CompressFormat.JPEG, 75, bytes)
                        if (small !== frame) small.recycle()
                        frame.recycle()
                        Handler(Looper.getMainLooper()).post {
                            result.success(mapOf("bytes" to bytes.toByteArray(), "durationMs" to duration))
                        }
                    } catch (error: Exception) {
                        Handler(Looper.getMainLooper()).post { result.error("preview", "Video preview unavailable", null) }
                    } finally { retriever.release() }
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == privateImport.requestCode) privateImport.result(resultCode, data)
        if (requestCode == portableFiles.pickCode || requestCode == portableFiles.saveCode) portableFiles.result(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == microphoneRequestCode) {
            microphoneResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            microphoneResult = null
        }
    }

    override fun onDestroy() {
        backgroundUploads.close()
        privateImport.close()
        portableFiles.close()
        videoPreparation.close()
        microphoneResult?.success(false)
        microphoneResult = null
        previews.shutdown()
        super.onDestroy()
    }
}
