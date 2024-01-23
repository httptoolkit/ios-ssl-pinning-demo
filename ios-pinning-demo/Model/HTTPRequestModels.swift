import Foundation
import Alamofire
import TrustKit
import AFNetworking

class BaseHTTPRequest: Identifiable, ObservableObject {
    
    let id = UUID()
    let name: String
    let url: String
    
    @Published var isLoading = false
    @Published var status: RequestStatus = .none

    init(name: String, url: String) {
        self.name = name
        self.url = url
    }
    
    func run() async {
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
            print("\(name) failed with: \(error)")
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.status = .failure
            }
        }
    }
    
    func isAvailable() -> Bool {
        return true
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
    
    override func isAvailable() -> Bool {
        if #available(iOS 15.0, *) {
            return true
        } else {
            return false
        }
    }
    
    override func buildSession() -> URLSession {
        if #available(iOS 15.0, *) {
            let delegate = PinningURLSessionDelegate(pinnedCertificate: pinnedCertificate)
            return URLSession(
                configuration: .default,
                delegate: delegate,
                delegateQueue: nil
            )
        } else {
            fatalError("URLSessionPinnedRequest is not available before iOS 15")
        }
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

var trustKitInitialized = false

class TrustKitPinnedHTTPRequest: SimpleHTTPRequest {
    
    init(name: String) {
        super.init(name: name, url: "https://ecc384.badssl.com")
    }
    
    override func buildSession() -> URLSession {
        // Initialize when first clicked:
        if (!trustKitInitialized) {
            TrustKit.initSharedInstance(withConfiguration: [
                kTSKSwizzleNetworkDelegates: false,
                kTSKEnforcePinning: true,
                kTSKPinnedDomains: [
                    "ecc384.badssl.com": [
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

class AFNetworkingSimpleHTTPRequest: BaseHTTPRequest {
    
    override func performRequest() async throws -> Int {
        let manager = buildManager()
        
        return try await withCheckedThrowingContinuation { continuation in
            manager.get("/", parameters: nil, headers: nil, progress: nil, success: { (task, responseObject) in
                let httpResponse = task.response as! HTTPURLResponse
                continuation.resume(returning: httpResponse.statusCode)
            }, failure: { (task, error) in
                continuation.resume(throwing: error)
            })
        }
    }
    
    func buildManager() -> AFHTTPSessionManager {
        let manager = AFHTTPSessionManager(
            baseURL: URL(string: self.url)
        )
        manager.responseSerializer = AFHTTPResponseSerializer()
        return manager
    }

}

class AFNetworkingPinnedHTTPRequest: AFNetworkingSimpleHTTPRequest {
    
    let pinnedCertificate: SecCertificate
    
    init(name: String, url: String, pinnedCertificate: SecCertificate) {
        self.pinnedCertificate = pinnedCertificate
        super.init(name: name, url: url)
    }
    
    override func buildManager() -> AFHTTPSessionManager {
        let manager = super.buildManager()
        
        let securityPolicy = AFSecurityPolicy(pinningMode: .certificate)
        securityPolicy.pinnedCertificates = Set(
            [SecCertificateCopyData(self.pinnedCertificate)] as! [Data]
        )
        securityPolicy.validatesDomainName = true
        manager.securityPolicy = securityPolicy
        
        return manager
    }

}
