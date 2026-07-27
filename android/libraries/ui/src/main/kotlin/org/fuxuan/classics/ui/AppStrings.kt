package org.fuxuan.classics.ui

import org.fuxuan.classics.core.persistence.ThemePreference

internal class AppStrings(locale: String) {
    private val simplified = locale == "zh-Hans"

    val startReading = if (simplified) "开始阅读" else "開始閱讀"
    val continueReading = if (simplified) "继续阅读" else "繼續閱讀"
    val reading = if (simplified) "读经" else "讀經"
    val scriptureDirectory = if (simplified) "经文目录" else "經文目錄"
    val outline = "科判"
    val volumes = "卷目"
    val expanded = if (simplified) "已展开" else "已展開"
    val collapsed = if (simplified) "已折叠" else "已收合"
    val favorites = "收藏"
    val noFavorites = if (simplified) "还没有收藏" else "還沒有收藏"
    val addFavorite = if (simplified) "收藏当前段落" else "收藏當前段落"
    val removeFavorite = "取消收藏"
    val favoriteUnavailable = if (simplified) {
        "此收藏无法在当前版本定位"
    } else {
        "此收藏無法在當前版本定位"
    }
    val settings = if (simplified) "设置" else "設定"
    val appearance = if (simplified) "外观" else "外觀"
    val language = if (simplified) "语言" else "語言"
    val fontSize = if (simplified) "正文字号" else "正文字號"
    val fontPreview = if (simplified) "如是我闻" else "如是我聞"
    val search = "搜索"
    val clearSearch = "清除搜索"
    val commonKeywords = if (simplified) "常用关键词" else "常用關鍵詞"
    val searchUnavailable = if (simplified) "搜索暂时无法使用" else "搜索暫時無法使用"
    val outlineResult = "科判"
    val scriptureResult = if (simplified) "经文" else "經文"
    val searchResultLimit = if (simplified) {
        "仅显示前 50 项，请输入更完整的关键词"
    } else {
        "僅顯示前 50 項，請輸入更完整的關鍵詞"
    }
    val searchKeywords = if (simplified) {
        listOf(
            "如来藏", "真心", "妙明", "妙真如性", "因缘", "和合", "虚空",
            "客尘", "生灭", "菩提", "涅槃", "妄想", "圆通", "反闻闻自性", "歇即菩提",
        )
    } else {
        listOf(
            "如來藏", "真心", "妙明", "妙真如性", "因緣", "和合", "虛空",
            "客塵", "生滅", "菩提", "涅槃", "妄想", "圓通", "反聞聞自性", "歇即菩提",
        )
    }
    val lastRead = if (simplified) "上次读到" else "上次讀到"
    val back = "返回"
    val contentUnavailable = if (simplified) "经文暂时无法打开" else "經文暫時無法打開"
    val retry = if (simplified) "重试" else "重試"
    val share = "分享"
    val sharePreview = if (simplified) "分享预览" else "分享預覽"
    val shareImage = if (simplified) "分享图片" else "分享圖片"
    val shareText = "分享文字"
    val saveTextFile = "存文字"
    val copyText = if (simplified) "复制" else "複製"
    val cancel = "取消"
    val imageExportFailed = if (simplified) "图片生成失败，请重试" else "圖片產生失敗，請重試"
    val shareFailed = if (simplified) "无法打开分享，请重试" else "無法開啟分享，請重試"
    val textSaveFailed = if (simplified) "文件保存失败，请重试" else "檔案儲存失敗，請重試"
    val textSaved = if (simplified) "文件已保存" else "檔案已儲存"
    val textCopied = if (simplified) "全文已复制" else "全文已複製"
    val textCopyFailed = if (simplified) "复制失败，请重试" else "複製失敗，請重試"

    fun volumeCount(count: Int): String = "全文 $count 卷"

    fun noSearchResults(query: String): String = if (simplified) {
        "没有找到“$query”"
    } else {
        "沒有找到「$query」"
    }

    fun searchResultCount(count: Int, hasMore: Boolean): String = if (simplified) {
        if (hasMore) "显示前 $count 项结果" else "找到 $count 项结果"
    } else {
        if (hasMore) "顯示前 $count 項結果" else "找到 $count 項結果"
    }

    fun fontSizeState(level: Int): String = if (simplified) {
        "第 ${level + 1} 级，共 5 级"
    } else {
        "第 ${level + 1} 級，共 5 級"
    }

    fun shareCharacterCount(count: Int): String = if (simplified) {
        "全文 $count 字"
    } else {
        "全文 $count 字"
    }

    fun imageExportProgress(completed: Int, total: Int?): String = if (total == null) {
        if (simplified) "正在生成图片" else "正在產生圖片"
    } else if (simplified) {
        "正在生成图片 $completed / $total"
    } else {
        "正在產生圖片 $completed / $total"
    }

    fun themeName(theme: ThemePreference): String = when (theme) {
        ThemePreference.SYSTEM -> if (simplified) "跟随系统" else "跟隨系統"
        ThemePreference.LIGHT -> if (simplified) "浅色" else "淺色"
        ThemePreference.DARK -> "深色"
    }

    fun localeName(locale: String): String = when (locale) {
        "zh-Hans" -> "简体中文"
        "zh-Hant" -> "繁體中文"
        else -> locale
    }
}
