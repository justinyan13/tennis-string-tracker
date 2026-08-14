import SwiftUI

@main
struct StringbedApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(Palette.ball)
        }
    }
}
