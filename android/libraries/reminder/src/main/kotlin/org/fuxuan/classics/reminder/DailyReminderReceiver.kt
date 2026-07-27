package org.fuxuan.classics.reminder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

abstract class DailyReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val host = context.applicationContext as? DailyReminderHost ?: return
        val action = intent.action ?: return
        val isAlarm = action == DailyReminderCoordinator.alarmAction(context)
        if (!isAlarm && action !in RESCHEDULE_ACTIONS) return

        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val coordinator = DailyReminderCoordinator(context, host)
                if (isAlarm) coordinator.deliver() else coordinator.reconcileCurrent()
            } catch (exception: CancellationException) {
                throw exception
            } catch (_: Exception) {
                // A later app start or protected system broadcast can reconcile the schedule.
            } finally {
                pendingResult.finish()
            }
        }
    }

    private companion object {
        val RESCHEDULE_ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_LOCALE_CHANGED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
        )
    }
}
