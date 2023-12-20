import Foundation
import TrustKit

class TrustKitURLSessionDelegate: NSObject, URLSessionDelegate {

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let pinningValidator = TrustKit.sharedInstance().pinningValidator
        if pinningValidator.handle(challenge, completionHandler: completionHandler) {
            // Challenge handled by TrustKit
            return
        }

        // Not handled - we fail in this case, this delegate should only be used with TrustKit
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}
