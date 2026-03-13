import Foundation
import SwiftUI
import UIKit

#if canImport(StripeFinancialConnections)
import StripeCore
import StripeFinancialConnections
#endif

/// Return URL for Stripe Financial Connections (must match URL scheme in Info.plist — we use "anita").
private let stripeReturnURL = "anita://stripe-redirect"

/// Starts the Stripe Financial Connections flow: backend session → present sheet on main thread.
final class BankConnectionTester: ObservableObject {
    static let shared = BankConnectionTester()
    
    #if canImport(StripeFinancialConnections)
    private var sheet: FinancialConnectionsSheet?
    #endif
    
    private init() {}
    
    /// 1) Fetches client_secret from backend. 2) Presents FinancialConnectionsSheet on main thread.
    func startTestFlow(userId: String, userEmail: String?) async throws {
        let response = try await NetworkService.shared.createFinancialConnectionsSession(
            userId: userId,
            userEmail: userEmail
        )
        
        guard let clientSecret = response.clientSecret, !clientSecret.isEmpty else {
            throw NetworkError.apiError(response.error ?? "Missing client_secret from backend.")
        }
        
        #if canImport(StripeFinancialConnections)
        await presentSheetOnMain(clientSecret: clientSecret)
        #else
        print("[BankConnectionTester] Session created. Add StripeFinancialConnections to target to show the window.")
        #endif
    }
    
    #if canImport(StripeFinancialConnections)
    @MainActor
    private func presentSheetOnMain(clientSecret: String) async {
        StripeAPI.defaultPublishableKey = Config.stripePublishableKey
        sheet = FinancialConnectionsSheet(
            financialConnectionsSessionClientSecret: clientSecret,
            returnURL: stripeReturnURL
        )
        
        guard let rootVC = topMostViewController() else {
            print("[BankConnectionTester] No root view controller.")
            return
        }
        
        sheet?.present(from: rootVC) { result in
            switch result {
            case .completed:
                print("[BankConnectionTester] Completed.")
            case .canceled:
                print("[BankConnectionTester] Canceled.")
            case .failed(let error):
                print("[BankConnectionTester] Failed: \(error.localizedDescription)")
            @unknown default:
                break
            }
        }
    }
    
    private func topMostViewController() -> UIViewController? {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first,
            let window = scene.windows.first(where: { $0.isKeyWindow }),
            var root = window.rootViewController
        else { return nil }
        while let presented = root.presentedViewController { root = presented }
        return root
    }
    #endif
}
