import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

final class AdMobBannerView: UIView {

    static let preferredHeight: CGFloat = 50

    #if canImport(GoogleMobileAds)
    private let bannerView = BannerView()
    private var hasLoadedAd = false
    #endif

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    func load(adUnitID: String, rootViewController: UIViewController) {
        #if canImport(GoogleMobileAds)
        guard !hasLoadedAd else { return }

        hasLoadedAd = true
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = rootViewController
        bannerView.adSize = adSizeFor(cgSize: CGSize(width: 320, height: Self.preferredHeight))
        bannerView.delegate = self
        AppLog.debug("[AdMobBannerView] Loading banner ad: \(adUnitID) testAds=\(AdMobConfiguration.isUsingTestAds)")
        bannerView.load(Request())
        #else
        AppLog.debug("[AdMobBannerView] GoogleMobileAds is not linked to this target.")
        isHidden = true
        #endif
    }

    private func setupView() {
        backgroundColor = .clear

        #if canImport(GoogleMobileAds)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bannerView)

        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            bannerView.widthAnchor.constraint(equalToConstant: 320),
            bannerView.heightAnchor.constraint(equalToConstant: Self.preferredHeight)
        ])
        #else
        isHidden = true
        #endif
    }
}

#if canImport(GoogleMobileAds)
extension AdMobBannerView: BannerViewDelegate {

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        AppLog.debug("[AdMobBannerView] Banner ad loaded.")
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        let nsError = error as NSError
        AppLog.debug("[AdMobBannerView] Banner ad failed to load: domain=\(nsError.domain) code=\(nsError.code) message=\(nsError.localizedDescription) userInfo=\(nsError.userInfo)")
        if let responseInfo = bannerView.responseInfo {
            AppLog.debug("[AdMobBannerView] Response info: \(responseInfo)")
        }
    }

    func bannerViewDidRecordImpression(_ bannerView: BannerView) {
        AppLog.debug("[AdMobBannerView] Banner ad impression recorded.")
    }

    func bannerViewDidRecordClick(_ bannerView: BannerView) {
        AppLog.debug("[AdMobBannerView] Banner ad click recorded.")
    }
}
#endif
