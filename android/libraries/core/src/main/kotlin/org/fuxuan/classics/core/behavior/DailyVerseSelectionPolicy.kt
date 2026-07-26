package org.fuxuan.classics.core.behavior

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

object DailyVerseSelectionPolicy {
    fun localDate(
        instant: Instant,
        timeZone: ZoneId,
    ): LocalDate = instant.atZone(timeZone).toLocalDate()

    fun selectedID(
        productID: String,
        contentVersion: String,
        instant: Instant,
        timeZone: ZoneId,
        candidateIDs: List<String>,
        excludedID: String?,
    ): String? {
        val uniqueCandidates = candidateIDs.filter(String::isNotEmpty).distinct()
        if (uniqueCandidates.isEmpty()) return null

        val filtered = uniqueCandidates.filter { it != excludedID }
        val eligible = filtered.ifEmpty { uniqueCandidates }
        val day = localDate(instant, timeZone).toEpochDay()
        val dayIndex = Math.floorMod(day, eligible.size.toLong()).toInt()
        val versionOffset = stableOffset(productID, contentVersion, eligible.size)
        return eligible[(dayIndex + versionOffset) % eligible.size]
    }

    private fun stableOffset(
        productID: String,
        contentVersion: String,
        count: Int,
    ): Int {
        var hash = FNV_OFFSET_BASIS
        "$productID\u0000$contentVersion".toByteArray(Charsets.UTF_8).forEach { byte ->
            hash = (hash xor byte.toUByte().toULong()) * FNV_PRIME
        }
        return (hash % count.toULong()).toInt()
    }

    private const val FNV_OFFSET_BASIS = 14_695_981_039_346_656_037uL
    private const val FNV_PRIME = 1_099_511_628_211uL
}
