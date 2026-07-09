import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        Task { @MainActor in
            await ExchangeRateService.shared.refreshRatesIfNeeded()
        }

        return true
    }
}
