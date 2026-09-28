import SwiftUI

/// Screen 1 — Tap to launch.
struct LaunchView: View {
    @ObservedObject var vm: GameViewModel
    @State private var pulse = false

    /// The scene is full-screen: the rocket base sits at `rocketScreenYFraction` of the full height
    /// and the stack is `stackLength` km tall. Returns the space to keep free above the safe-area bottom.
    private func rocketClearance(_ geometry: GeometryProxy) -> CGFloat {
        let fullHeight = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
        let fraction = GameConfig.rocketScreenYFraction + GameConfig.stackLength / GameConfig.visibleKm
        return max(0, fullHeight * CGFloat(fraction) - geometry.safeAreaInsets.bottom + 16)
    }

    var body: some View {
        GeometryReader { geometry in
            content(clearance: rocketClearance(geometry))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func content(clearance: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: vm.launch)

            VStack(spacing: 10) {
                HStack {
                    Spacer()
                    Button(action: vm.openHangar) {
                        Image(systemName: "paintpalette.fill")
                    }
                    .buttonStyle(IconButtonStyle())
                    .accessibilityLabel(Text("hangar.title"))
                }
                .padding(.horizontal, 20)

                VStack(spacing: -6) {
                    Text("STARBARGE")
                        .font(Theme.display(30))
                        .foregroundStyle(.white.opacity(0.85))
                        .kerning(6)
                    Text("DON'T POP")
                        .font(Theme.display(54))
                        .foregroundStyle(Theme.orange)
                        .shadow(color: .black.opacity(0.4), radius: 0, x: 3, y: 3)
                }
                Text("launch.subtitle")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))

                if vm.profile.data.bestScore > 0 {
                    Text(String(
                        format: L("launch.best"),
                        Formatters.score(vm.profile.data.bestScore),
                        Formatters.altitude(vm.profile.data.bestAltitude)
                    ))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.yellow)
                    .padding(.top, 4)
                }

                if let challenge = vm.challenge {
                    challengeBanner(challenge)
                }

                Spacer()

                Text("launch.tap")
                    .font(Theme.display(30))
                    .foregroundStyle(.white)
                    .scaleEffect(pulse ? 1.06 : 0.96)
                    .opacity(pulse ? 1 : 0.7)
                Text("launch.howto")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Keep the rocket on the pad visible below the text.
                Spacer().frame(height: clearance)
            }
            .padding(.top, 12)
        }
    }

    private func challengeBanner(_ challenge: Challenge) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "flag.checkered")
            VStack(alignment: .leading, spacing: 2) {
                Text("launch.challenge.title")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                Text(String(format: L("launch.challenge.target"), Formatters.score(challenge.score)))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .opacity(0.8)
            }
            Spacer()
            Button(action: vm.clearChallenge) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
            }
            .accessibilityLabel(Text("common.close"))
        }
        .foregroundStyle(.black)
        .padding(12)
        .background(Theme.yellow, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}
