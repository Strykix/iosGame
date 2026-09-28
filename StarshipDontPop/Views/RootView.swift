import SpriteKit
import SwiftUI

/// The 4 screens: launch, run (HUD), game over + share, hangar (sheet).
struct RootView: View {
    @ObservedObject var vm: GameViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            SpriteView(scene: vm.scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

            switch vm.screen {
            case .launch:
                LaunchView(vm: vm)
                    .transition(.opacity)
            case .run:
                HUDView(hud: vm.hud, streak: vm.profile.data.cleanStagingStreak)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            case .gameOver:
                GameOverView(vm: vm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: vm.screen)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .sheet(isPresented: $vm.showHangar, onDismiss: vm.hangarClosed) {
            HangarView(vm: HangarViewModel(profile: vm.profile, store: vm.store, ads: vm.ads))
        }
        .onAppear(perform: vm.onAppear)
        .onOpenURL(perform: vm.handle(url:))
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { vm.appWillResignActive() }
        }
    }
}
