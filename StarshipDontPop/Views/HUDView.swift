import SwiftUI

/// Screen 2 overlay. Never intercepts touches: the whole screen is the throttle.
struct HUDView: View {
    let hud: HUDSnapshot
    let streak: Int

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar
                Spacer()
                if let hint {
                    Text(hint.text)
                        .font(Theme.display(22))
                        .foregroundStyle(hint.color)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.6), radius: 0, x: 2, y: 2)
                        .padding(.horizontal, 40)
                        .id(hint.text)
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                Spacer()
            }
            .padding(.top, 8)

            HStack {
                GaugeBar(value: hud.heat, symbol: "flame.fill", color: Theme.orange, critical: hud.heat > 0.8)
                Spacer()
                GaugeBar(value: hud.fuel, symbol: "fuelpump.fill", color: Theme.green, critical: hud.fuel < 0.15)
            }
            .padding(.horizontal, 12)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hint?.text)
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Formatters.altitude(hud.altitude))
                        .font(Theme.display(40))
                        .monospacedDigit()
                    Text("hud.km")
                        .font(Theme.display(16))
                        .opacity(0.7)
                }
                Text(LocalizedStringKey(hud.phase.localizationKey))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(phaseColor)
                Text(LocalizedStringKey(hud.tier.localizationKey))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .opacity(0.6)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.score(hud.score))
                    .font(Theme.display(24))
                    .monospacedDigit()
                if hud.stylePoints > 0 {
                    Text(String(format: L("hud.style"), Formatters.score(hud.stylePoints)))
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.yellow)
                }
                if streak > 0 {
                    Badge(text: String(format: L("hud.streak"), streak), symbol: "bolt.fill", color: Theme.green)
                }
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.5), radius: 0, x: 1, y: 1)
        .padding(.horizontal, 20)
    }

    private var phaseColor: Color {
        switch hud.phase {
        case .hotStaging: return Theme.green
        case .orbitBurn: return Theme.sky
        case .orbit: return Theme.yellow
        default: return Theme.orange
        }
    }

    private var hint: (text: String, color: Color)? {
        if hud.waitingForTouch {
            return (L(hud.phase == .pad ? "hint.hold.liftoff" : "hint.hold.resume"), .white)
        }
        if hud.stagingPending { return (L("hint.staging.tap"), Theme.green) }
        if hud.phase == .hotStaging { return (L("hint.staging.release"), Theme.green) }
        if hud.heat > 0.85 { return (L("hint.overheat"), Theme.red) }
        if hud.inWind && abs(hud.tilt) > 0.45 { return (L("hint.wind"), Theme.sky) }
        if hud.velocity < -2.4 { return (L("hint.falling"), Theme.yellow) }
        if hud.fuel < 0.15 && hud.phase != .pad { return (L("hint.fuel"), Theme.yellow) }
        if hud.inTurbulence { return (L("hint.turbulence"), Theme.orange) }
        return nil
    }
}
