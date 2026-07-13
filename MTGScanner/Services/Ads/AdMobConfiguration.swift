import Foundation

enum AdMobConfiguration {
    static let applicationID = "ca-app-pub-7086770658495525~1154239496"

    #if DEBUG
    static let bannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let isUsingTestAds = true
    #else
    static let bannerAdUnitID = "ca-app-pub-7086770658495525/6720437119"
    static let isUsingTestAds = false
    #endif
}
