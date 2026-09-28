import Foundation
import StoreKit

/// StoreKit 2: two cosmetic non-consumables. No pay-to-win, no energy.
@MainActor
final class StoreService: ObservableObject {
    enum PurchaseState: Equatable {
        case idle
        case purchasing(String)
        case failed(String)
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var ownedProductIDs: Set<String> = []
    @Published private(set) var purchaseState: PurchaseState = .idle
    @Published private(set) var isLoading = false

    var onEntitlementsChanged: ((Set<String>) -> Void)?
    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self.refreshEntitlements()
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func start() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: ProductID.all)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            #if DEBUG
            print("StoreKit products failed: \(error)")
            #endif
        }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    func purchase(_ product: Product) async {
        purchaseState = .purchasing(product.id)
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                    purchaseState = .idle
                } else {
                    purchaseState = .failed(NSLocalizedString("store.error.verification", comment: ""))
                }
            case .userCancelled, .pending:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
        await refreshEntitlements()
    }

    func clearError() {
        purchaseState = .idle
    }

    func refreshEntitlements() async {
        var owned = Set<String>()
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement, transaction.revocationDate == nil {
                owned.insert(transaction.productID)
            }
        }
        ownedProductIDs = owned
        onEntitlementsChanged?(owned)
    }
}
