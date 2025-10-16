import UIKit

class QRCodeViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "QR Code"
        navigationController?.navigationBar.titleTextAttributes = [.font: UIFont.systemFont(ofSize: 24, weight: .bold)]
        
        view.backgroundColor = .systemBackground
    }
}
