package com.example.kechen_software_flutter.plugins

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class SystemVideoPlayerPlugin(
    private val activity: Activity,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {

    companion object {
        private const val REQUEST_CODE = 999
    }

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openSystemPlayer" -> {
                val url = call.argument<String>("url")
                openSystemPlayer(url)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun openSystemPlayer(url: String?) {
        if (url == null) return

        val intent = Intent(Intent.ACTION_VIEW)
        intent.setDataAndType(Uri.parse(url), "video/*")

        Log.i("SystemVideoPlayer", "启动系统播放器播放：$url")

        activity.startActivityForResult(intent, REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_CODE) {

            Log.i("SystemVideoPlayer", "系统播放器关闭了")

            // 回调给 Flutter
            channel.invokeMethod("onSystemPlayerExit", null)

            return true
        }
        return false
    }
}
