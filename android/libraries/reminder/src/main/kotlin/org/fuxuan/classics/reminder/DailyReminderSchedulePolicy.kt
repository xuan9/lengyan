package org.fuxuan.classics.reminder

import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId

object DailyReminderSchedulePolicy {
    fun nextTrigger(
        instant: Instant,
        timeZone: ZoneId,
        hour: Int,
        minute: Int,
    ): Instant {
        require(hour in 0..23) { "reminder hour must be within the local day" }
        require(minute in 0..59) { "reminder minute must be within the hour" }

        val now = instant.atZone(timeZone)
        val time = LocalTime.of(hour, minute)
        val today = now.toLocalDate().atTime(time).atZone(timeZone)
        val next = if (today.toInstant() > instant) {
            today
        } else {
            now.toLocalDate().plusDays(1).atTime(time).atZone(timeZone)
        }
        return next.toInstant()
    }
}
