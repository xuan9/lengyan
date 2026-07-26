package org.fuxuan.classics.ui

import org.fuxuan.classics.core.persistence.ThemePreference

internal class AppStrings(locale: String) {
    private val simplified = locale == "zh-Hans"

    val startReading = if (simplified) "开始阅读" else "開始閱讀"
    val continueReading = if (simplified) "继续阅读" else "繼續閱讀"
    val reading = if (simplified) "读经" else "讀經"
    val chooseVolume = if (simplified) "选择卷目" else "選擇卷目"
    val volumes = "卷目"
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

    fun volumeCount(count: Int): String = "全文 $count 卷"

    fun noSearchResults(query: String): String = if (simplified) {
        "没有找到“$query”"
    } else {
        "沒有找到「$query」"
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
