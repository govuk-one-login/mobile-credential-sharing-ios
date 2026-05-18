import UIKit

// MARK: - Temporary(?) Holding View for processing establishment
class ProcessingEstablishmentViewController: UIViewController {
    static let activityIndicatorIdentifier = "ProcessingEstablishmentActivityIndicator"
    
    let activityIndicator = UIActivityIndicatorView(style: .large)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Processing establishment..."
        navigationItem.hidesBackButton = true
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        activityIndicator.accessibilityIdentifier = ProcessingEstablishmentViewController.activityIndicatorIdentifier
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor
                .constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor
                .constraint(equalTo: view.centerYAnchor)
        ])
    }
}
