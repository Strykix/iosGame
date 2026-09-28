import Combine
import StoreKit
import SwiftUI

@MainActor
final class HangarViewModel: ObservableObject {
    struct SkinItem: Identifiable {
        let skin: Skin
        let isUnlocked: Bool
        let isSelected: Bool
        var id: String { skin.id }
    }

    struct ShopItem: Identifiable {
        let id: String
        let titleKey: String
        let descriptionKey: String
        let symbol: String
        let product: Product?
        let isOwned: Bool
    }

    let profile: ProfileStore
    let store: StoreService
    private let ads: AdService
    private var cancellables = Set<AnyCancellable>()

    init(profile: ProfileStore, store: StoreService, ads: AdService) {
        self.profile = profile
        self.store = store
        self.ads = ads
        // Re-render whenever progression or entitlements change.
        profile.objectWillChange
            .merge(with: store.objectWillChange)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var skins: [SkinItem] {
        Skin.allCases.map { skin in
            SkinItem(skin: skin, isUnlocked: profile.isUnlocked(skin), isSelected: profile.data.selectedSkin == skin)
        }
    }

    var shopItems: [ShopItem] {
        [
            ShopItem(
                id: ProductID.chromePack, titleKey: "shop.chrome.title", descriptionKey: "shop.chrome.description",
                symbol: "sparkles", product: store.product(for: ProductID.chromePack),
                isOwned: store.ownedProductIDs.contains(ProductID.chromePack) || store.ownedProductIDs.contains(ProductID.fleetPack)
            ),
            ShopItem(
                id: ProductID.fleetPack, titleKey: "shop.fleet.title", descriptionKey: "shop.fleet.description",
                symbol: "airplane.departure", product: store.product(for: ProductID.fleetPack),
                isOwned: store.ownedProductIDs.contains(ProductID.fleetPack)
            ),
        ]
    }

    var stats: SaveData { profile.data }

    func select(_ skin: Skin) {
        profile.select(skin)
    }

    func buy(_ item: ShopItem) async {
        guard let product = item.product else { return }
        await store.purchase(product)
    }

    func restore() async {
        await store.restore()
    }

    func setSound(_ enabled: Bool) {
        profile.setSound(enabled)
    }

    func setHaptics(_ enabled: Bool) {
        profile.setHaptics(enabled)
    }

    /// GDPR: users in the EEA must be able to revisit their ad consent.
    var showsPrivacyOptions: Bool { ads.needsPrivacyOptions }

    func openPrivacyOptions() async {
        await ads.presentPrivacyOptions()
        objectWillChange.send()
    }
}
