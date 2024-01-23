import Foundation
import CryptoKit

@available(iOS 15.0, *)
class PinningURLSessionDelegate: NSObject, URLSessionDelegate {
    var pinnedCertificate: String

    init(pinnedCertificate: String) {
        self.pinnedCertificate = pinnedCertificate
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?
    ) -> Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        if SecTrustEvaluateWithError(serverTrust, nil) {
            if let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] {
                for serverCertificate in certificateChain {
                    guard let publicKey = SecCertificateCopyKey(serverCertificate) else {
                        print("Error reading public key from certificate")
                        continue
                    }
                    
                    var error: Unmanaged<CFError>?
                    guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
                        print("Error retrieving public key data: \(error!.takeRetainedValue() as Error)")
                        return
                    }
                    
                    let publicKeyHash = SHA256.hash(data: publicKeyData)
                    let publicKeyHashBase64 = Data(publicKeyHash).base64EncodedString()

                    if publicKeyHashBase64 == pinnedCertificate {
                        completionHandler(.useCredential, URLCredential(trust: serverTrust))
                        return
                    }
                }
            }
        }

        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}
