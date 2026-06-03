import Foundation

// MARK: - Handle Event Logic
extension HolderOrchestrator {
    /// Handles each event as it is fired, listed in order for readablitity
    func handleEvent(_ event: HolderOrchestratorEvent) {
        switch event {
        case .started:
            performPreflightChecks()

        case .prerequisitesMet:
            prepareEngagement()

        case .advertisingStarted:
            presentQRCode()

        case .bluetoothFailed(let error):
            delegate?.orchestrator(
                didUpdateState: .failed(.generic(error.errorDescription ?? "Unknown error"))
            )

        case .connectionEstablished:
            connectionDidConnect()

        case .dataReceived(let data):
            didReceive(data)

        case .credentialValidated(let deviceRequest):
            filterIssuerSigned(for: deviceRequest)

        case .userApproved:
            Task {
                await prepareDeviceSignedResponse()
                handleEvent(.responseReady)
            }

        case .responseReady:
            assembleAndEncryptResponse()

        case .sendData(let sessionData):
            encodeAndSend(sessionData) {
                /// Callback to trigger transition to `.success` state when response sent successfully
                self.transitionToSuccess()
            }

        case .userDenied:
            handleTermination(
                with: nil,
                deviceResponseStatus: .ok
            )

            transitionToCancel()
            tearDownSession(andNotify: true)

        case .sendCompleted:
            let completion = sendCompletion
            sendCompletion = nil
            completion?()

        case .receivedEndRequest:
            print("BLE session terminated successfully via GATT End command")
            if session?.currentState != .success {
                transitionToCancel()
            }
            tearDownSession(andNotify: false)

        case .userCancelled:
            transitionToCancel()
            tearDownSession(andNotify: true)
        }
    }
}
