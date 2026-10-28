import UIKit

@MainActor
public protocol SharingURLOpener {
    func open(url: URL)
}

@MainActor
extension UIApplication: SharingURLOpener {
    public func open(url: URL) {
        open(url)
    }
}
