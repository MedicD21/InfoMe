import WidgetKit
import SwiftUI

@main
struct InfoMeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ShareCardWidget()
        // `ControlWidget` (and therefore `ShowCardControl`) requires iOS 18 —
        // the deployment target here is 17, so older OS versions only get the
        // `AppShortcut`-based Action Button binding from `OpenCardIntent`.
        if #available(iOS 18.0, *) {
            ShowCardControl()
        }
    }
}
