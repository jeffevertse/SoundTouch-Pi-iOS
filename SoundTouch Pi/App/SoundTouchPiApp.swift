import SwiftUI

@main
struct SoundTouchPiApp: App {
    @StateObject private var vm = PlayerViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
                    .navigationTitle("SoundTouch Pi")
                    .navigationBarTitleDisplayMode(.large)
            }
            .environmentObject(vm)
        }
    }
}
