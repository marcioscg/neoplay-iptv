package br.com.neoplay.neoplay

import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Picture-in-Picture nativo (janela flutuante estilo YouTube Premium).
 *
 * O Flutter pede `enter` quando o app vai para segundo plano com um vídeo
 * tocando. Os botões da janelinha (voltar 10s / play-pause / avançar 10s)
 * voltam pelo canal `miaunet/pip`, método `action`.
 *
 * Tudo protegido por `SDK_INT >= O` (PiP exige Android 8).
 */
class MainActivity : FlutterActivity() {
    private val channelName = "miaunet/pip"
    private var channel: MethodChannel? = null
    private var isPlaying = true
    private var receiver: BroadcastReceiver? = null

    private val actionControl = "br.com.neoplay.neoplay.PIP_CONTROL"
    private val extraControl = "control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, channelName
        )
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(pipSupported())
                "enter" -> {
                    isPlaying = call.argument<Boolean>("playing") ?: true
                    result.success(enterPip())
                }
                "setPlaying" -> {
                    isPlaying = call.argument<Boolean>("playing") ?: true
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        isInPictureInPictureMode
                    ) {
                        setPictureInPictureParams(buildParams())
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        registerPipReceiver()
    }

    private fun pipSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(
                PackageManager.FEATURE_PICTURE_IN_PICTURE
            )

    private fun enterPip(): Boolean {
        if (!pipSupported()) return false
        return try {
            enterPictureInPictureMode(buildParams())
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun buildParams(): PictureInPictureParams {
        val actions = listOf(
            remoteAction(android.R.drawable.ic_media_rew, "Voltar 10s", "rewind"),
            remoteAction(
                if (isPlaying) android.R.drawable.ic_media_pause
                else android.R.drawable.ic_media_play,
                "Play/Pause", "playpause"
            ),
            remoteAction(android.R.drawable.ic_media_ff, "Avançar 10s", "forward")
        )
        return PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
            .setActions(actions)
            .build()
    }

    private fun remoteAction(icon: Int, title: String, control: String): RemoteAction {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        val intent = Intent(actionControl)
            .setPackage(packageName)
            .putExtra(extraControl, control)
        val pending =
            PendingIntent.getBroadcast(this, control.hashCode(), intent, flags)
        return RemoteAction(Icon.createWithResource(this, icon), title, title, pending)
    }

    private fun registerPipReceiver() {
        if (receiver != null) return
        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val control = intent?.getStringExtra(extraControl) ?: return
                channel?.invokeMethod("action", control)
            }
        }
        val filter = IntentFilter(actionControl)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, filter)
        }
    }

    override fun onDestroy() {
        receiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {
            }
        }
        receiver = null
        super.onDestroy()
    }
}
