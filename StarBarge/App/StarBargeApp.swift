import SwiftUI

@main
struct StarBargeApp: App {
    @StateObject private var viewModel: GameViewModel

    init() {
        let profile = ProfileStore()
        let store = StoreService()
        let ads = AdServiceFactory.make()
        _viewModel = StateObject(wrappedValue: GameViewModel(profile: profile, store: store, ads: ads))
    }

    var body: some Scene {
        WindowGroup {
            RootView(vm: viewModel)
        }
    }
}
