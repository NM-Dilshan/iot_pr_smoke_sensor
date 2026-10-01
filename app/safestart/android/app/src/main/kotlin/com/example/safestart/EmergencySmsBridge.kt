package com.example.safestart

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/** Called only after the Flutter confirmation dialog. No startup permission request. */
class EmergencySmsBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "safestart/emergency_sms")
    private val handler = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var receiver: BroadcastReceiver? = null
    private var phone = ""
    private var message = ""
    private var dispatched = false
    private var permanentlyDenied = false
    private val timeout = Runnable {
        finish("failed", "Sending could not be confirmed. Do not resend; check the phone and contact the recipient directly.", canRetry = false)
    }

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "sendEmergencyAlert") {
                result.notImplemented()
            } else if (pending != null) {
                result.success(mapOf("status" to "failed", "message" to "An alert is already in progress.", "canRetry" to false))
            } else {
                pending = result
                phone = (call.argument<String>("phoneNumber") ?: "").replace(Regex("[\\s()-]"), "")
                message = call.argument<String>("message") ?: ""
                dispatched = false
                begin()
            }
        }
    }

    private fun begin() {
        val emulator = Build.FINGERPRINT.startsWith("generic") || Build.FINGERPRINT.contains("emulator") ||
            Build.MODEL.contains("sdk", ignoreCase = true) || Build.HARDWARE in listOf("goldfish", "ranchu")
        val feature = if (Build.VERSION.SDK_INT >= 33) PackageManager.FEATURE_TELEPHONY_MESSAGING else PackageManager.FEATURE_TELEPHONY
        if (emulator || !activity.packageManager.hasSystemFeature(feature)) {
            finish("unsupported", "Use a supported Android phone with an active SMS SIM.")
            return
        }
        if (!Regex("\\+?[0-9]{7,15}").matches(phone) || message.isBlank()) {
            finish("failed", "Check the emergency contact phone number and message.")
            return
        }
        if (activity.checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) {
            send()
        } else if (permanentlyDenied && !activity.shouldShowRequestPermissionRationale(Manifest.permission.SEND_SMS)) {
            finish("permissionDenied", permanent = true)
        } else {
            activity.requestPermissions(arrayOf(Manifest.permission.SEND_SMS), PERMISSION_REQUEST)
        }
    }

    fun onPermissionResult(requestCode: Int, grants: IntArray) {
        if (requestCode != PERMISSION_REQUEST || pending == null) return
        if (grants.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            permanentlyDenied = false
            send()
        } else {
            permanentlyDenied = !activity.shouldShowRequestPermissionRationale(Manifest.permission.SEND_SMS)
            finish("permissionDenied", permanent = permanentlyDenied)
        }
    }

    @Suppress("DEPRECATION")
    private fun send() {
        try {
            val telephony = activity.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            if (telephony?.simState != TelephonyManager.SIM_STATE_READY) {
                finish("failed", "No ready SIM is available. Check the SIM and mobile service.")
                return
            }
            val subscription = SubscriptionManager.getDefaultSmsSubscriptionId()
            if (!SubscriptionManager.isValidSubscriptionId(subscription)) {
                finish("failed", "Choose a default SIM for SMS in Android Settings, then try again.")
                return
            }
            val manager = if (Build.VERSION.SDK_INT >= 31) {
                activity.getSystemService(SmsManager::class.java).createForSubscriptionId(subscription)
            } else SmsManager.getSmsManagerForSubscriptionId(subscription)
            if (manager.divideMessage(message).size != 1) {
                finish("failed", "The alert must fit in one SMS.")
                return
            }
            val action = "${activity.packageName}.SMS_SENT.${UUID.randomUUID()}"
            receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    if (intent.action != action) return
                    when (resultCode) {
                        Activity.RESULT_OK -> finish("sent")
                        SmsManager.RESULT_ERROR_NO_SERVICE -> finish("failed", "No mobile service. Check signal before trying again.")
                        SmsManager.RESULT_ERROR_RADIO_OFF -> finish("failed", "The mobile radio is off. Check airplane mode.")
                        else -> finish("failed", "Android could not send the SMS. Check your SIM, signal, and SMS balance.")
                    }
                }
            }
            if (Build.VERSION.SDK_INT >= 33) {
                activity.registerReceiver(receiver, IntentFilter(action), Context.RECEIVER_NOT_EXPORTED)
            } else activity.registerReceiver(receiver, IntentFilter(action))
            val sentIntent = PendingIntent.getBroadcast(activity, 0, Intent(action).setPackage(activity.packageName),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            manager.sendTextMessage(phone, null, message, sentIntent, null)
            dispatched = true
            handler.postDelayed(timeout, 90_000)
        } catch (_: SecurityException) {
            finish("permissionDenied", "Android did not allow SMS sending. Check the app's SMS permission.")
        } catch (_: Exception) {
            finish("failed", "SMS sending is unavailable. Check the SIM and device settings.", canRetry = !dispatched)
        }
    }

    private fun finish(status: String, message: String? = null, permanent: Boolean = false, canRetry: Boolean = true) {
        handler.removeCallbacks(timeout)
        receiver?.let { try { activity.unregisterReceiver(it) } catch (_: IllegalArgumentException) { } }
        receiver = null
        val result = pending
        pending = null
        result?.success(mapOf("status" to status, "message" to message, "permanentlyDenied" to permanent, "canRetry" to canRetry))
    }

    fun dispose() {
        finish("failed", "The SMS operation was interrupted; check the phone before resending.", canRetry = !dispatched)
        channel.setMethodCallHandler(null)
    }

    companion object { private const val PERMISSION_REQUEST = 4109 }
}
