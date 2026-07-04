import Foundation
import StoreKit
import Tauri

struct GetProductsArgs: Decodable, Sendable {
    let productIds: [String]
}

struct PurchaseArgs: Decodable, Sendable {
    let productId: String
}

struct FinishTransactionArgs: Decodable, Sendable {
    let transactionId: String
}

struct ProductInfo: Encodable, Sendable {
    let id: String
    let displayName: String
    let description: String
    let displayPrice: String
    let price: Double
    let currencyCode: String?
    let subscriptionPeriod: String?
}

struct TransactionInfo: Encodable, Sendable {
    let transactionId: String
    let originalTransactionId: String
    let productId: String
    let expiresDateMs: Int64?
}

struct GetProductsResponse: Encodable, Sendable {
    let products: [ProductInfo]
}

struct PurchaseResponse: Encodable, Sendable {
    let status: String
    let transaction: TransactionInfo?
}

struct TransactionsResponse: Encodable, Sendable {
    let transactions: [TransactionInfo]
}

private final class InvokeResponder: @unchecked Sendable {
    private let invoke: Invoke

    init(_ invoke: Invoke) {
        self.invoke = invoke
    }

    @MainActor
    func resolve() {
        invoke.resolve()
    }

    @MainActor
    func resolve<T: Encodable & Sendable>(_ data: T) {
        invoke.resolve(data)
    }

    @MainActor
    func reject(_ message: String) {
        invoke.reject(message)
    }
}

private func periodString(_ period: Product.SubscriptionPeriod?) -> String? {
    guard let period else { return nil }
    switch period.unit {
    case .day: return "P\(period.value)D"
    case .week: return "P\(period.value)W"
    case .month: return "P\(period.value)M"
    case .year: return "P\(period.value)Y"
    @unknown default: return nil
    }
}

private func productInfo(_ product: Product) -> ProductInfo {
    var currencyCode: String? = nil
    if #available(iOS 16.0, *) {
        currencyCode = product.priceFormatStyle.currencyCode
    }
    return ProductInfo(
        id: product.id,
        displayName: product.displayName,
        description: product.description,
        displayPrice: product.displayPrice,
        price: NSDecimalNumber(decimal: product.price).doubleValue,
        currencyCode: currencyCode,
        subscriptionPeriod: periodString(product.subscription?.subscriptionPeriod)
    )
}

// 服务端会拿 transactionId 去 App Store Server API 反查权威数据，
// 因此本地 unverified 的交易也照常上抛，真正的信任判断在服务端。
private func unwrap(_ result: VerificationResult<Transaction>) -> Transaction {
    switch result {
    case .verified(let transaction): return transaction
    case .unverified(let transaction, _): return transaction
    }
}

private func transactionInfo(_ transaction: Transaction) -> TransactionInfo {
    var expiresDateMs: Int64? = nil
    if let expirationDate = transaction.expirationDate {
        expiresDateMs = Int64(expirationDate.timeIntervalSince1970 * 1000)
    }
    return TransactionInfo(
        transactionId: String(transaction.id),
        originalTransactionId: String(transaction.originalID),
        productId: transaction.productID,
        expiresDateMs: expiresDateMs
    )
}

class IapPlugin: Plugin {
    @objc public func getProducts(_ invoke: Invoke) throws {
        let args = try invoke.parseArgs(GetProductsArgs.self)
        let responder = InvokeResponder(invoke)
        Task {
            do {
                let products = try await Product.products(for: args.productIds)
                await responder.resolve(GetProductsResponse(products: products.map(productInfo)))
            } catch {
                await responder.reject("get_products_failed: \(error.localizedDescription)")
            }
        }
    }

    @objc public func purchase(_ invoke: Invoke) throws {
        let args = try invoke.parseArgs(PurchaseArgs.self)
        let responder = InvokeResponder(invoke)
        Task {
            do {
                let products = try await Product.products(for: [args.productId])
                guard let product = products.first else {
                    await responder.reject("product_not_found")
                    return
                }
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    // 不在这里 finish：等服务端确认发放后由前端调 finishTransaction，
                    // 中途失败的交易会留在 unfinished 里，下次启动可补验。
                    let transaction = unwrap(verification)
                    await responder.resolve(
                        PurchaseResponse(
                            status: "success",
                            transaction: transactionInfo(transaction)
                        ))
                case .userCancelled:
                    await responder.resolve(PurchaseResponse(status: "cancelled", transaction: nil))
                case .pending:
                    // 等待家长同意等场景，交易稍后会出现在 unfinished 中
                    await responder.resolve(PurchaseResponse(status: "pending", transaction: nil))
                @unknown default:
                    await responder.reject("purchase_unknown_result")
                }
            } catch {
                await responder.reject("purchase_failed: \(error.localizedDescription)")
            }
        }
    }

    @objc public func restorePurchases(_ invoke: Invoke) throws {
        let responder = InvokeResponder(invoke)
        Task {
            // 用户取消 App Store 登录时 sync 会抛错，此时仍返回本地缓存的权益
            try? await AppStore.sync()
            var transactions: [TransactionInfo] = []
            for await result in Transaction.currentEntitlements {
                transactions.append(transactionInfo(unwrap(result)))
            }
            await responder.resolve(TransactionsResponse(transactions: transactions))
        }
    }

    @objc public func getUnfinishedTransactions(_ invoke: Invoke) throws {
        let responder = InvokeResponder(invoke)
        Task {
            var transactions: [TransactionInfo] = []
            for await result in Transaction.unfinished {
                transactions.append(transactionInfo(unwrap(result)))
            }
            await responder.resolve(TransactionsResponse(transactions: transactions))
        }
    }

    @objc public func finishTransaction(_ invoke: Invoke) throws {
        let args = try invoke.parseArgs(FinishTransactionArgs.self)
        let responder = InvokeResponder(invoke)
        Task {
            for await result in Transaction.unfinished {
                let transaction = unwrap(result)
                if String(transaction.id) == args.transactionId {
                    await transaction.finish()
                    break
                }
            }
            // 找不到视为已 finish，幂等处理
            await responder.resolve()
        }
    }
}

@_cdecl("init_plugin_iap")
func initPluginIap() -> Plugin {
    return IapPlugin()
}
