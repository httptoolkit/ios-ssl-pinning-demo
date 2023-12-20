import Foundation

class RequestViewModel: ObservableObject {
    @Published var requests: [BaseHTTPRequest] = [
        // We use amiusing.httptoolkit.tech for unpinned requests:
        SimpleHTTPRequest(name: "Plain HTTP", url: "http://amiusing.httptoolkit.tech"),
        SimpleHTTPRequest(name: "HTTPS", url: "https://amiusing.httptoolkit.tech"),
        
        // We use sha256.badssl.com for config-pinned (in Info.plist NSPinnedDomains) requests:
        SimpleHTTPRequest(name: "Config-based pinning", url: "https://sha256.badssl.com"),
        
        // We use ecc384.badssl.com for all manually-pinned requests:
        URLSessionPinnedRequest(
            name: "URLSession pinning",
            url: "https://ecc384.badssl.com",
            // Pinned on hash of raw PK - fiddly to format to match pins elsewhere:
            pinnedCertificate: "9Fk6HgfMnM7/vtnBHcUhg1b3gU2bIpSd50XmKZkMbGA="
        ),
        
        AlamofireSimpleHTTPRequest(
            name: "Alamofire cert pinning",
            url: "https://ecc384.badssl.com"
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
        )
    ]
    
    @Published var currentError: RequestError?

    func sendRequest(_ httpRequest: BaseHTTPRequest) {
        Task {
            do {
                try await httpRequest.run()
            } catch {
                DispatchQueue.main.async {
                    self.currentError = RequestError(localizedDescription: error.localizedDescription)
                    httpRequest.status = .failure
                }
            }
        }
    }
}

enum RequestStatus {
    case none, success, failure
}

struct RequestError: Identifiable, Error {
    let id = UUID()
    let localizedDescription: String
}
