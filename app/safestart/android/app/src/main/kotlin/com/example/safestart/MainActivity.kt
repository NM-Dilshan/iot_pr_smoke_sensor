package com.example.safestart

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var smsBridge: EmergencySmsBridge? = null
    private var networkBridge: LocalNetworkBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        smsBridge = EmergencySmsBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        networkBridge = LocalNetworkBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        smsBridge?.onPermissionResult(requestCode, grantResults)
    }

    override fun onDestroy() {
        smsBridge?.dispose()
        networkBridge?.dispose()
        super.onDestroy()
    }
}
