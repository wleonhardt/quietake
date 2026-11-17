package cam.quietake.app

import android.content.ComponentName
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
    private var privacyChannel: MethodChannel? = null
    private lateinit var privateImport: PrivateImport
    private lateinit var folderImport: FolderImport
    private lateinit var portableFiles: PortableFiles
    private lateinit var videoPreparation: VideoPreparation
    private lateinit var backgroundUploads: BackgroundUploads

    companion object {
        const val LOCKED_CAMERA = "cam.quietake.app.LOCKED_CAMERA"
    }

    /** Set by the camera tile; the Dart lock screen takes it once (decision 028). */
    @Volatile private var lockedCameraRequested = false

    override fun onCreate(savedInstanceState: Bundle?) {
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
        handleLaunch(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleLaunch(intent)
    }

    /**
     * Only the camera tile's action may show this window over the device lock
     * screen. The app is locked first, so an unlocked session never appears
     * there, and the flag is dropped as soon as the activity pauses.
     */
    private fun handleLaunch(intent: Intent?) {
        if (intent?.action != LOCKED_CAMERA) return
        intent.action = null
        lockedCameraRequested = true
        setShowWhenLocked(true)
        setTurnScreenOn(true)
        privacyChannel?.invokeMethod("lockNow", null)
    }

    override fun onPause() {
        super.onPause()
        lockedCameraRequested = false
        setShowWhenLocked(false)
        setTurnScreenOn(false)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        privacyChannel?.invokeMethod("userLeaving", null)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        backgroundUploads = BackgroundUploads(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quietake/background")
            .setMethodCallHandler(backgroundUploads::handle)
        videoPreparation = VideoPreparation(this)
        privateImport = PrivateImport(this)
        portableFiles = PortableFiles(this)
        folderImport = FolderImport(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quietake/folder")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pick" -> folderImport.pick(result)
                    "copy" -> folderImport.copy(call.argument<String>("id")!!, call.argument<String>("directory")!!, result)
                    "cancel" -> { folderImport.cancel(); result.success(null) }
                    "release" -> folderImport.release(result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quietake/backup")
            .setMethodCallHandler { call, result -> portableFiles.handle(call, result) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quietake/import")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pick" -> privateImport.pick(result)
                    "pickShare" -> privateImport.pick(result, bundle = true)
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quietake/screen")
            .setMethodCallHandler { call, result ->
                if (call.method != "keepAwake") { result.notImplemented(); return@setMethodCallHandler }
                if (call.arguments == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quietake/appearance")
            .setMethodCallHandler { call, result ->
                val main = ComponentName(this, MainActivity::class.java)
                val alias = ComponentName(this, "cam.quietake.app.NeutralAlias")
                when (call.method) {
                    "neutral" -> result.success(
                        packageManager.getComponentEnabledSetting(alias) == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                    )
                    "setNeutral" -> try {
                        val on = call.arguments == true
                        // Enable the wanted entry first so a launcher entry always exists.
                        val enable = if (on) alias else main
                        val disable = if (on) main else alias
                        packageManager.setComponentEnabledSetting(enable, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
                        packageManager.setComponentEnabledSetting(disable, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("failed", "Could not switch the launcher entry", null)
                    }
                    else -> result.notImplemented()
                }
            }
        val privacy = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quietake/privacy")
        privacyChannel = privacy
        LockBridge.channel = privacy
        privacy.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(mapOf(
                    "screenshotProtected" to ((window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE) != 0),
                    "captured" to false, "covered" to false, "backgrounded" to false, "generation" to 0
                ))
                "ready" -> result.success(null)
                "takeLockedCamera" -> {
                    result.success(lockedCameraRequested)
                    lockedCameraRequested = false
                }
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
        if (requestCode == folderImport.requestCode) folderImport.result(resultCode, data)
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
        if (LockBridge.channel === privacyChannel) LockBridge.channel = null
        backgroundUploads.close()
        privateImport.close()
        folderImport.close()
        portableFiles.close()
        videoPreparation.close()
        microphoneResult?.success(false)
        microphoneResult = null
        previews.shutdown()
        super.onDestroy()
    }
}
