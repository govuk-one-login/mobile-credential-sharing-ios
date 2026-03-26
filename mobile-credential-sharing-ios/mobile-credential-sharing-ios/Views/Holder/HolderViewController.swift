import CredentialSharingUI
import Logging
import UIKit

class HolderViewController: UITableViewController {
    static let cellIdentifier = "MockCredentialCell"

    private let loggingService: AnalyticsService = DebugLoggingService()
    private let credentials = MockCredential.allMocks

    override func viewDidLoad() {
        super.viewDidLoad()
        restorationIdentifier = "HolderViewController"
        title = "Holder"
        navigationItem.largeTitleDisplayMode = .always
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellIdentifier)
    }

    // MARK: - UITableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        credentials.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier, for: indexPath)
        cell.textLabel?.text = credentials[indexPath.row].displayName
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selected = credentials[indexPath.row]
        let provider = MockCredentialProvider(activeCredential: selected)
        let presenter = CredentialPresenter(
            credentialProvider: provider,
            logger: loggingService,
            completion: { [weak self] in
                self?.dismiss(animated: true)
            }
        )
        let journeyVC = presenter.viewControllerForSharingJourney()
        present(journeyVC, animated: true)
    }
}
