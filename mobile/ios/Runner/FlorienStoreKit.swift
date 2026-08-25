import CryptoKit
import Foundation
import StoreKit

/// Maps a Firebase Auth uid to StoreKit 2 `appAccountToken` (RFC 4122 UUID v5).
/// Apple only accepts a UUID here — the raw Firebase uid is silently dropped.
enum FlorienAppAccountToken {
  /// RFC 4122 URL namespace. Must match Dart and Cloud Functions.
  private static let urlNamespace = UUID(
    uuid: (0x6B, 0xA7, 0xB8, 0x11, 0x9D, 0xAD, 0x11, 0xD1, 0x80, 0xB4, 0x00, 0xC0, 0x4F, 0xD4, 0x30, 0xC8)
  )

  static func uuid(forFirebaseUID uid: String) -> UUID {
    var namespace = urlNamespace.uuid
    var data = withUnsafeBytes(of: &namespace) { Data($0) }
    data.append(Data("florien.uid:\(uid)".utf8))
    let digest = Insecure.SHA1.hash(data: data)
    var bytes = Array(digest)
    bytes[6] = (bytes[6] & 0x0F) | 0x50
    bytes[8] = (bytes[8] & 0x3F) | 0x80
    return UUID(uuid: (
      bytes[0], bytes[1], bytes[2], bytes[3],
      bytes[4], bytes[5], bytes[6], bytes[7],
      bytes[8], bytes[9], bytes[10], bytes[11],
      bytes[12], bytes[13], bytes[14], bytes[15]
    ))
  }
}

enum FlorienStoreKitError: LocalizedError {
  case notSignedIn
  case productNotFound

  var errorDescription: String? {
    switch self {
    case .notSignedIn:
      return "Firebase user is not signed in."
    case .productNotFound:
      return "StoreKit product was not found."
    }
  }
}

/// Native StoreKit 2 purchase that attaches the signed-in Firebase uid
/// as `appAccountToken` so App Store Server Notifications V2 can re-bind
/// the subscription when the same Apple ID switches Firebase accounts.
enum FlorienStoreKit {
  @MainActor
  static func purchase(productId: String, firebaseUID: String) async throws -> [String: Any] {
    let uid = firebaseUID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !uid.isEmpty else { throw FlorienStoreKitError.notSignedIn }

    let products = try await Product.products(for: [productId])
    guard let product = products.first else { throw FlorienStoreKitError.productNotFound }

    let appAccountToken = FlorienAppAccountToken.uuid(forFirebaseUID: uid)
    let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])

    switch result {
    case .success(let verification):
      let transaction = try verification.payloadValue
      let originalTransactionId = String(transaction.originalID)
      await transaction.finish()
      return [
        "status": "purchased",
        "jws": verification.jwsRepresentation,
        "productId": transaction.productID,
        "originalTransactionId": originalTransactionId,
        "appAccountToken": appAccountToken.uuidString.lowercased(),
      ]
    case .userCancelled:
      return ["status": "cancelled"]
    case .pending:
      return ["status": "pending"]
    @unknown default:
      return ["status": "unknown"]
    }
  }
}
