import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // 1. Kick off the database sync process on launch
        Task {
            await ScryfallBulkService.shared.refreshIfNeeded()
            
            // Proactive optimization: If data is already present, run a quick cycle right away
            if ScryfallBulkService.shared.isDataPresent {
                ScryfallBulkService.shared.precomputeVectorsForCommonCards()
            }
        }
        
        // 2. Register the idle observer to maximize background execution windows
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            ScryfallBulkService.shared.precomputeVectorsForCommonCards()
        }
        
        return true
    }
}
