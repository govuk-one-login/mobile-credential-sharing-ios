import Foundation
import SharingCryptoService
@testable import SharingOrchestration
import SharingPrerequisiteGate
import Testing

@MainActor
@Suite("VerifierConfig Acceptance Criteria")
struct VerifierConfigTests {

    // MARK: Valid configuration with a single namespace starts the journey
    @Test("Single namespace config transitions to readyToScan")
    func singleNamespaceConfigStartsJourney() throws {
        // Given — single namespace AttributeGroup (mdlAttributes only, gbMdlAttributes empty)
        let attributeGroup = try #require(AttributeGroup(
            mdlAttributes: [
                .init(attribute: .familyName, intentToRetain: true),
                .init(attribute: .ageOver(18), intentToRetain: false)
            ],
            gbMdlAttributes: []
        ))
        let config = VerifierConfig(
            attributeRequest: attributeGroup,
            trustedIssuerCertificate: TestCertificate.issuer
        )

        let mockGate = MockPrerequisiteGate()
        mockGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockGate)
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate

        // When
        sut.startVerification(config: config)

        // Then — session transitions to readyToScan
        #expect(sut.session?.currentState == .readyToScan)
        #expect(delegate.stateToRender == .readyToScan)
    }

    @Test("Orchestration receives the supplied AttributeGroup")
    func singleNamespaceConfigRoutesAttributeGroupToOrchestration() throws {
        // Given
        let attributeGroup = try #require(AttributeGroup(
            mdlAttributes: [
                .init(attribute: .familyName, intentToRetain: true),
                .init(attribute: .ageOver(18), intentToRetain: false)
            ]
        ))
        let config = VerifierConfig(
            attributeRequest: attributeGroup,
            trustedIssuerCertificate: TestCertificate.issuer
        )

        let mockGate = MockPrerequisiteGate()
        mockGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockGate)

        // When
        sut.startVerification(config: config)

        // Then — the session's docRequest was built from the supplied AttributeGroup
        let session = try #require(sut.session as? VerifierSession)
        let expectedDocRequest = DocRequest(with: attributeGroup)
        #expect(session.docRequest == expectedDocRequest)
    }

    @Test("Verification component receives the trusted issuer root certificate")
    func singleNamespaceConfigRoutesCertificateToVerification() throws {
        // Given
        let attributeGroup = try #require(AttributeGroup(
            mdlAttributes: [
                .init(attribute: .portrait, intentToRetain: false)
            ]
        ))
        let config = VerifierConfig(
            attributeRequest: attributeGroup,
            trustedIssuerCertificate: TestCertificate.issuer
        )

        let mockGate = MockPrerequisiteGate()
        mockGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockGate)

        // When
        sut.startVerification(config: config)

        // Then — the session holds the supplied certificate
        let session = try #require(sut.session as? VerifierSession)
        #expect(session.trustedIssuerCertificate === TestCertificate.issuer)
    }

    // MARK: Valid configuration with both namespaces starts the journey
    @Test("Dual namespace config transitions to readyToScan")
    func dualNamespaceConfigStartsJourney() throws {
        // Given — both mdlAttributes and gbMdlAttributes populated
        let attributeGroup = try #require(AttributeGroup(
            mdlAttributes: [
                .init(attribute: .familyName, intentToRetain: true)
            ],
            gbMdlAttributes: [
                .init(attribute: .title, intentToRetain: false)
            ]
        ))
        let config = VerifierConfig(
            attributeRequest: attributeGroup,
            trustedIssuerCertificate: TestCertificate.issuer
        )

        let mockGate = MockPrerequisiteGate()
        mockGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockGate)
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate

        // When
        sut.startVerification(config: config)

        // Then — session transitions to readyToScan
        #expect(sut.session?.currentState == .readyToScan)
        #expect(delegate.stateToRender == .readyToScan)
    }

    @Test("Both namespace collections are preserved independently on the session")
    func dualNamespaceCollectionsPreservedIndependently() throws {
        // Given
        let mdlAttrs: [AttributeGroup.MDLRequestedAttribute] = [
            .init(attribute: .familyName, intentToRetain: true),
            .init(attribute: .portrait, intentToRetain: false)
        ]
        let gbAttrs: [AttributeGroup.GBRequestedAttribute] = [
            .init(attribute: .title, intentToRetain: false)
        ]
        let attributeGroup = try #require(AttributeGroup(
            mdlAttributes: mdlAttrs,
            gbMdlAttributes: gbAttrs
        ))
        let config = VerifierConfig(
            attributeRequest: attributeGroup,
            trustedIssuerCertificate: TestCertificate.issuer
        )

        let mockGate = MockPrerequisiteGate()
        mockGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockGate)

        // When
        sut.startVerification(config: config)

        // Then — the DocRequest preserves both namespace collections
        let session = try #require(sut.session as? VerifierSession)
        let docRequest = try #require(session.docRequest)
        let expectedDocRequest = DocRequest(with: attributeGroup)
        #expect(docRequest == expectedDocRequest)

        // Also verify the config's attributeRequest preserves both collections
        #expect(config.attributeRequest.mdlAttributes == mdlAttrs)
        #expect(config.attributeRequest.gbMdlAttributes == gbAttrs)
    }

    // MARK: - Empty attribute request prevents journey start
    @Test("AttributeGroup with both empty collections returns nil")
    func emptyAttributeGroupReturnsNil() {
        // Given / When
        let group = AttributeGroup(mdlAttributes: [], gbMdlAttributes: [])

        // Then
        #expect(group == nil)
    }

    @Test("No VerifierConfig can be constructed without a valid AttributeGroup")
    func noVerifierConfigWithoutValidAttributeGroup() {
        // Given — attempting to construct an AttributeGroup with empty collections
        let group = AttributeGroup(mdlAttributes: [], gbMdlAttributes: [])

        // Then — group is nil, so VerifierConfig cannot be constructed
        #expect(group == nil)
        // VerifierConfig's init requires a non-optional AttributeGroup,
        // so the failable init on AttributeGroup is the gatekeeper.
    }

    // MARK: - Each journey requires a fresh configuration
    @Test("After journey completes, SDK holds no reference to previous configuration")
    func noReferenceAfterJourneyCompletes() throws {
        // Given
        let attributeGroup = try #require(AttributeGroup(
            mdlAttributes: [.init(attribute: .portrait, intentToRetain: false)]
        ))
        let config = VerifierConfig(
            attributeRequest: attributeGroup,
            trustedIssuerCertificate: TestCertificate.issuer
        )

        let mockGate = MockPrerequisiteGate()
        mockGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockGate)
        sut.startVerification(config: config)

        // When — journey is cancelled (simulating completion/failure)
        sut.cancelVerification()

        // Then — session is nil, no reference to previous config
        #expect(sut.session == nil)
    }

    @Test("Starting a new journey after completion uses a new config instance")
    func newJourneyUsesNewConfigInstance() throws {
        // Given
        let attributeGroup1 = try #require(AttributeGroup(
            mdlAttributes: [.init(attribute: .portrait, intentToRetain: false)]
        ))
        let config1 = VerifierConfig(
            attributeRequest: attributeGroup1,
            trustedIssuerCertificate: TestCertificate.issuer
        )

        let attributeGroup2 = try #require(AttributeGroup(
            mdlAttributes: [.init(attribute: .familyName, intentToRetain: true)]
        ))
        let config2 = VerifierConfig(
            attributeRequest: attributeGroup2,
            trustedIssuerCertificate: TestCertificate.issuer
        )

        let mockGate = MockPrerequisiteGate()
        mockGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockGate)

        // First journey
        sut.startVerification(config: config1)
        let firstSession = sut.session as? VerifierSession
        sut.cancelVerification()

        // When — new journey with different config
        sut.startVerification(config: config2)
        let secondSession = try #require(sut.session as? VerifierSession)

        // Then — new session uses the new config's attribute group
        let expectedDocRequest = DocRequest(with: attributeGroup2)
        #expect(secondSession.docRequest == expectedDocRequest)
        #expect(firstSession !== secondSession)
    }
}
