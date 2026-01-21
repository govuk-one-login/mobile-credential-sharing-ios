import Bluetooth
import Foundation

class MockPeripheralSessionDelegate: PeripheralSessionDelegate {
    var didUpdateState: Bool?
    var didThrowError: Bluetooth.PeripheralError?
    var messageDecodedSuccessfully: Bool?
    // swiftlint:disable line_length
    let mockMessageNoEReaderKey = Data(base64Encoded: "oWRkYXRhWQLfUq2irL62w5DyygvGWbSEZ465TdRQdDhqreziN3e0RgbkLihGvC4u48HoZ7HRaF5BNUoCGrsP2jbwnPXVxRtWHTvkHJNHrnHPK0nenex7RARqsCJHkxshDJFXhAwVFKYCewiBBxat9hlmNEl5MUrDrp9A5m4BXBJUpoQQi9CT6HcuwzP7Zj/WgDrwLqEL2+g6mZ91tVoYD4chOftXrASs1YyhXsoVDN4cO4SUARiLejDOiH3XtxsS7aL8bsblI1pslJg1H80wHyKSpOu6dVUoXO6E6tlu8Wd7Cvgjn2p6Uq9LiAmx1SqyGhYsoxreIcV70dmXCigyqsQcfVLRxP7k7mQDCiGN9RNjvnAXkvpsUVxIm9Odytb7pI8dbrGenHaVMaO/mZijLAGEEwXyOETKPbah/w0NkXND1i/HKtWOqwGjGYEW8ZYGYJ+U416st40jxZxnhSo2GRX+h4SM26VjDJn6txrv9y0THPRCZU93COxIIWQW8tmWz2z5EBK3cbiJB7HRYp36eUND5lPDEgdILi9mIc1LXc87PDKGJcM/6YvpnF8mSiZDFb5Buv3HJvi83lkg3gpxiE2GCvRMH/Gz14sujXINhdrlP+orP6GAYWKkvgLQOVZ8XrJBnCrYea9I/LffVcqU8bAPYhh/ojKcgieq4BMOwFLKPiEC5X5ykRsyjP3Puq9rk2RmD2E0FTgmRMMMC9TiIsXPlLpac2ecU9XO2VylB4fCKJoMFzWDk8Hg8icjYQAvubFgYGiIpZ73osOJ9ot8tCRXLbAmsXzyvcr8tnyCktkrUAUDVpAKYqgrFvhUdZBSsA8PRnOkYin0Mlfo6DJUAbP+zIxtIli69/fC+7r6s6G2re1Ozqwer9W2ERjfk7wKYisDUE/eR867Ik6YPbEmd+MWwiquBC1s5K2uDYsPQEN7jhr6CFnJUBvrY5dEloWaYPEQabGWW0/6xXealhkfierHyqaIueZ8")
    let mockMessageNoData = Data(base64Encoded: "oWplUmVhZGVyS2V52BhYS6QBAiABIVggYOM5I4UEH1FAMFHyQVUxy1bdP5mccWhwE6rGdovIGH4iWCDljeuP2+kH991TaCRVUaNHlvfSIVxEDDObsPe2e+zN+g==")
    // swiftlint:enable line_length

    func peripheralSessionDidUpdateState(withError error: Bluetooth.PeripheralError?) {
        if error != nil {
            didUpdateState = false
            didThrowError = error
        } else {
            didUpdateState = true
            didThrowError = nil
        }
    }
    
    func peripheralSessionDidReceiveMessageData(_ message: Data) {
        switch message {
        case Data([0x02, 0x04, 0x08]), mockMessageNoEReaderKey, mockMessageNoData:
            messageDecodedSuccessfully = false
        default:
            messageDecodedSuccessfully = true
        }
    }
}
