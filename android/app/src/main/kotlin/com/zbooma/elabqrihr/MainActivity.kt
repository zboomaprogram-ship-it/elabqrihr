package com.zbooma.elabqrihr

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AttendanceTrustPlugin.attach(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
        BackgroundSyncPlugin.attach(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
    }
}
