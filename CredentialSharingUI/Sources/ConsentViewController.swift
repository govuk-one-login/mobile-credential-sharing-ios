import SharingCryptoService
import UIKit

class ConsentViewController: UIViewController {
    private let deviceRequest: DeviceRequest
    
    init(deviceRequest: DeviceRequest) {
        self.deviceRequest = deviceRequest
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
        setupTextView()
        setupButtons()
    }
    
    private func setupTitle() {
        let titleLabel = UILabel()
        titleLabel.text = "Confirm the credential attributes to share"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupTextView() {
        let textView = UITextView()
        textView.text = formatDeviceRequest()
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.layer.cornerRadius = 8
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100)
        ])
    }
    
    private func setupButtons() {
        let acceptButton = UIButton(type: .system)
        acceptButton.setTitle("Accept", for: .normal)
        acceptButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        acceptButton.backgroundColor = .systemGreen
        acceptButton.setTitleColor(.white, for: .normal)
        acceptButton.layer.cornerRadius = 8
        acceptButton.translatesAutoresizingMaskIntoConstraints = false
        
        let denyButton = UIButton(type: .system)
        denyButton.setTitle("Deny", for: .normal)
        denyButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        denyButton.backgroundColor = .systemRed
        denyButton.setTitleColor(.white, for: .normal)
        denyButton.layer.cornerRadius = 8
        denyButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(acceptButton)
        view.addSubview(denyButton)
        
        NSLayoutConstraint.activate([
            acceptButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            acceptButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            acceptButton.heightAnchor.constraint(equalToConstant: 50),
            acceptButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -10),
            
            denyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            denyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            denyButton.heightAnchor.constraint(equalToConstant: 50),
            denyButton.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 10)
        ])
    }
    
    private func formatDeviceRequest() -> String {
        var output = "Version: \(deviceRequest.version)\n\n"
        
        for docRequest in deviceRequest.docRequests {
            output += "Document Type: \(docRequest.itemsRequest.docType.rawValue)\n\n"
            
            for nameSpace in docRequest.itemsRequest.nameSpaces {
                output += "Namespace: \(nameSpace.name)\n"
                output += "Requested Elements:\n"
                
                for element in nameSpace.elements {
                    output += "  - \(element.identifier): IntentToRetain = \(element.intentToRetain)\n"
                }
                output += "\n"
            }
        }
        
        return output
    }
}
