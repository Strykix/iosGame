import SwiftUI

/// Screen 3 — Game over / orbit + share. The replay of the last 3 s loops in the scene behind.
struct GameOverView: View {
    @ObservedObject var vm: GameViewModel
    @State private var copied = false

    var body: some View {
        if let result = vm.result {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                card(result)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func card(_ result: RunResult) -> some View {
        VStack(spacing: 12) {
            header(result)

            Text("« \(L(result.memeKey)) »")
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .italic()
                .foregroundStyle(Theme.yellow)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)

            HStack(spacing: 8) {
                StatTile(value: "\(Formatters.altitude(result.altitude)) km", label: L("gameover.altitude"))
                StatTile(value: Formatters.score(result.score), label: L("gameover.score"))
                StatTile(value: Formatters.score(vm.profile.data.bestScore), label: L("gameover.best"))
            }

            badges(result)

            if result.reachedOrbit {
                shareCode(result)
            }

            shareRow(result)

            if vm.canUseSecondChance {
                HStack(spacing: 8) {
                    Button {
                        Task { await vm.continueWithAd() }
                    } label: {
                        Label("gameover.continue", systemImage: "play.rectangle.fill")
                    }
                    if vm.canRetryFromStaging {
                        Button {
                            Task { await vm.retryFromStagingWithAd() }
                        } label: {
                            Label("gameover.retry.staging", systemImage: "arrow.uturn.backward.circle.fill")
                        }
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(vm.isShowingAd)
            }

            HStack(spacing: 8) {
                Button(action: vm.relaunch) {
                    Label("gameover.relaunch", systemImage: "arrow.clockwise")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(action: vm.openHangar) {
                    Image(systemName: "paintpalette.fill")
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel(Text("hangar.title"))

                Button(action: vm.backToMenu) {
                    Image(systemName: "house.fill")
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel(Text("gameover.menu"))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 34)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                .fill(Theme.panel.opacity(0.92))
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func header(_ result: RunResult) -> some View {
        HStack(spacing: 12) {
            Image(systemName: result.failReason?.symbol ?? "sparkles")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(result.reachedOrbit ? Theme.yellow : Theme.orange)
            VStack(alignment: .leading, spacing: 0) {
                Text(LocalizedStringKey(result.failReason?.titleKey ?? "win.title"))
                    .font(Theme.display(32))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(LocalizedStringKey(result.failReason?.subtitleKey ?? "win.subtitle"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func badges(_ result: RunResult) -> some View {
        let challengeLine = challengeText(result)
        if result.isNewBest || result.cleanStaging || !result.newlyUnlocked.isEmpty || challengeLine != nil {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if result.isNewBest {
                        Badge(text: L("gameover.newbest"), symbol: "trophy.fill", color: Theme.yellow)
                    }
                    if result.cleanStaging {
                        Badge(text: String(format: L("gameover.clean.streak"), result.cleanStagingStreak), symbol: "bolt.fill", color: Theme.green)
                    }
                    if result.nearMisses > 0 {
                        Badge(text: String(format: L("gameover.nearmiss"), result.nearMisses), symbol: "wind", color: Theme.sky)
                    }
                    ForEach(result.newlyUnlocked) { skin in
                        Badge(text: String(format: L("gameover.unlocked"), L(skin.nameKey)), symbol: "lock.open.fill", color: .white)
                    }
                    if let challengeLine {
                        Badge(text: challengeLine.text, symbol: "flag.checkered", color: challengeLine.won ? Theme.green : Theme.orange)
                    }
                }
            }
        }
    }

    private func challengeText(_ result: RunResult) -> (text: String, won: Bool)? {
        guard let challenge = vm.challenge else { return nil }
        if result.score > challenge.score {
            return (L("gameover.challenge.won"), true)
        }
        return (String(format: L("gameover.challenge.missing"), Formatters.score(challenge.score - result.score + 1)), false)
    }

    private func shareCode(_ result: RunResult) -> some View {
        let code = Challenge(seed: result.seed, score: result.score).code
        return Button {
            UIPasteboard.general.string = code
            copied = true
        } label: {
            HStack {
                Text("gameover.code")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .opacity(0.7)
                Text(code)
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                Spacer()
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.yellow, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
        }
    }

    private func shareRow(_ result: RunResult) -> some View {
        HStack(spacing: 8) {
            if let image = vm.shareImage {
                ShareLink(
                    item: Image(uiImage: image),
                    message: Text(vm.shareText),
                    preview: SharePreview(Text("STARSHIP: DON'T POP"), image: Image(uiImage: image))
                ) {
                    Label("gameover.share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle(color: Theme.yellow, foreground: .black))
            } else {
                ShareLink(item: vm.shareText) {
                    Label("gameover.share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle(color: Theme.yellow, foreground: .black))
            }

            if let url = vm.xShareURL {
                Link(destination: url) {
                    Text("𝕏")
                        .font(.system(size: 22, weight: .black))
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel(Text("gameover.share.x"))
            }

            Button(action: vm.shareToStories) {
                Image(systemName: "camera.circle.fill")
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel(Text("gameover.share.stories"))
        }
    }
}
