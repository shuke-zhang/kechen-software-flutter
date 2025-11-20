package com.example.kechen_software_flutter

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "kechen_software_flutter/system_video_player"
    private val REQUEST_CODE = 999

    private var pendingResult: MethodChannel.Result? = null
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        methodChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "openSystemPlayer" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrEmpty()) {
                        result.error("INVALID_URL", "url is empty", null)
                        return@setMethodCallHandler
                    }

                    openSystemPlayer(url, result)
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * 打开系统播放器
     */
    private fun openSystemPlayer(url: String, result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.parse(url), "video/*")
            }

            pendingResult = result

            Log.i("SystemVideoPlayer", "启动系统播放器播放：$url")

            startActivityForResult(intent, REQUEST_CODE)

        } catch (e: Exception) {
            result.error("OPEN_FAILED", e.message, null)
            pendingResult = null
        }
    }

    /**
     * 系统播放器关闭时会回到这里（无论自然播放结束 / 用户退出）
     */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_CODE) {

            Log.i("SystemVideoPlayer", "系统播放器关闭了")

            // 通知 Flutter
            methodChannel?.invokeMethod("onSystemPlayerExit", null)

            // 让 Flutter 得到 openSystemPlayer 的结果
            pendingResult?.success(true)
            pendingResult = null
        }

        super.onActivityResult(requestCode, resultCode, data)
    }
}
