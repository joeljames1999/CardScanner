import UIKit

final class AppInfoViewController: UIViewController {

    enum Page {
        case about
        case dataSources
        case privacy
        case diagnostics

        var title: String {
            switch self {
            case .about: return "About"
            case .dataSources: return "Data Sources"
            case .privacy: return "Privacy"
            case .diagnostics: return "Diagnostics"
            }
        }

        var iconName: String {
            switch self {
            case .about: return "info.circle.fill"
            case .dataSources: return "tray.full.fill"
            case .privacy: return "hand.raised.fill"
            case .diagnostics: return "waveform.path.ecg"
            }
        }

        var body: String {
            switch self {
            case .about:
                return "TCGCompanion is a solo-developed app for scanning cards, managing a local collection, and tracking tabletop play. It started as a scanner, but is being built into a broader companion for trading card games."
            case .dataSources:
                return "Card metadata, imagery, and bulk card data are provided by Scryfall. Card prices are shown for reference and may differ from live marketplace values."
            case .privacy:
                return "TCGCompanion uses the camera to scan cards. Ads are provided by Google AdMob and privacy choices are managed through Google's consent flow where required. Analytics are not enabled."
            case .diagnostics:
                return "Crash reports are monitored through Apple crash reports in Xcode Organizer and App Store Connect. No third-party analytics SDK is enabled."
            }
        }
    }

    private let page: Page

    private lazy var iconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: page.iconName))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .brandBlue
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var bodyLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .label
        label.numberOfLines = 0
        label.text = page.body
        return label
    }()

    private lazy var privacyChoicesButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.tinted()
        configuration.title = "Manage Ad Privacy Choices"
        configuration.baseForegroundColor = .brandBlue
        configuration.baseBackgroundColor = .brandBlue
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        button.configuration = configuration
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.addTarget(self, action: #selector(showPrivacyChoices), for: .touchUpInside)
        button.isHidden = page != .privacy
        return button
    }()

    init(page: Page) {
        self.page = page
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = page.title
        view.backgroundColor = .systemGroupedBackground
        setupLayout()
    }

    private func setupLayout() {
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 16

        let stack = UIStackView(arrangedSubviews: [iconView, bodyLabel, privacyChoicesButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 18

        view.addSubview(contentView)
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -22),

            iconView.heightAnchor.constraint(equalToConstant: 42)
        ])
    }

    @objc private func showPrivacyChoices() {
        AdConsentManager.shared.presentPrivacyOptions(from: self)
    }
}
