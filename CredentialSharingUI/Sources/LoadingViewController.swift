import UIKit

// MARK: - Temporary Holding View for loading
class LoadingViewController: UIViewController {
    static let activityIndicatorIdentifier = "LoadingActivityIndicator"
    
    let activityIndicator = UIActivityIndicatorView(style: .large)
    let loadingTitle: String
    
    init(loadingTitle: String = "Processing...") {
        self.loadingTitle = loadingTitle
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = loadingTitle
        navigationItem.hidesBackButton = true
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        activityIndicator.accessibilityIdentifier = LoadingViewController.activityIndicatorIdentifier
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
