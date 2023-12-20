import Foundation
import Alamofire

class BaseHTTPRequest: Identifiable, ObservableObject {
    let id = UUID()
    var name: String
    var url: String
    
    @Published var isLoading = false
    @Published var status: RequestStatus = .none

    init(name: String, url: String) {
        self.name = name
        self.url = url
    }
    
    func run() async throws {
        URLCache.shared.removeAllCachedResponses()
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.status = .none
        }
        
        do {
            let status = try await performRequest()
            
            if (status != 200) {
                throw URLError(.badServerResponse)
            }
            
            DispatchQueue.main.async {
                self.status = .success
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.status = .failure
            }
            
            // Rethrow so the UI can show the failure details
            throw error
        }
    }

    func performRequest() async throws -> Int {
        preconditionFailure("performRequest must be overloaded for each case")
    }
}

class SimpleHTTPRequest: BaseHTTPRequest {
    override func performRequest() async throws -> Int {
        let url = URL(string: url)!
        
        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = 10
        urlRequest.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData

        let session = buildSession()

        let (_, response) = try await session.data(for: urlRequest)
        return (response as! HTTPURLResponse).statusCode
    }
    
    func buildSession() -> URLSession {
        return URLSession(configuration: .default)
    }
}

class URLSessionPinnedRequest: SimpleHTTPRequest {
    
    let pinnedCertificate: String
    
    init(name: String, url: String, pinnedCertificate: String) {
        self.pinnedCertificate = pinnedCertificate
        super.init(name: name, url: url)
    }
    
    override func buildSession() -> URLSession {
        let delegate = PinningURLSessionDelegate(pinnedCertificate: pinnedCertificate)
        return URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )
    }
    
}

class AlamofireBaseHTTPRequest: BaseHTTPRequest {
    
    let evaluators: [String: ServerTrustEvaluating]
    
    init(name: String, url: String, evaluators: [String: ServerTrustEvaluating]) {
        self.evaluators = evaluators
        super.init(name: name, url: url)
    }
    
    override func performRequest() async throws -> Int {
        // Disable all caching:
        let configuration = URLSessionConfiguration.af.default
        configuration.urlCache = nil

        let session = Session(
            configuration: configuration,
            serverTrustManager: ServerTrustManager(
                allHostsMustBeEvaluated: !self.evaluators.isEmpty,
                evaluators: self.evaluators
            )
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request(self.url).response { response in
                switch response.result {
                    case .success:
                        continuation.resume(returning: response.response!.statusCode)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                }
            }
        }
    }
}

class AlamofireSimpleHTTPRequest: AlamofireBaseHTTPRequest {
    
    init(name: String, url: String) {
        super.init(name: name, url: url, evaluators: [:])
    }
    
}

class AlamofirePinnedCertHTTPRequest: AlamofireBaseHTTPRequest {
    
    init(name: String, url: String, pinnedCertificate: SecCertificate) {
        let evaluators = [URL(string: url)!.host!: PinnedCertificatesTrustEvaluator(
            certificates: [pinnedCertificate],
            acceptSelfSignedCertificates: false,
            performDefaultValidation: true,
            validateHost: true
        )]
        
        super.init(name: name, url: url, evaluators: evaluators)
    }
    
}

class AlamofirePinnedPKHTTPRequest: AlamofireBaseHTTPRequest {
    
    init(name: String, url: String, pinnedKey: SecKey) {
        let evaluators = [URL(string: url)!.host!: PublicKeysTrustEvaluator(
            keys: [pinnedKey],
            performDefaultValidation: true,
            validateHost: true
        )]
        
        super.init(name: name, url: url, evaluators: evaluators)
    }
    
}

import TrustKit

var trustKitInitialized = false

class TrustKitPinnedHTTPRequest: SimpleHTTPRequest {
    
    init(name: String) {
        super.init(name: name, url: "https://ecc256.badssl.com")
    }
    
    override func buildSession() -> URLSession {
        // Initialize when first clicked:
        if (!trustKitInitialized) {
            TrustKit.initSharedInstance(withConfiguration: [
                kTSKSwizzleNetworkDelegates: false,
                kTSKEnforcePinning: true,
                kTSKPinnedDomains: [
                    "ecc256.badssl.com": [
                        kTSKPublicKeyHashes: [
                            "C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M=",
                            // A backup pin is required, so we add a dud:
                            "ABCABCABCABCABCABCABCABCABCABCABCABCABCABCA="
                        ]
                    ]
                ]
            ])
            trustKitInitialized = true
        }
        
        return URLSession(
            configuration: .default,
            delegate: TrustKitURLSessionDelegate(),
            delegateQueue: nil
        )
    }
    
}
