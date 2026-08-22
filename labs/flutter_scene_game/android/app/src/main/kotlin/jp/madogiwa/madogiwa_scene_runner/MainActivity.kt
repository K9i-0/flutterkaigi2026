package jp.madogiwa.madogiwa_scene_runner

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import kotlin.math.abs

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The game targets a stable 60 fps. Rendering at 90/120 Hz on a
        // high-refresh phone wastes the thermal/GPU budget without changing
        // gameplay, so prefer the panel mode nearest 60 Hz when available.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val targetMode = display?.supportedModes?.minByOrNull {
                abs(it.refreshRate - 60f)
            }
            if (targetMode != null) {
                val attributes = window.attributes
                attributes.preferredDisplayModeId = targetMode.modeId
                window.attributes = attributes
            }
        }
    }
}
