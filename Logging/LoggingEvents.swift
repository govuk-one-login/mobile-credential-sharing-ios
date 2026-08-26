import Logging

public enum LoggingEvents: String, LoggableEvent {
    
    // Common
    case failedWithError = "Failed with error"
    case cancelledConfirmationSessionAlive = "Cancel confirmation dismissed — session remains active"
    case unableToOpenSettings = "Unable to open settings"
    case pheripheralDisconnected = "Peripheral disconnected"
    
    
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
    case bleSessionTerminatedGattEnd = "BLE session terminated successfully via GATT End command"
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
}



/*
OSLoggingService.shared.logEvent(LoggingEvents.
OSLoggingService.shared.logEvent(LoggingEvents.XXX, parameters: ["XXX": XXX])
 */
