import CredentialSharingUI
import GDSAnalytics
import Logging

extension ScreenView: @retroactive LoggableScreen
where Screen: GDSAnalytics.ScreenType & CustomStringConvertible {
    public var name: String {
        title
    }
    
    public var type: Screen {
        screen
    }
}

extension ErrorScreenView: @retroactive LoggableScreen
where Screen: GDSAnalytics.ScreenType & CustomStringConvertible {
    public var name: String {
        title
    }
    
    public var type: Screen {
        screen
    }
}
