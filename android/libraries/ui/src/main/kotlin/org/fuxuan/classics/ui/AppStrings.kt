package org.fuxuan.classics.ui

import java.time.LocalDate
import org.fuxuan.classics.core.content.DocumentedSource
import org.fuxuan.classics.core.content.DocumentedSourceRole
import org.fuxuan.classics.core.content.SourceApprovalStatus
import org.fuxuan.classics.core.content.SourceReleaseEligibility
import org.fuxuan.classics.core.content.SourceReviewStatus
import org.fuxuan.classics.core.content.SourceRightsStatus
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
    val desktopWidget = if (simplified) "桌面组件" else "桌面組件"
    val todayReadingWidget = if (simplified) "今日读经" else "今日讀經"
    val widgetAdd = if (simplified) "添加到桌面" else "加入桌面"
    val widgetAdded = if (simplified) "已添加，可再次添加" else "已加入，可再次加入"
    val widgetOpenGuide = if (simplified) "查看添加步骤" else "查看加入步驟"
    val widgetGuideDone = "知道了"
    val dailyPractice = if (simplified) "每日修习" else "每日修習"
    val dailyReminder = if (simplified) "每日读经提醒" else "每日讀經提醒"
    val reminderTime = if (simplified) "提醒时间" else "提醒時間"
    val enabledState = if (simplified) "已开启" else "已開啟"
    val disabledState = if (simplified) "已关闭" else "已關閉"
    val notificationPermissionDenied = if (simplified) {
        "未开启通知权限，提醒保持关闭"
    } else {
        "未開啟通知權限，提醒保持關閉"
    }
    val about = if (simplified) "关于" else "關於"
    val sourceInformation = if (simplified) "来源说明" else "來源說明"
    val privacy = if (simplified) "隐私" else "隱私"
    val privacySettingsSubtitle = if (simplified) "本机数据与网络说明" else "本機資料與網路說明"
    val sourceRecords = if (simplified) "资料记录" else "資料記錄"
    val textAccuracy = if (simplified) "文字准确性" else "文字準確性"
    val distributionRights = if (simplified) "使用与发行权利" else "使用與發行權利"
    val sourceInstitutionLabel = if (simplified) "机构" else "機構"
    val sourceIdentifierLabel = if (simplified) "典籍编号" else "典籍編號"
    val sourceAttributionLabel = if (simplified) "来源标注" else "來源標註"
    val sourceRetrievedLabel = if (simplified) "记录日期" else "記錄日期"
    val openSourcePage = if (simplified) "查看资料" else "查看資料"
    val openRightsPage = if (simplified) "查看权利说明" else "查看權利說明"
    val privacyLocalTitle = if (simplified) "本机数据" else "本機資料"
    val privacyLocalBody = if (simplified) {
        "阅读进度、收藏、提醒和显示设置保存在本机。阅读、搜索和收藏无需注册账户。"
    } else {
        "閱讀進度、收藏、提醒和顯示設定保存在本機。閱讀、搜尋和收藏無需註冊帳戶。"
    }
    val privacyTrackingTitle = if (simplified) "广告与跟踪" else "廣告與追蹤"
    val privacyTrackingBody = if (simplified) {
        "App 不含广告、第三方分析或跨 App 跟踪。"
    } else {
        "App 不含廣告、第三方分析或跨 App 追蹤。"
    }
    val privacyNetworkTitle = if (simplified) "网络与分享" else "網路與分享"
    val privacyNetworkBody = if (simplified) {
        "分享内容时，数据由您选择的系统应用处理。打开完整隐私政策时，浏览器会访问支持网站。"
    } else {
        "分享內容時，資料由您選擇的系統 App 處理。打開完整隱私政策時，瀏覽器會存取支援網站。"
    }
    val privacyRemovalTitle = if (simplified) "卸载与备份" else "解除安裝與備份"
    val privacyRemovalBody = if (simplified) {
        "当前 Android 版本未启用云备份。卸载 App 会删除本机进度、收藏和设置。"
    } else {
        "目前 Android 版本未啟用雲端備份。解除安裝 App 會刪除本機進度、收藏和設定。"
    }
    val openFullPrivacyPolicy = if (simplified) "查看完整隐私政策" else "查看完整隱私政策"
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

    fun reminderSchedule(time: String): String = if (simplified) {
        "约在 $time 提醒"
    } else {
        "約在 $time 提醒"
    }

    fun widgetGuideTitle(widgetName: String): String = if (simplified) {
        "添加“$widgetName”"
    } else {
        "加入「$widgetName」"
    }

    fun widgetGuideSteps(productTitle: String): List<String> = if (simplified) {
        listOf(
            "长按桌面空白处。",
            "打开系统的桌面组件列表。",
            "找到《$productTitle》的“$todayReadingWidget”，拖到桌面。",
        )
    } else {
        listOf(
            "長按桌面空白處。",
            "打開系統的桌面組件列表。",
            "找到《$productTitle》的「$todayReadingWidget」，拖到桌面。",
        )
    }

    fun sourceSettingsSubtitle(
        status: SourceReviewStatus,
        eligibility: SourceReleaseEligibility,
    ): String = when {
        eligibility == SourceReleaseEligibility.ELIGIBLE -> {
            if (simplified) "来源与权利已审核" else "來源與權利已審核"
        }
        status == SourceReviewStatus.REJECTED -> {
            if (simplified) "来源审核未通过" else "來源審核未通過"
        }
        status == SourceReviewStatus.CANDIDATE -> {
            if (simplified) "来源与权利正在审核" else "來源與權利正在審核"
        }
        status == SourceReviewStatus.APPROVED -> {
            if (simplified) "仍有发行条件待完成" else "仍有發行條件待完成"
        }
        else -> {
            if (simplified) "来源与权利待核实" else "來源與權利待核實"
        }
    }

    fun sourceReviewTitle(status: SourceReviewStatus): String = when (status) {
        SourceReviewStatus.APPROVED -> if (simplified) "资料已审核" else "資料已審核"
        SourceReviewStatus.REJECTED -> if (simplified) "资料未通过审核" else "資料未通過審核"
        SourceReviewStatus.CANDIDATE -> if (simplified) "资料正在审核" else "資料正在審核"
        SourceReviewStatus.LEGACY_UNVERIFIED -> {
            if (simplified) "当前资料仍待核实" else "目前資料仍待核實"
        }
    }

    fun sourceReviewBody(
        status: SourceReviewStatus,
        eligibility: SourceReleaseEligibility,
        productTitle: String,
    ): String = when {
        eligibility == SourceReleaseEligibility.ELIGIBLE -> {
            if (simplified) {
                "《$productTitle》的底本、文字校对和使用与发行权利已按来源清单完成审核。"
            } else {
                "《$productTitle》的底本、文字校對和使用與發行權利已按來源清單完成審核。"
            }
        }
        status == SourceReviewStatus.LEGACY_UNVERIFIED -> if (simplified) {
            "此版本沿用现有 App 的经文与科判资料。正式底本、逐字校对和使用与发行权利尚未在来源清单中全部确认。"
        } else {
            "此版本沿用現有 App 的經文與科判資料。正式底本、逐字校對和使用與發行權利尚未在來源清單中全部確認。"
        }
        status == SourceReviewStatus.CANDIDATE -> if (simplified) {
            "来源清单中的资料仅为候选。正式底本、文字审核和使用与发行权利尚未全部批准。"
        } else {
            "來源清單中的資料僅為候選。正式底本、文字審核和使用與發行權利尚未全部批准。"
        }
        status == SourceReviewStatus.REJECTED -> if (simplified) {
            "来源资料未通过审核，此版本不具备发行条件，也不应视为已批准底本。"
        } else {
            "來源資料未通過審核，此版本不具備發行條件，也不應視為已批准底本。"
        }
        else -> if (simplified) {
            "来源资料已经审核，但文字准确性或使用与发行权利仍有未完成的发行条件。"
        } else {
            "來源資料已經審核，但文字準確性或使用與發行權利仍有未完成的發行條件。"
        }
    }

    fun sourceApproval(status: SourceApprovalStatus): String = when (status) {
        SourceApprovalStatus.PENDING -> if (simplified) "待审核" else "待審核"
        SourceApprovalStatus.APPROVED -> if (simplified) "已审核" else "已審核"
        SourceApprovalStatus.REJECTED -> if (simplified) "未通过" else "未通過"
    }

    fun documentedSourceTitle(source: DocumentedSource, productTitle: String): String =
        if (source.role == DocumentedSourceRole.LEGACY_RUNTIME_INPUT) {
            if (simplified) "《$productTitle》目前使用资料" else "《$productTitle》目前使用資料"
        } else {
            source.title
        }

    fun documentedSourceRole(role: DocumentedSourceRole): String = when (role) {
        DocumentedSourceRole.LEGACY_RUNTIME_INPUT -> {
            if (simplified) "当前 App 使用资料" else "目前 App 使用資料"
        }
        DocumentedSourceRole.CANONICAL_INPUT -> if (simplified) "正式底本" else "正式底本"
        DocumentedSourceRole.COLLATION_REFERENCE -> if (simplified) "校勘参考" else "校勘參考"
        DocumentedSourceRole.TRANSCRIPTION_BASE -> if (simplified) "录入底本" else "錄入底本"
        DocumentedSourceRole.TRANSLATION_REFERENCE -> if (simplified) "译本参考" else "譯本參考"
    }

    fun documentedSourceRoleNote(role: DocumentedSourceRole): String? =
        if (role == DocumentedSourceRole.COLLATION_REFERENCE) {
            if (simplified) {
                "仅用于校勘，不等于当前正文来源。"
            } else {
                "僅用於校勘，不等於目前正文來源。"
            }
        } else {
            null
        }

    fun sourceRights(status: SourceRightsStatus): String = when (status) {
        SourceRightsStatus.UNKNOWN -> if (simplified) "权利依据待核实" else "權利依據待核實"
        SourceRightsStatus.RESTRICTED_NONCOMMERCIAL -> {
            if (simplified) "非商业限制；商业使用需另行许可" else "非商業限制；商業使用需另行許可"
        }
        SourceRightsStatus.PUBLIC_DOMAIN -> if (simplified) "公有领域" else "公有領域"
        SourceRightsStatus.PRODUCT_LICENSE -> if (simplified) "产品许可" else "產品許可"
    }

    fun sourceMetadata(label: String, value: String): String = "$label：$value"

    fun sourceRetrievedDate(value: String): String = LocalDate.parse(value).let { date ->
        "${date.year}年${date.monthValue}月${date.dayOfMonth}日"
    }

    fun versionLabel(version: String): String = "版本 $version"

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
