import Logging

public enum LoggingEvents: String, LoggableEvent {
    
    // Common
    case failedWithError = "Failed with error"
    case cancelledConfirmationSessionAlive = "Cancel confirmation dismissed — session remains active"
    case unableToOpenSettings = "Unable to open settings"
    case pheripheralDisconnected = "Peripheral disconnected"
    case bleSessionTerminatedGattEnd = "BLE session terminated successfully via GATT End command"
    case stateTransitioned = "State transitioned to:"
    case terminationMessageSent = "Termination message sent"
    
    // Consent
    case consentDenyButtonTapped  = "Deny button tapped — session state: awaitingUserConsent"
    case consentDenialCancelled  = "Denial cancelled — session state: awaitingUserConsent"
    
    // Holder Container
    case navigateToSettings = "Tapped navigate to settings"
    
    // VerifierContainer
    case verifierCancelAlertSessionDown = "Cancel confirmation confirmed — cancelling session"
    
    // BLECentralTransport
    case scanningStartedForUUID = "Scanning started for service UUID:"
    case scanningStopped = "Scanning stopped"
    case failedToWriteStartState = "Failed to write 'Start' state"
    case mtuNegotiated = "MTU negotiated:"
    case sessionNowReady = "Session is now active, ready to send a request."
    case calculatedChunkSize = "Calculated chunk size:"
    case payloadOfDataWithHeader = "Payload of data with 0x01 header sent:"
    case finalPayloadOfData = "Final payload of data with 0x00 header sent:"
    
    case gattEndWritten = "GATT End written to State characteristic:"
    case discoveredPeripheralUUID = "Discovered peripheral advertising service UUID:"
    
    case successfullyConnectedToPeripheral = "Successfully connected to peripheral:"
    case failedToSubscribe = "Failed to subscribe to characteristics"
    case subscribedToSession = "Subscribed to session characteristics."
    case stateUpdateReceived = "State update received"
    
    case receivedBytes = "Received Bytes:"
    case partialMessageWithFurtherBytesExpected = "Partial message recieved with further bytes expected"
    case fullBytesReceived = "Full message received:"
    
    // BLEPeripheralTransport
    case gattNotifiedStateCharacteristics = "GATT Notified 'State' characteristic with:"
    case failedToNotifyGattEnd = "Failed to notify GATT end command"
    case peripheralDidAddService = "PeripheralManager did add service for peripheral"
    case advertisingStarted = "Advertising started:"
    case centralDidSubscribeCharactertic = "Central did subscribe the characteristc for peripheral"
    case startRequestReceived = "Start request received"
    case gattEndReceivedWriteRequest = "GATT received write request 0x02 on State"
    
    case discoveredCharacteristics = "Discovered characteristics:"
    case readerAuthIgnored = "Optional 'readerAuth' field was present, but ignored"
    
    case skReaderKeyGenerated = "SKReader key generated"
    case skDeviceKeyGenerated = "SKDevice key generated"
    case payloadDecrypted = "Payload was successfully decrypted"
    case issueDecryptingData = "There was an issue decrypting the data:"
    
    // Session Encryption
    case ivLog = "IV:"
    case messageCounterBytes = "Message counter bytes"
    
    // Crypto Service
    case sessionTranscriptSuccessful = "SessionTranscript constructed successfully:"
    case errorConstructingDeviceAuthBytes = "error constructing DeviceAuthenticationBytes"
    case sigStructConstructedSuccessfully = "Sig_structure constructed successfully:"
    case eReaderKeyBytes = "eReaderKeyBytes:"
    case base64eReaderKey = "base64 eReaderKeyCBOR:"
    case sessionTranscriptCBOR = "SessionTranscript CBOR:"
    case sessionTranscriptBytesConstructedSuccessfully = "SessionTranscriptBytes constructed successfully:"
    case sessionEstablishmentMessageConstructed = "SessionEstablishment message constructed"
    case deviceRequestedEncrypted = "DeviceRequest encrypted successfully"
    case decoderReceivedCompleteSessionData = "Decoder received complete SessionData message."
    
    // CredRequestHandler
    case sessionDataTermGetCredError = "SessionData termination initiated due to getCredentials error thrown"
    case sessionDataTermGetCredNoCredentials = "SessionData termination initiated due to getCredentials no credentials returned"
    case sessionDataTermMSOError = "SessionData termination initiated due to MSO decoding error"
    case sessionDataTermDocType = "SessionData termination initiated due to getCredentials no credentials of correct docType returned"
    case credentialMatchesDocType = "provided credential matches DeviceRequest docType"
    
    // Holder
    case holderSessionStarted = "Holder Presentation Session started"
    case prepDevSignedResponse = "prepDevSignedResponse returned"
    case inactivityTimeoutHolder = "Inactivity timeout fired — sending GATT End From Holder"
    case holderPresenationSessionEnded = "Holder Presentation Session ended"
    case timerStartedForHolder = "Timer started for Holder"
    case missingTransitionEntry = "Error: Missing transition entry for"
    
    // Verifier
    case verifierSessionStarted = "Verifier session started"
    case verifierSessionEnded = "Verifier session ended"
    case encryptionErrorMalformedSKReader = "Encryption error due to malformed SKReader key"
    case deviceRequest = "DeviceRequest:"
    case sessionDataDecodedSuccessfully = "SessionData decoded successfully."
    case deviceResponseParsedSuccessfully = "DeviceResponse parsed successfully."
    case deviceResponseValidationFailed = "DeviceResponse validation failed:"
    case sessionDecyrptionError = "Session decryption error"
    case inactivityTimerGattEndFromVerifier = "Inactivity timeout fired — sending GATT End From Verifier"
    
    case centralManagerPoweredOn = "Central manager powered on."
    case timerStartedForVerifier = "Timer started for Verifier"
    case peripheralConnectionInitiated = "Peripheral discovered, connection initiated."
    case ignoringInboundBLEData = "Ignoring inbound BLE data"
}

/*
OSLoggingService.shared.logEvent(LoggingEvents.)
OSLoggingService.shared.logEvent(LoggingEvents.XXX, parameters: ["XXX": XXX])
 */
