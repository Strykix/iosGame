import SwiftUI

func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

enum Theme {
    static let orange = Color(red: 1, green: 0.42, blue: 0.12)
    static let green = Color(red: 0.25, green: 0.82, blue: 0.48)
    static let yellow = Color(red: 1, green: 0.82, blue: 0.25)
    static let red = Color(red: 1, green: 0.23, blue: 0.19)
    static let sky = Color(red: 0.56, green: 0.89, blue: 1)
    static let panel = Color(red: 0.05, green: 0.06, blue: 0.12)

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.orange
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(20))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 50, height: 50)
            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
    }
}

/// Vertical gauge used for heat and fuel.
struct GaugeBar: View {
    let value: Double
    let symbol: String
    let color: Color
    var critical = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(critical ? Theme.red : .white)
            ZStack(alignment: .bottom) {
                Capsule().fill(Color.black.opacity(0.35))
                Capsule()
                    .fill(critical ? Theme.red : color)
                    .frame(height: max(4, 150 * min(max(value, 0), 1)))
            }
            .frame(width: 12, height: 150)
            .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
        }
    }
}

struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.display(22))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct Badge: View {
    let text: String
    let symbol: String
    let color: Color

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color, in: Capsule())
    }
}

/// Small preview of a skin (ship stacked on booster), drawn with the same code as the game.
struct SkinPreview: View {
    let skin: Skin
    var height: CGFloat = 110

    var body: some View {
        let width = height * 0.22
        VStack(spacing: 0) {
            Image(uiImage: Artwork.shipImage(skin: skin, size: CGSize(width: width, height: height / 2)))
            Image(uiImage: Artwork.boosterImage(skin: skin, size: CGSize(width: width, height: height / 2)))
        }
    }
}

enum Formatters {
    static func score(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    static func altitude(_ km: Double) -> String {
        km.formatted(.number.precision(.fractionLength(1)))
    }
}
