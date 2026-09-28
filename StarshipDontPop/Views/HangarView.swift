import StoreKit
import SwiftUI

/// Screen 4 — Hangar (skins) + shop (cosmetic IAP only) + settings.
struct HangarView: View {
    @StateObject private var vm: HangarViewModel
    @Environment(\.dismiss) private var dismiss

    init(vm: @autoclosure @escaping () -> HangarViewModel) {
        _vm = StateObject(wrappedValue: vm())
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    stats
                    section("hangar.skins") {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(vm.skins) { item in
                                skinCard(item)
                            }
                        }
                    }
                    section("hangar.shop") {
                        VStack(spacing: 12) {
                            ForEach(vm.shopItems) { item in
                                shopCard(item)
                            }
                            Button {
                                Task { await vm.restore() }
                            } label: {
                                Label("shop.restore", systemImage: "arrow.clockwise.circle")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            Text("shop.cosmetic.note")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    section("hangar.settings") {
                        VStack(spacing: 0) {
                            Toggle(isOn: Binding(get: { vm.stats.soundEnabled }, set: vm.setSound)) {
                                Label("settings.sound", systemImage: "speaker.wave.2.fill")
                            }
                            .padding(.vertical, 8)
                            Divider().overlay(Color.white.opacity(0.1))
                            Toggle(isOn: Binding(get: { vm.stats.hapticsEnabled }, set: vm.setHaptics)) {
                                Label("settings.haptics", systemImage: "iphone.radiowaves.left.and.right")
                            }
                            .padding(.vertical, 8)
                            if vm.showsPrivacyOptions {
                                Divider().overlay(Color.white.opacity(0.1))
                                Button {
                                    Task { await vm.openPrivacyOptions() }
                                } label: {
                                    HStack {
                                        Label("settings.privacy", systemImage: "hand.raised.fill")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .bold))
                                            .opacity(0.5)
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.vertical, 12)
                                }
                            }
                        }
                        .tint(Theme.orange)
                        .padding(.horizontal, 14)
                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    Text("legal.parody")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            }
            .background(Theme.panel.ignoresSafeArea())
            .navigationTitle(Text("hangar.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .alert(
                Text("store.error.title"),
                isPresented: Binding(
                    get: { if case .failed = vm.store.purchaseState { return true } else { return false } },
                    set: { if !$0 { vm.store.clearError() } }
                )
            ) {
                Button("common.ok", role: .cancel) { vm.store.clearError() }
            } message: {
                if case .failed(let message) = vm.store.purchaseState {
                    Text(message)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var stats: some View {
        HStack(spacing: 8) {
            StatTile(value: Formatters.score(vm.stats.bestScore), label: L("hangar.stat.best"))
            StatTile(value: "\(Formatters.altitude(vm.stats.bestAltitude))", label: L("hangar.stat.altitude"))
            StatTile(value: "\(vm.stats.orbitCount)", label: L("hangar.stat.orbits"))
            StatTile(value: "\(vm.stats.bestCleanStagingStreak)", label: L("hangar.stat.streak"))
        }
    }

    private func section<Content: View>(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titleKey)
                .font(Theme.display(20))
                .foregroundStyle(.white)
            content()
        }
    }

    private func skinCard(_ item: HangarViewModel.SkinItem) -> some View {
        Button {
            vm.select(item.skin)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    SkinPreview(skin: item.skin, height: 110)
                        .opacity(item.isUnlocked ? 1 : 0.25)
                    if !item.isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(height: 120)
                Text(LocalizedStringKey(item.skin.nameKey))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(LocalizedStringKey(item.isSelected ? "hangar.equipped" : (item.isUnlocked ? "hangar.equip" : item.skin.unlockHintKey)))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(item.isSelected ? Theme.green : .white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(item.isSelected ? Theme.green : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(!item.isUnlocked)
    }

    private func shopCard(_ item: HangarViewModel.ShopItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.symbol)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.yellow)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(item.titleKey))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                Text(LocalizedStringKey(item.descriptionKey))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            if item.isOwned {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.green)
            } else if let product = item.product {
                Button {
                    Task { await vm.buy(item) }
                } label: {
                    if vm.store.purchaseState == .purchasing(product.id) {
                        ProgressView().tint(.black)
                    } else {
                        Text(product.displayPrice)
                    }
                }
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Theme.yellow, in: Capsule())
            } else {
                ProgressView()
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
