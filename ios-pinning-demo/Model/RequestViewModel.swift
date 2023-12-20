import Foundation

class RequestViewModel: ObservableObject {
    @Published var unpinnedRequests: [BaseHTTPRequest] = [
        // We use amiusing.httptoolkit.tech for unpinned requests:
        SimpleHTTPRequest(name: "Plain HTTP", url: "http://amiusing.httptoolkit.tech"),
        SimpleHTTPRequest(name: "HTTPS", url: "https://amiusing.httptoolkit.tech"),
        AlamofireSimpleHTTPRequest(name: "Alamofire HTTPS", url: "https://amiusing.httptoolkit.tech"),
        AFNetworkingSimpleHTTPRequest(name: "AFNetworking HTTPS", url: "https://amiusing.httptoolkit.tech")
    ]
    
    @Published var pinnedRequests: [BaseHTTPRequest] = [
        // We use sha256.badssl.com for config-pinned (in Info.plist NSPinnedDomains) requests:
        SimpleHTTPRequest(name: "Config-based pinning", url: "https://sha256.badssl.com"),
        
        // We use ecc384.badssl.com for all manually-pinned requests:
        URLSessionPinnedRequest(
            name: "URLSession pinning",
            url: "https://ecc384.badssl.com",
            // Pinned on hash of raw PK - fiddly to format to match pins elsewhere:
            pinnedCertificate: "9Fk6HgfMnM7/vtnBHcUhg1b3gU2bIpSd50XmKZkMbGA="
        ),
        
        AlamofirePinnedCertHTTPRequest(
            name: "Alamofire cert pinning",
            url: "https://ecc384.badssl.com",
            pinnedCertificate: BundledCertificates.isrgRootCert
        ),
        
        AlamofirePinnedPKHTTPRequest(
            name: "Alamofire PK pinning",
            url: "https://ecc384.badssl.com",
            pinnedKey: SecCertificateCopyKey(BundledCertificates.isrgRootCert)!
        ),
        
        AFNetworkingPinnedHTTPRequest(
            name: "AFNetworking cert pinning",
            url: "https://ecc384.badssl.com",
            pinnedCertificate: BundledCertificates.isrgRootCert
        ),
        
        TrustKitPinnedHTTPRequest(
            name: "TrustKit pinning"
            // TrustKit uses global configuration, configured to pin ecc384.badssl.com
        )
    ]
    
    func sendRequest(_ httpRequest: BaseHTTPRequest) {
        Task {
            await httpRequest.run()
        }
    }
}

enum RequestStatus {
    case none, success, failure
}
