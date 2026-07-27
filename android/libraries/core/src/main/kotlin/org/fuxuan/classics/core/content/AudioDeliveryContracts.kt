package org.fuxuan.classics.core.content

enum class AudioDeliveryPlatform(val contractValue: String) {
    IOS("ios"),
    ANDROID("android"),
    ;

    companion object {
        fun fromContract(value: String): AudioDeliveryPlatform =
            entries.firstOrNull { it.contractValue == value }
                ?: error("invalid audio delivery platform: $value")
    }
}

enum class ProductPlatformState(val contractValue: String) {
    PRODUCTION("production"),
    DEVELOPMENT("development"),
    PLANNED("planned"),
    RETIRED("retired"),
    ;

    val isActive: Boolean
        get() = this == PRODUCTION || this == DEVELOPMENT

    companion object {
        fun fromContract(value: String): ProductPlatformState =
            entries.firstOrNull { it.contractValue == value }
                ?: error("invalid product platform state: $value")
    }
}

enum class AudioProviderRole(val contractValue: String) {
    PRIMARY("primary"),
    FALLBACK("fallback"),
    ;

    companion object {
        fun fromContract(value: String): AudioProviderRole =
            entries.firstOrNull { it.contractValue == value }
                ?: error("invalid audio provider role: $value")
    }
}

enum class HttpsAudioActivation(val contractValue: String) {
    ALWAYS("always"),
    USER_PLAYBACK_AFTER_PRIMARY_FAILURE_OR_STALL(
        "user-playback-after-primary-failure-or-stall",
    ),
    ;

    companion object {
        fun fromContract(value: String): HttpsAudioActivation =
            entries.firstOrNull { it.contractValue == value }
                ?: error("invalid HTTPS audio activation: $value")
    }
}

enum class AudioByteRangeSupport(val contractValue: String) {
    SUPPORTED("supported"),
    UNSUPPORTED("unsupported"),
    UNVERIFIED("unverified"),
    ;

    companion object {
        fun fromContract(value: String): AudioByteRangeSupport =
            entries.firstOrNull { it.contractValue == value }
                ?: error("invalid audio byte-range support: $value")
    }
}

sealed interface AudioDeliveryProvider {
    val providerID: String
    val role: AudioProviderRole
    val minimumOSMajor: Int
}

data class AppleOnDemandAudioProvider(
    override val providerID: String,
    override val role: AudioProviderRole,
    override val minimumOSMajor: Int,
    val maximumOSMajor: Int,
    val tagTemplate: String,
    val bundleFileTemplate: String,
) : AudioDeliveryProvider {
    init {
        requireValidProviderIdentity(providerID, minimumOSMajor)
        require(role == AudioProviderRole.PRIMARY) { "Apple ODR provider must be primary" }
        require(maximumOSMajor >= minimumOSMajor) { "Apple ODR OS range is invalid" }
        require(tagTemplate == "{legacyTrackID}") { "unsupported Apple ODR tag template" }
        require(bundleFileTemplate == "{fileName}") {
            "unsupported Apple ODR bundle file template"
        }
    }
}

data class AppleManagedAudioProvider(
    override val providerID: String,
    override val role: AudioProviderRole,
    override val minimumOSMajor: Int,
    val assetPackIDTemplate: String,
    val relativePathTemplate: String,
    val downloadPolicy: String,
    val platforms: List<String>,
) : AudioDeliveryProvider {
    init {
        requireValidProviderIdentity(providerID, minimumOSMajor)
        require(role == AudioProviderRole.PRIMARY) {
            "Apple managed background asset provider must be primary"
        }
        require(APPLE_ASSET_PACK_TEMPLATE_PATTERN.matches(assetPackIDTemplate)) {
            "invalid Apple managed asset pack template"
        }
        require(APPLE_RELATIVE_PATH_TEMPLATE_PATTERN.matches(relativePathTemplate)) {
            "invalid Apple managed relative path template"
        }
        require(downloadPolicy == "onDemand") { "unsupported Apple download policy" }
        require(platforms == listOf("iOS")) { "unsupported Apple managed platforms" }
    }
}

