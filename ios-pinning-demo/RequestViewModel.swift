import Foundation

class RequestViewModel: ObservableObject {
    @Published var requests: [BaseHTTPRequest] = [
        // We use amiusing.httptoolkit.tech for unpinned requests:
        SimpleHTTPRequest(name: "Plain HTTP request", url: "http://amiusing.httptoolkit.tech"),
        SimpleHTTPRequest(name: "HTTPS request", url: "https://amiusing.httptoolkit.tech"),
        
        // We use sha256.badssl.com for config-pinned (in Info.plist NSPinnedDomains) requests:
        SimpleHTTPRequest(name: "Config-pinned request", url: "https://sha256.badssl.com"),
        
        // We use ecc384.badssl.com for all manually-pinned requests:
        URLSessionPinnedRequest(
            name: "URLSession-pinned request",
            url: "https://ecc384.badssl.com",
            // Pinned on hash of raw PK - fiddly to format to match pins elsewhere:
            pinnedCertificate: "9Fk6HgfMnM7/vtnBHcUhg1b3gU2bIpSd50XmKZkMbGA="
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
