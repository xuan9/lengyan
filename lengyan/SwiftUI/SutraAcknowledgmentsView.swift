import Foundation
import SwiftUI

struct ThirdPartyNoticeCatalog: Decodable {
    enum CatalogError: Error {
        case missingResource
        case invalidDocument
    }

    let schemaVersion: Int
    let inventorySHA256: String
    let components: [ThirdPartyNoticeComponent]
    let licenses: [ThirdPartyLicense]
    let platform: String

    static func load() throws -> Self {
        try load(bundle: Bundle(for: ThirdPartyNoticeBundleToken.self))
    }

    static func load(bundle: Bundle) throws -> Self {
        guard let url = bundle.url(
            forResource: "third-party-notices",
            withExtension: "json"
        ) else {
            throw CatalogError.missingResource
        }
        return try decode(Data(contentsOf: url))
    }

    static func decode(_ data: Data) throws -> Self {
        let document = try JSONDecoder().decode(Self.self, from: data)
        let licenseIDs = document.licenses.map(\.licenseID)
        let componentIDs = document.components.map(\.componentID)
        let validHash = document.inventorySHA256.range(
            of: "^[0-9a-f]{64}$",
            options: .regularExpression
        ) != nil
        guard document.schemaVersion == 1,
              document.platform == "ios",
              validHash,
              !document.components.isEmpty,
              !document.licenses.isEmpty,
              Set(licenseIDs).count == licenseIDs.count,
              Set(componentIDs).count == componentIDs.count,
              document.components.allSatisfy({ component in
                  !component.displayName.isEmpty
                      && !component.versions.isEmpty
                      && component.versions.allSatisfy { !$0.isEmpty }
                      && component.moduleCount > 0
                      && licenseIDs.contains(component.licenseID)
                      && isCanonicalHTTPS(component.homepage)
              }),
              document.licenses.allSatisfy({ license in
                  !license.name.isEmpty
                      && !license.text.isEmpty
                      && isCanonicalHTTPS(license.canonicalURL)
              }) else {
            throw CatalogError.invalidDocument
        }
        return document
    }

    private static func isCanonicalHTTPS(_ value: String) -> Bool {
        guard let url = URL(string: value) else { return false }
        return url.scheme == "https" && url.absoluteString == value
    }
}

struct ThirdPartyNoticeComponent: Decodable {
    let componentID: String
    let displayName: String
    let versions: [String]
    let moduleCount: Int
    let licenseID: String
    let homepage: String
    let notice: String
}

struct ThirdPartyLicense: Decodable {
    let licenseID: String
    let name: String
    let canonicalURL: String
    let text: String
}

private final class ThirdPartyNoticeBundleToken: NSObject {}

struct SutraAcknowledgmentsView: View {
    @Environment(\.presentationMode) var presentationMode
    private let thirdPartyNotices: ThirdPartyNoticeCatalog?

    init(thirdPartyNotices: ThirdPartyNoticeCatalog? = try? ThirdPartyNoticeCatalog.load()) {
        self.thirdPartyNotices = thirdPartyNotices
    }

    private var goldColor: Color {
        Color(SutraDesignTokens.shared.color(for: .decorativeGold))
    }

    private var textPrimary: Color {
        Color(SutraDesignTokens.shared.color(for: .textPrimary))
    }

    private var textSecondary: Color {
        Color(SutraDesignTokens.shared.color(for: .textSecondary))
    }

