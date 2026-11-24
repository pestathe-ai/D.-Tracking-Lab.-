package dev.dtrackinglab.d_tracking_lab

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dtl/share").also {
            it.setMethodCallHandler { call, result ->
                if (call.method == "getInitial") {
                    result.success(pending)
                    pending = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) pending = extract(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val data = extract(intent) ?: return
        val ch = channel
        if (ch != null) ch.invokeMethod("onShare", data) else pending = data
    }

    private fun extract(i: Intent?): Map<String, String>? {
        if (i?.action != ShareTrampolineActivity.ACTION_ADD) return null
        return mapOf(
            "text" to (i.getStringExtra("text") ?: ""),
            "source" to (i.getStringExtra("source") ?: "")
        )
    }
}
