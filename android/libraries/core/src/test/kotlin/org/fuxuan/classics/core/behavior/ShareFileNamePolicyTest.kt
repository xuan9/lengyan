package org.fuxuan.classics.core.behavior

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class ShareFileNamePolicyTest {
    @Test
    fun semanticTextNameNeedsNoDateOrOpaqueSuffix() {
        val fileName = ShareFileNamePolicy.fileName(
            locale = "zh-Hant",
            defaultBaseName = "楞嚴經",
            source = "《楞嚴經 卷一》",
            kind = ShareFileKind.TEXT,
        )

        assertEquals("楞嚴經-卷一-經文.txt", fileName)
        assertFalse(fileName.contains(Regex("\\d{8}|[A-F0-9]{6}")))
    }

    @Test
    fun semanticPagedImageNameKeepsStablePaddedPageNumbers() {
        val fileName = ShareFileNamePolicy.fileName(
            locale = "zh-Hans",
            defaultBaseName = "楞严经",
            source = "《楞严经 卷二》",
            kind = ShareFileKind.IMAGE,
            pageNumber = 2,
            pageCount = 12,
        )

        assertEquals("楞严经-卷二-分享图-02-12.jpg", fileName)
    }
}
