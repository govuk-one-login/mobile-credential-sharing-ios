import UIKit

// MARK: - Temporary(?) Holding View for processing establishment / engagement
class ProcessingViewController: UIViewController {
    static let activityIndicatorIdentifier = "ProcessingActivityIndicator"
    
    let activityIndicator = UIActivityIndicatorView(style: .large)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Processing..."
        navigationItem.hidesBackButton = true
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        activityIndicator.accessibilityIdentifier = ProcessingViewController.activityIndicatorIdentifier
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
