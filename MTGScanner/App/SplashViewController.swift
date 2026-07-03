import UIKit

final class SplashViewController: UIViewController {
    
    private let logoImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage.icon
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let laserView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.brandBlue
        view.layer.shadowColor = UIColor.white.cgColor
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 1
        return view
    }()

    private var laserTopConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        setupLayout()
        animateLaser()
    }

    private func setupLayout() {

        view.addSubview(logoImageView)
        view.addSubview(laserView)

        NSLayoutConstraint.activate([

            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 220),
            logoImageView.heightAnchor.constraint(equalToConstant: 220),

            laserView.centerXAnchor.constraint(equalTo: logoImageView.centerXAnchor),
            laserView.widthAnchor.constraint(equalToConstant: view.frame.width / 2),
            laserView.heightAnchor.constraint(equalToConstant: 3)
        ])

        laserTopConstraint = laserView.topAnchor.constraint(
            equalTo: logoImageView.topAnchor
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

                self.laserTopConstraint.constant = 220
                self.view.layoutIfNeeded()

            }
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {

            UIView.animate(withDuration: 0.25) {

                self.view.alpha = 0

            } completion: { _ in

                let mainVC = MainTabBarController()

                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first
                else { return }

                window.rootViewController = mainVC

                UIView.transition(
                    with: window,
                    duration: 0.3,
                    options: .transitionCrossDissolve, animations: .none
                )
            }
        }
    }
}

