import SwiftUI

/// 9:16 card rendered to an image for X / Stories / the share sheet.
struct ShareCardView: View {
    let result: RunResult
    let skin: Skin

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.18, blue: 0.42), Color(red: 0.01, green: 0.01, blue: 0.04)],
                startPoint: .bottom, endPoint: .top
            )
            stars

            VStack(spacing: 14) {
                VStack(spacing: -4) {
                    Text("STARBARGE")
                        .font(Theme.display(18))
                        .kerning(5)
                        .foregroundStyle(.white.opacity(0.8))
                    Text("DON'T POP")
                        .font(Theme.display(38))
                        .foregroundStyle(Theme.orange)
                }
                .padding(.top, 36)

                Spacer()

                SkinPreview(skin: skin, height: 170)
                    .rotationEffect(.degrees(result.reachedOrbit ? 0 : 12))

                Text(LocalizedStringKey(result.failReason?.titleKey ?? "win.title"))
                    .font(Theme.display(40))
                    .foregroundStyle(result.reachedOrbit ? Theme.yellow : .white)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Formatters.altitude(result.altitude))
                        .font(Theme.display(64))
                    Text("hud.km")
                        .font(Theme.display(24))
                        .opacity(0.7)
                }
                .foregroundStyle(.white)

                Text("« \(L(result.memeKey)) »")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .italic()
                    .foregroundStyle(Theme.yellow)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(String(format: L("share.card.score"), Formatters.score(result.score)))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                VStack(spacing: 4) {
                    Text("share.card.beat")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(Challenge(seed: result.seed, score: result.score).code)
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Theme.yellow, in: Capsule())
                    Text(ShareConfig.hashtag)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 4)
                }
                .padding(.bottom, 36)
            }
        }
    }

    private var stars: some View {
        Canvas { context, size in
            var rng = SeededRandom(seed: UInt64(result.seed))
            for _ in 0..<60 {
                let x = rng.nextDouble() * size.width
                let y = rng.nextDouble() * size.height * 0.7
                let r = rng.next(in: 0.5...1.8)
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.7)))
            }
        }
    }
}
