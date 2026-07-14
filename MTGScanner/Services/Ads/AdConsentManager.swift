import UIKit

#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

extension Notification.Name {
    static let adConsentDidUpdate = Notification.Name("adConsentDidUpdate")
}

@MainActor
final class AdConsentManager {

    static let shared = AdConsentManager()

    private var isGatheringConsent = false
    private var hasStartedMobileAds = false

    private init() {}

    var canRequestAds: Bool {
        #if canImport(UserMessagingPlatform)
        ConsentInformation.shared.canRequestAds
        #else
        true
        #endif
    }

    var isPrivacyOptionsRequired: Bool {
        #if canImport(UserMessagingPlatform)
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        #else
        false
        #endif
    }

    func gatherConsent(from viewController: UIViewController) {
        guard !isGatheringConsent else { return }
        isGatheringConsent = true

        #if canImport(UserMessagingPlatform)
        let parameters = RequestParameters()

        #if DEBUG
        parameters.debugSettings = DebugSettings()
        #endif

        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self, weak viewController] requestConsentError in
            Task { @MainActor in
                guard let self else { return }

                if let requestConsentError {
                    AppLog.debug("[AdConsent] Consent info update failed: \(requestConsentError.localizedDescription)")
                }

                if let viewController {
                    do {
                        try await ConsentForm.loadAndPresentIfRequired(from: viewController)
                    } catch {
                        AppLog.debug("[AdConsent] Consent form failed: \(error.localizedDescription)")
                    }
                }

                await self.requestTrackingAuthorizationIfNeeded()
                self.startMobileAdsIfAllowed()
                self.isGatheringConsent = false
            }
        }
        #else
        Task { @MainActor in
            await requestTrackingAuthorizationIfNeeded()
            startMobileAdsIfAllowed()
            isGatheringConsent = false
        }
        #endif
    }

    func presentPrivacyOptions(from viewController: UIViewController) {
        #if canImport(UserMessagingPlatform)
        Task { @MainActor in
            do {
                try await ConsentForm.presentPrivacyOptionsForm(from: viewController)
                NotificationCenter.default.post(name: .adConsentDidUpdate, object: nil)
            } catch {
                AppLog.debug("[AdConsent] Privacy options form failed: \(error.localizedDescription)")
            }
        }
        #else
        let alert = UIAlertController(
            title: "Privacy Choices",
            message: "Privacy options are unavailable because the User Messaging Platform SDK is not linked.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
        #endif
    }

    private func requestTrackingAuthorizationIfNeeded() async {
        #if canImport(AppTrackingTransparency)
        guard #available(iOS 14, *) else { return }
        guard Bundle.main.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription") != nil else { return }

        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        guard currentStatus == .notDetermined else {
            AppLog.debug("[AdConsent] ATT status: \(currentStatus.rawValue)")
            return
        }

        let status = await ATTrackingManager.requestTrackingAuthorization()
        AppLog.debug("[AdConsent] ATT status: \(status.rawValue)")
        #endif
    }

    private func startMobileAdsIfAllowed() {
        #if canImport(UserMessagingPlatform)
        guard ConsentInformation.shared.canRequestAds else {
            AppLog.debug("[AdConsent] Ads cannot be requested yet.")
            NotificationCenter.default.post(name: .adConsentDidUpdate, object: nil)
            return
        }
        #endif

        #if canImport(GoogleMobileAds)
        guard !hasStartedMobileAds else {
            NotificationCenter.default.post(name: .adConsentDidUpdate, object: nil)
            return
        }

        hasStartedMobileAds = true
        MobileAds.shared.start { status in
            AppLog.debug("[AdMob] SDK initialized: \(status.adapterStatusesByClassName)")
            Task { @MainActor in
                NotificationCenter.default.post(name: .adConsentDidUpdate, object: nil)
            }
        }
        #else
        NotificationCenter.default.post(name: .adConsentDidUpdate, object: nil)
        #endif
    }
}
