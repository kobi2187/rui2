package dev.rui.rui_mockups

import dev.rui.android.RuiActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The Flutter app's Android side, plus one channel: Dart calls
 * `open(screen)` and the RUI version of that screen opens over it
 * (lib/rui_bridge.dart).
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.rui/rui")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> {
                        val screen = call.argument<String>("screen")
                        if (screen == null) {
                            result.error("no-screen", "open needs a screen", null)
                        } else {
                            startActivity(RuiActivity.intent(this, screen, call.argument<String>("theme")))
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
