import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("ErrorViewController Tests")
struct ErrorViewControllerTests {
    func findStackView(in view: UIView) -> UIStackView? {
        return view.subviews.first {$0 is UIStackView } as? UIStackView
    }
    
    func findLabel(in view: UIView) -> UILabel? {
        guard let stack = findStackView(in: view) else { return nil }
        return stack.arrangedSubviews.compactMap { $0 as? UILabel }.first
    }
    
    func findSettingButton(in view: UIView) -> UIButton? {
        guard let stack = findStackView(in: view) else { return nil }
        return stack.arrangedSubviews.compactMap { $0 as? UIButton }.first
    }
    
    @Test("Checking the view loads successfully")
    func checkSubviewLoadsCorrectly() {
        let sut = ErrorViewController(error: .generic("Test title"))
        sut.viewDidLoad()
        
        let label = findLabel(in: sut.view)
        let settingButton = findSettingButton(in: sut.view)

        #expect(sut.view.subviews.count == 2)
        #expect(label?.text == "Test title")
        #expect(settingButton == nil)
    }
    
    @Test("Bluetooth denied error shows setting button CTA")
    func bluetoothDeniedShowsCTA() {
        let sut = ErrorViewController(error: .unrecoverablePrerequisite(.bluetooth(.authorizationDenied))
        )
        
        sut.viewDidLoad()
        
        let label = findLabel(in: sut.view)
        let settingButton = findSettingButton(in: sut.view)

        #expect(sut.view.subviews.count == 2)
        #expect(label?.text == "Bluetooth access has been denied. Please enable it in Settings to continue.")
        #expect(settingButton != nil)
//        #expect(settingButton?.title == "Open Settings")
        
    }
    
    @Test("Bluetooth restricted error does not show setting button CTA")
    func bluetoothRestrictedNoCTAButton() {
        let sut = ErrorViewController(error: .unrecoverablePrerequisite(.bluetooth(.authorizationRestricted))
        )
        
        sut.viewDidLoad()
        
        let label = findLabel(in: sut.view)
        let settingButton = findSettingButton(in: sut.view)

        #expect(sut.view.subviews.count == 2)
        #expect(label?.text == "Bluetooth access is restricted by device policy.")
        #expect(settingButton == nil)
        
    }
    
    @Test("Unknown error shows label and shows no setting button CTA")
    func unknownErrorNoCTA() {
        let sut = ErrorViewController(error: .unknown)
        
        sut.viewDidLoad()
        
        let label = findLabel(in: sut.view)
        let settingButton = findSettingButton(in: sut.view)

        #expect(sut.view.subviews.count == 2)
        #expect(label?.text == "Bluetooth status is currently unknown.")
        #expect(settingButton == nil)
    }
    
    @Test("Tapping Open Settings button triggers UIApplication.open")
    func tappingOpenSettingsCallsUIApplicationOpen() {
        let sut = ErrorViewController(error: .unrecoverablePrerequisite(.bluetooth(.authorizationDenied))
        )
        
        sut.viewDidLoad()

        let settingButton = findSettingButton(in: sut.view)
        let action = settingButton?.actions(forTarget: sut, forControlEvent: .touchUpInside)
        
        #expect(action?.contains("openSettingsTapped") == true)
    }
}
