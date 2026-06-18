import SharingCryptoService

/// A collection of requested mDL attributes, each associated with
/// an `intentToRetain` flag. This model maps directly to the ISO-defined `ItemsRequest`structure.
///
/// At least one of `mdlAttributes` or `gbMdlAttributes` must be non-empty.
public struct AttributeGroup: Equatable, Sendable {

    /// ISO 18013-5 namespace identifiers.
    public enum Namespace: String, Sendable {
        case standard = "org.iso.18013.5.1"
        case gb = "org.iso.18013.5.1.GB"
    }

    /// A standard namespace attribute paired with its `intentToRetain` flag.
    public struct MDLRequestedAttribute: Equatable, Sendable {
        public let attribute: MDLAttribute
        public let intentToRetain: Bool

        public init(attribute: MDLAttribute, intentToRetain: Bool) {
            self.attribute = attribute
            self.intentToRetain = intentToRetain
        }
    }

    /// A GB namespace attribute paired with its `intentToRetain` flag.
    public struct GBRequestedAttribute: Equatable, Sendable {
        public let attribute: GBMDLAttribute
        public let intentToRetain: Bool

        public init(attribute: GBMDLAttribute, intentToRetain: Bool) {
            self.attribute = attribute
            self.intentToRetain = intentToRetain
        }
    }

    /// The document type this group of attributes belongs to.
    public let docType: DocType

    /// Attributes from the standard namespace (org.iso.18013.5.1).
    public let mdlAttributes: [MDLRequestedAttribute]

    /// Attributes from the UK domestic namespace (org.iso.18013.5.1.GB).
    public let gbMdlAttributes: [GBRequestedAttribute]

    /// Initialises an `AttributeGroup`.
    /// - Parameters:
    ///   - docType: The document type for this request.
    ///   - mdlAttributes: Standard namespace attributes with `intentToRetain` flags.
    ///   - gbMdlAttributes: GB namespace attributes with `intentToRetain` flags.
    /// - Returns: `nil` if both collections are empty.
    public init?(
        docType: DocType = .mdl,
        mdlAttributes: [MDLRequestedAttribute] = [],
        gbMdlAttributes: [GBRequestedAttribute] = []
    ) {
        guard !mdlAttributes.isEmpty || !gbMdlAttributes.isEmpty else { return nil }
        self.docType = docType
        self.mdlAttributes = mdlAttributes
        self.gbMdlAttributes = gbMdlAttributes
    }
}
