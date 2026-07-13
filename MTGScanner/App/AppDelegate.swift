import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        #if canImport(GoogleMobileAds)
        MobileAds.shared.start { status in
            print("[AdMob] SDK initialized: \(status.adapterStatusesByClassName)")
        }
        #endif

        Task { @MainActor in
            await ExchangeRateService.shared.refreshRatesIfNeeded()
        }

        return true
    }
}
