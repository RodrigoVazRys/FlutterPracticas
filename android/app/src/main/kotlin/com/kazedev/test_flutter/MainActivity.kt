package com.kazedev.test_flutter

import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.kazedev.app/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                // ── FLAG_SECURE (previene capturas de pantalla) ──────────────
                "toggleSecure" -> {
                    val isSecure = call.arguments as? Boolean ?: false
                    runOnUiThread {
                        if (isSecure) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                    }
                    result.success(null)
                }

                // ── Detección de ubicación simulada (Mock GPS) ───────────────
                "isMockLocation" -> {
                    try {
                        val isMock = isMockLocationActive()
                        result.success(isMock)
                    } catch (e: Exception) {
                        result.error("MOCK_CHECK_FAILED", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Verifica si algún proveedor de ubicación activo está entregando
     * ubicaciones simuladas. Funciona en Android 5+ (API 18+).
     */
    private fun isMockLocationActive(): Boolean {
        val locationManager =
            getSystemService(LOCATION_SERVICE) as LocationManager

        val providers = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER
        )

        for (provider in providers) {
            if (!locationManager.isProviderEnabled(provider)) continue
            try {
                val location: Location? =
                    locationManager.getLastKnownLocation(provider)
                if (location != null) {
                    // API 18+: isFromMockProvider
                    if (location.isFromMockProvider) return true

                    // Android 12+ (API 31): isMock
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        if (location.isMock) return true
                    }
                }
            } catch (_: SecurityException) {
                // Permiso de ubicación no concedido aún; el check del plugin
                // en Dart ya lo maneja, así que ignoramos aquí.
            }
        }
        return false
    }
}