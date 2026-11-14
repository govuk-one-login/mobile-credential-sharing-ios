import Foundation
import SwiftASN1
import X509

/// Result of validating a reader-auth leaf certificate.
enum ReaderAuthCertificateStatus: Equatable {
    /// A parseable, in-date certificate.
    case valid

    /// The build was not provisioned: the asset is an unreplaced CI placeholder, or is otherwise
    /// missing / unusable as an in-date X.509 certificate.
    case placeholder
}

/// Classifies the leaf certificate backing a ``ReaderAuthProfileOption`` so the UI can fail closed
/// when a DVS option has not been provisioned by the build pipeline.
///
/// Anything that is not a parseable, in-date X.509 certificate — including the committed
/// `DVS_PLACEHOLDER_CERTIFICATE_REPLACE_IN_CI` placeholder — is treated as ``placeholder`` so the
/// UI blocks verification against unprovisioned material.
struct ReaderAuthCertificateValidator {
    /// Sentinel embedded in the committed placeholder assets, replaced by the pipeline at build time.
    private static let placeholderSentinel = "DVS_PLACEHOLDER_CERTIFICATE_REPLACE_IN_CI"

    /// The instant used for the validity check. Defaults to now; tests inject a fixed instant.
    private let validationTime: Date

    /// The bundle the leaf assets are read from. Defaults to `.main`; tests inject a test bundle.
    private let bundle: Bundle

    init(validationTime: Date = Date(), bundle: Bundle = .main) {
        self.validationTime = validationTime
        self.bundle = bundle
    }

    /// Loads the leaf certificate asset for `option` and classifies it. Any load failure classifies
    /// as ``ReaderAuthCertificateStatus/placeholder`` so callers fail closed.
    func validate(_ option: ReaderAuthProfileOption) -> ReaderAuthCertificateStatus {
        guard let url = bundle.url(forResource: option.leafCertificateResource, withExtension: "der"),
              let bytes = try? Data(contentsOf: url) else {
            return .placeholder
        }
        return classify(bytes)
    }

    /// Classifies raw leaf certificate `bytes`. The first X.509 certificate is used, so a leaf-first
    /// chain buffer resolves to its leaf. Anything that is not a parseable, in-date certificate is
    /// treated as an unprovisioned placeholder so the UI fails closed.
    func classify(_ bytes: Data) -> ReaderAuthCertificateStatus {
        // Fast path: the committed placeholder carries a known sentinel string.
        if let text = String(data: bytes, encoding: .utf8), text.contains(Self.placeholderSentinel) {
            return .placeholder
        }

        // Use the first certificate in the (possibly multi-cert) leaf-first buffer.
        guard let leafDER = ReaderAuthProfileOption.splitDERCertificates(bytes).first,
              let certificate = try? Certificate(derEncoded: Array(leafDER)) else {
            return .placeholder
        }

        let isInDate = certificate.notValidBefore <= validationTime
            && validationTime <= certificate.notValidAfter
        return isInDate ? .valid : .placeholder
    }
}
