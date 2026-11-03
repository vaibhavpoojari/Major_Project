package com.example.accident_guard_system

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.telephony.SmsManager
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SMS_CHANNEL = "com.example.accident_guard_system/sms"
    private val PERMISSIONS_CHANNEL = "com.example.accident_guard_system/permissions"
    private val SMS_PERMISSION_CODE = 101
    private val NOTIFICATION_PERMISSION_CODE = 102

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // SMS MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "requestSmsPermission") {
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                    ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.SEND_SMS), SMS_PERMISSION_CODE)
                    result.success(false)
                } else {
                    result.success(true)
                }
            } else if (call.method == "sendSms") {
                val phoneNumber = call.argument<String>("phoneNumber")
                val message = call.argument<String>("message")
                if (phoneNumber != null && message != null) {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.SEND_SMS), SMS_PERMISSION_CODE)
                        result.error("PERMISSION_DENIED", "SMS permission not granted. Requesting now.", null)
                    } else {
                        try {
                            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                applicationContext.getSystemService(SmsManager::class.java) ?: SmsManager.getDefault()
                            } else {
                                SmsManager.getDefault()
                            }
                            val parts = smsManager.divideMessage(message)
                            smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
                            result.success("SMS Dispatched")
                        } catch (e: Exception) {
                            result.error("SMS_FAILED", "Failed to send SMS: ${e.message}", null)
                        }
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Phone number or message was null", null)
                }
            } else if (call.method == "getTelephonyStatus") {
                val tm = getSystemService(android.content.Context.TELEPHONY_SERVICE) as? android.telephony.TelephonyManager
                val simState = tm?.simState ?: android.telephony.TelephonyManager.SIM_STATE_UNKNOWN
                val hasSim = (simState == android.telephony.TelephonyManager.SIM_STATE_READY)
                val carrier = if (!tm?.networkOperatorName.isNullOrEmpty()) tm?.networkOperatorName else "Cellular Network"
                val isSmsCapable = packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)
                result.success(mapOf(
                    "hasSim" to hasSim,
                    "simState" to (if (hasSim) "READY" else "NO_SERVICE"),
                    "carrierName" to carrier,
                    "isSmsCapable" to isSmsCapable
                ))
            } else {
                result.notImplemented()
            }
        }

        // Permissions & App Settings MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSIONS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_CODE)
                            result.success(false)
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "checkNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    } else {
                        result.success(true)
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_SETTINGS_FAILED", "Could not open app settings: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}

