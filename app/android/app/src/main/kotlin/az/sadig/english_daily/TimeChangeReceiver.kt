package az.sadig.english_daily

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import dev.fluttercommunity.workmanager.BackgroundWorker

/**
 * After a reboot, a manual clock change or a time zone change, run the Dart
 * background task "reschedule" (see lib/services/background.dart). It
 * recomputes the daily reminder, any snooze for today and the prefetch job.
 */
class TimeChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val request = OneTimeWorkRequest.Builder(BackgroundWorker::class.java)
            .setInputData(
                Data.Builder()
                    .putString(BackgroundWorker.DART_TASK_KEY, "reschedule")
                    .build()
            )
            .build()
        WorkManager.getInstance(context)
            .enqueueUniqueWork("reschedule-after-time-change", ExistingWorkPolicy.REPLACE, request)
    }
}
