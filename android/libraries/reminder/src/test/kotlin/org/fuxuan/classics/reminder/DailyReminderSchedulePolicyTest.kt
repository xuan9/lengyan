package org.fuxuan.classics.reminder

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant
import java.time.ZoneId

class DailyReminderSchedulePolicyTest {
    private val oslo = ZoneId.of("Europe/Oslo")

    @Test
    fun schedulesLaterTimeOnTheSameLocalDay() {
        val next = DailyReminderSchedulePolicy.nextTrigger(
            instant = Instant.parse("2026-07-27T05:00:00Z"),
            timeZone = oslo,
            hour = 8,
            minute = 30,
        )

        assertEquals(Instant.parse("2026-07-27T06:30:00Z"), next)
    }

    @Test
    fun schedulesTheNextDayWhenTheLocalTimeHasPassed() {
        val next = DailyReminderSchedulePolicy.nextTrigger(
            instant = Instant.parse("2026-07-27T07:00:00Z"),
            timeZone = oslo,
            hour = 8,
            minute = 30,
        )

        assertEquals(Instant.parse("2026-07-28T06:30:00Z"), next)
    }

    @Test
    fun resolvesANonexistentDaylightSavingTimeWithoutAnExactAlarm() {
        val next = DailyReminderSchedulePolicy.nextTrigger(
            instant = Instant.parse("2026-03-28T23:00:00Z"),
            timeZone = oslo,
            hour = 2,
            minute = 30,
        )

        assertEquals(Instant.parse("2026-03-29T01:30:00Z"), next)
        assertEquals(3, next.atZone(oslo).hour)
        assertEquals(30, next.atZone(oslo).minute)
    }

    @Test
    fun doesNotRepeatDuringTheSecondOccurrenceOfAnOverlappingLocalTime() {
        val next = DailyReminderSchedulePolicy.nextTrigger(
            instant = Instant.parse("2026-10-25T00:45:00Z"),
            timeZone = oslo,
            hour = 2,
            minute = 30,
        )

        assertEquals(Instant.parse("2026-10-26T01:30:00Z"), next)
    }

    @Test
    fun schedulesTomorrowWhenNowEqualsTheRequestedMinute() {
        val next = DailyReminderSchedulePolicy.nextTrigger(
            instant = Instant.parse("2026-07-27T06:30:00Z"),
            timeZone = oslo,
            hour = 8,
            minute = 30,
        )

        assertEquals(Instant.parse("2026-07-28T06:30:00Z"), next)
    }
}
