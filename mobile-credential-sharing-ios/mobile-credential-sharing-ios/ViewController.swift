import UIKit

class ViewController: UIViewController {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Welcome to GOV.UK Wallet Sharing"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = .darkText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        setupLayout()
    }
    
    private func setupLayout() {
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            titleLabel.leadingAnchor
                .constraint(equalTo: view.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor
                .constraint(equalTo: view.trailingAnchor, constant: -12)
        ])
    }
}
