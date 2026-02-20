import UIKit

class ErrorViewController: UIViewController {
    var titleText: String
    
    init(titleText: String) {
        self.titleText = titleText
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        navigationItem.hidesBackButton = true
        
        setupTitle()
    }
    
    func setupTitle() {
        let titleLabel: UILabel = {
            let label = UILabel()
            label.text = titleText
            label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
            label.textAlignment = .center
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
        
        view.addSubview(titleLabel)
        
        NSLayoutConstraint.activate(
            [
                titleLabel.centerXAnchor
                    .constraint(equalTo: view.centerXAnchor),
                titleLabel.centerYAnchor
                    .constraint(
                        equalTo: view.centerYAnchor,
                    ),
                titleLabel.leadingAnchor
                    .constraint(equalTo: view.leadingAnchor, constant: 62),
                titleLabel.trailingAnchor
                    .constraint(equalTo: view.trailingAnchor, constant: -62)
            ]
        )
    }
}
