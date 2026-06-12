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
        view.backgroundColor = UIColor(
            red: 85/255,
            green: 189/255,
            blue: 251/255,
            alpha: 1
        )

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

extension UIColor {
    public convenience init?(hex: String) {
        let r, g, b, a: CGFloat

        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 8 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
                    g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                    b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                    a = CGFloat(hexNumber & 0x000000ff) / 255

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }

        return nil
    }
}