    private var textTertiary: Color {
        Color(SutraDesignTokens.shared.color(for: .textTertiary))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // MARK: 开篇 — 缘起
                Text(L10n.str("acknowledgments_intro"))
                    .font(SutraTypographyBridge.uiBody(weight: .regular))
                    .foregroundColor(textSecondary)
                    .tracking(3)
                    .padding(.top, 48)
                    .padding(.bottom, 32)

                // MARK: 来源 — 逐一致敬
                sourceCard(
                    title: L10n.str("acknowledgments_text_title"),
                    text: L10n.str("acknowledgments_text_body")
                )

                goldDivider

                sourceCard(
                    title: L10n.str("acknowledgments_audio_title"),
                    text: L10n.str("acknowledgments_audio_body")
                )

                goldDivider

                sourceCard(
                    title: L10n.str("acknowledgments_image_title"),
                    text: L10n.str("acknowledgments_image_body")
                )

                goldDivider

                openSourceSection

                goldDivider

                // MARK: 收束 — 致敬
                VStack(spacing: 12) {
                    Text(L10n.str("acknowledgments_footer"))
                        .font(SutraTypographyBridge.uiCaption(weight: .light))
                        .foregroundColor(textTertiary)
                        .tracking(4)

                    Text(L10n.str("footer_homage"))
                        .font(SutraTypographyBridge.uiCaption(weight: .medium))
                        .foregroundColor(goldColor.opacity(0.65))
                        .tracking(3)
                }
                .padding(.top, 40)
                .padding(.bottom, 48)
            }
            .padding(.horizontal, 28)
        }
        .background(Color(SutraDesignTokens.shared.color(for: .background)).edgesIgnoringSafeArea(.all))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 开源软件

    private var openSourceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.str("acknowledgments_software_title"))
                .font(.headline)
                .foregroundColor(textPrimary)

            Text(L10n.str("acknowledgments_software_intro"))
                .font(.body)
                .foregroundColor(textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let thirdPartyNotices {
                Text(
                    localizedFormat(
                        "acknowledgments_software_summary_format",
                        thirdPartyNotices.components.count,
                        thirdPartyNotices.components.reduce(0) { $0 + $1.moduleCount }
                    )
                )
                .font(.subheadline)
                .foregroundColor(textTertiary)

                ForEach(thirdPartyNotices.components, id: \.componentID) { component in
                    softwareComponent(component)
                }

                Text(L10n.str("acknowledgments_software_terms_title"))
                    .font(.headline)
                    .foregroundColor(textPrimary)
                    .padding(.top, 8)

                ForEach(thirdPartyNotices.licenses, id: \.licenseID) { license in
                    softwareLicense(license)
                }
            } else {
                Text(L10n.str("acknowledgments_software_unavailable"))
                    .font(.body)
                    .foregroundColor(Color.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
        .accessibilityIdentifier("acknowledgments.open-source")
    }

    private func softwareComponent(_ component: ThirdPartyNoticeComponent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(component.displayName)
                .font(.headline)
                .foregroundColor(textPrimary)

            Text(
                localizedFormat(
                    "acknowledgments_software_versions_format",
                    component.versions.joined(separator: ", ")
                )
            )
            Text(
                localizedFormat(
                    "acknowledgments_software_modules_format",
                    component.moduleCount
                )
            )
            Text(
                localizedFormat(
                    "acknowledgments_software_license_format",
                    component.licenseID
                )
            )

            if !component.notice.isEmpty {
                Text(component.notice)
                    .foregroundColor(textSecondary)
            }

            if let url = URL(string: component.homepage) {
                Link(destination: url) {
                    Label(
                        L10n.str("acknowledgments_software_homepage"),
                        systemImage: "arrow.up.right"
                    )
                }
                .font(.body)
                .foregroundColor(goldColor)
            }
        }
        .font(.subheadline)
        .foregroundColor(textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .accessibilityIdentifier("acknowledgments.component.\(component.componentID)")
    }

    private func softwareLicense(_ license: ThirdPartyLicense) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(license.name)
                .font(.headline)
                .foregroundColor(textPrimary)

            if let url = URL(string: license.canonicalURL) {
                Link(destination: url) {
                    Label(
                        L10n.str("acknowledgments_software_license_page"),
                        systemImage: "arrow.up.right"
                    )
                }
                .font(.body)
                .foregroundColor(goldColor)
            }

            Text(license.text.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.footnote)
                .foregroundColor(textSecondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .accessibilityIdentifier("acknowledgments.license.\(license.licenseID)")
    }

    private func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: L10n.str(key), arguments: arguments)
    }

    // MARK: - 来源卡片

    private func sourceCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(SutraTypographyBridge.uiCaption(weight: .medium))
                .foregroundColor(textSecondary)
                .tracking(3)

            Text(text)
                .font(SutraTypographyBridge.uiBody(weight: .regular))
                .foregroundColor(textPrimary)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }

    // MARK: - 金色分隔线

    private var goldDivider: some View {
        Rectangle()
            .fill(goldColor.opacity(0.15))
            .frame(height: 0.5)
            .padding(.horizontal, 40)
    }
}