data class HttpsAudioProvider(
    override val providerID: String,
    override val role: AudioProviderRole,
    override val minimumOSMajor: Int,
    val baseURLConfigurationKey: String,
    val enabledConfigurationKey: String?,
    val activation: HttpsAudioActivation,
    val stallTimeoutConfigurationKey: String?,
    val byteRangeSupport: AudioByteRangeSupport,
    val prefetchAllowed: Boolean,
) : AudioDeliveryProvider {
    init {
        requireValidProviderIdentity(providerID, minimumOSMajor)
        require(baseURLConfigurationKey.isNotBlank()) {
            "HTTPS audio base URL configuration key must not be blank"
        }
        require(enabledConfigurationKey == null || enabledConfigurationKey.isNotBlank()) {
            "HTTPS audio enabled configuration key must not be blank"
        }
        require(stallTimeoutConfigurationKey == null || stallTimeoutConfigurationKey.isNotBlank()) {
            "HTTPS audio stall timeout configuration key must not be blank"
        }
        if (role == AudioProviderRole.PRIMARY) {
            require(activation == HttpsAudioActivation.ALWAYS) {
                "primary HTTPS audio provider must always be active"
            }
        }
        if (activation == HttpsAudioActivation.USER_PLAYBACK_AFTER_PRIMARY_FAILURE_OR_STALL) {
            require(role == AudioProviderRole.FALLBACK) {
                "failure-activated HTTPS audio provider must be a fallback"
            }
            require(enabledConfigurationKey != null && stallTimeoutConfigurationKey != null) {
                "failure-activated HTTPS audio provider requires enable and timeout keys"
            }
        }
    }
}

data class AudioDelivery(
    val schemaVersion: Int,
    val productID: String,
    val platform: AudioDeliveryPlatform,
    val deliveryVersion: String,
    val state: ProductPlatformState,
    val artifactManifestPath: String,
    val selectedRenditionID: String?,
    val providers: List<AudioDeliveryProvider>,
    val releaseBlockers: List<String>,
) {
    init {
        require(schemaVersion == 1) {
            "unsupported audio delivery schemaVersion: $schemaVersion"
        }
        require(AUDIO_DELIVERY_PRODUCT_ID_PATTERN.matches(productID)) {
            "invalid audio delivery productID: $productID"
        }
        require(AUDIO_DELIVERY_VERSION_PATTERN.matches(deliveryVersion)) {
            "invalid audio deliveryVersion"
        }
        require(artifactManifestPath.isSafeAudioDeliveryPath()) {
            "audio artifact manifest must be a safe relative path"
        }
        require(
            selectedRenditionID == null ||
                AUDIO_DELIVERY_IDENTIFIER_PATTERN.matches(selectedRenditionID),
        ) {
            "invalid selected audio rendition ID"
        }
        require(providers.map(AudioDeliveryProvider::providerID).toSet().size == providers.size) {
            "audio delivery provider IDs must be unique"
        }
        require(releaseBlockers.all(String::isNotBlank)) {
            "audio delivery release blockers must not be blank"
        }
        require(releaseBlockers.toSet().size == releaseBlockers.size) {
            "audio delivery release blockers must be unique"
        }
        if (state.isActive) {
            require(selectedRenditionID != null) {
                "active audio delivery requires a selected rendition"
            }
            require(providers.isNotEmpty()) { "active audio delivery requires a provider" }
            require(providers.any { it.role == AudioProviderRole.PRIMARY }) {
                "active audio delivery requires a primary provider"
            }
        }
        if (state == ProductPlatformState.PLANNED) {
            require(releaseBlockers.isNotEmpty()) {
                "planned audio delivery requires release blockers"
            }
        }
    }
}

private val AUDIO_DELIVERY_PRODUCT_ID_PATTERN = Regex("^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$")
private val AUDIO_DELIVERY_IDENTIFIER_PATTERN = Regex("^[a-z][a-z0-9.-]*$")
private val AUDIO_DELIVERY_VERSION_PATTERN = Regex("^[A-Za-z0-9][A-Za-z0-9._-]*$")
private val APPLE_ASSET_PACK_TEMPLATE_PATTERN = Regex("^[A-Za-z0-9.-]+[{]legacyTrackID[}]$")
private val APPLE_RELATIVE_PATH_TEMPLATE_PATTERN =
    Regex("^[A-Za-z0-9_-]+/[{]fileName[}]$")

private fun requireValidProviderIdentity(providerID: String, minimumOSMajor: Int) {
    require(AUDIO_DELIVERY_IDENTIFIER_PATTERN.matches(providerID)) {
        "invalid audio providerID: $providerID"
    }
    require(minimumOSMajor > 0) { "audio provider minimum OS major must be positive" }
}

private fun String.isSafeAudioDeliveryPath(): Boolean {
    val segments = split('/')
    return isNotBlank() &&
        !startsWith('/') &&
        '\\' !in this &&
        segments.all { it.isNotBlank() && it != "." && it != ".." }
}
