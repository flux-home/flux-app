package com.fluxhome.app

import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Relaunches the app process.
 *
 * Used when the CHIP controller must be (re)built onto a different fabric:
 * this CHIP build aborts if a second [chip.devicecontroller.ChipDeviceController]
 * is constructed in-process, so fabric changes are applied by restarting and
 * letting `ChipClient.init` build a single controller on the persisted identity.
 */
object AppRestart {
    private const val TAG = "AppRestart"

    fun relaunch(context: Context) {
        Log.i(TAG, "Relaunching app process")
        val intent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        if (intent != null) context.startActivity(intent)
        Runtime.getRuntime().exit(0)
    }
}
