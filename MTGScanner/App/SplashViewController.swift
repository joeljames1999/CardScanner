import UIKit

final class SplashViewController: UIViewController {
    
    private let logoImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage.icon
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let laserGlowView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.brandBlue.withAlphaComponent(0.32)
        view.layer.cornerRadius = 7
        view.layer.shadowColor = UIColor.brandBlue.cgColor
        view.layer.shadowRadius = 24
        view.layer.shadowOpacity = 1
        view.layer.shadowOffset = .zero
        return view
    }()

    private let laserView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.layer.cornerRadius = 1.5
        view.layer.borderColor = UIColor.accentColor.withAlphaComponent(0.65).cgColor
        view.layer.borderWidth = 0.5
        view.layer.shadowColor = UIColor.accentColor.cgColor
        view.layer.shadowRadius = 18
        view.layer.shadowOpacity = 1
        view.layer.shadowOffset = .zero
        return view
    }()

    private var laserTopConstraint: NSLayoutConstraint!
    private var hasFinishedLaunching = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLayout()
        animateLaser()

        Task {
            await ScryfallBulkService.shared.refreshIfNeeded()

            await MainActor.run {
                self.finishLaunching()
            }
        }
    }
    
    private func finishLaunching() {

        guard !hasFinishedLaunching else {
            return
        }

        hasFinishedLaunching = true

        UIView.animate(withDuration: 0.25) {
            self.view.alpha = 0
        } completion: { _ in

            let mainVC = MainTabBarController()

            guard
                let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let window = windowScene.windows.first
            else {
                return
            }

            window.rootViewController = mainVC

            UIView.transition(
                with: window,
                duration: 0.3,
                options: .transitionCrossDissolve, animations: .none
            )
        }
    }

    private func setupLayout() {

        view.addSubview(logoImageView)
        view.addSubview(laserGlowView)
        view.addSubview(laserView)

        NSLayoutConstraint.activate([

            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 220),
            logoImageView.heightAnchor.constraint(equalToConstant: 220),

            laserGlowView.centerXAnchor.constraint(equalTo: logoImageView.centerXAnchor),
            laserGlowView.widthAnchor.constraint(equalTo: logoImageView.widthAnchor, multiplier: 1.35),
            laserGlowView.heightAnchor.constraint(equalToConstant: 14),

            laserView.centerXAnchor.constraint(equalTo: laserGlowView.centerXAnchor),
            laserView.centerYAnchor.constraint(equalTo: laserGlowView.centerYAnchor),
            laserView.widthAnchor.constraint(equalTo: laserGlowView.widthAnchor),
            laserView.heightAnchor.constraint(equalToConstant: 3)
        ])

        laserTopConstraint = laserGlowView.centerYAnchor.constraint(
            equalTo: logoImageView.topAnchor,
            constant: 50
        )

        laserTopConstraint.isActive = true
    }

    private func animateLaser() {

        view.layoutIfNeeded()

        UIView.animate(
            withDuration: 1.5,
            delay: 0,
            options: [.autoreverse, .repeat],
            animations: {

                self.laserTopConstraint.constant = 170
                self.view.layoutIfNeeded()

            }
        )

        let glowPulse = CABasicAnimation(keyPath: "opacity")
        glowPulse.fromValue = 0.55
        glowPulse.toValue = 1.0
        glowPulse.duration = 0.72
        glowPulse.autoreverses = true
        glowPulse.repeatCount = .infinity
        glowPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        laserGlowView.layer.add(glowPulse, forKey: "scannerLaserGlowPulse")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.finishLaunching()
        }
    }
}
