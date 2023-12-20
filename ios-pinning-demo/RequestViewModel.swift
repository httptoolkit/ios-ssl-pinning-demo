import Foundation

class RequestViewModel: ObservableObject {
    @Published var requests: [HTTPRequest] = [
        // We use amiusing.httptoolkit.tech for unpinned requests:
        HTTPRequest(name: "Plain HTTP request", url: "http://amiusing.httptoolkit.tech"),
        HTTPRequest(name: "HTTPS request", url: "https://amiusing.httptoolkit.tech"),
        
        // We use sha256.badssl.com for config-pinned (in Info.plist NSPinnedDomains) requests:
        HTTPRequest(name: "Config-pinned request", url: "https://sha256.badssl.com"),
        
        // We use ecc384.badssl.com for all manually-pinned requests:
        HTTPRequest(
            name: "URLSession-pinned request",
            url: "https://ecc384.badssl.com",
            // Pinned against hash of raw PK data - fiddly to get it into the x509 format that would match Android:
            pinnedCertificate: "9Fk6HgfMnM7/vtnBHcUhg1b3gU2bIpSd50XmKZkMbGA="
        )
    ]
    @Published var currentError: RequestError?

    func sendRequest(_ httpRequest: HTTPRequest) {
        Task {
            do {
                try await httpRequest.performRequest()
            } catch {
                DispatchQueue.main.async {
                    self.currentError = RequestError(localizedDescription: error.localizedDescription)
                    httpRequest.status = .failure
                }
            }
        }
    }
}

class HTTPRequest: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    let url: String
    @Published var isLoading = false
    @Published var status: RequestStatus = .none
    var pinnedCertificate: String?

    init(name: String, url: String, pinnedCertificate: String? = nil) {
        self.name = name
        self.url = url
        self.pinnedCertificate = pinnedCertificate
    }
    
    func performRequest() async throws {
        guard let url = URL(string: url) else { throw URLError(.badURL) }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = 10

        let session: URLSession
        if (self.pinnedCertificate != nil) {
            let delegate = PinningURLSessionDelegate(pinnedCertificate: pinnedCertificate)
            session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        } else {
            session = URLSession(configuration: .default)
        }

        DispatchQueue.main.async {
            self.isLoading = true
            self.status = .none
        }

        do {
            let (_, response) = try await session.data(for: urlRequest)
            
            if ((response as! HTTPURLResponse).statusCode != 200) {
                throw URLError(.badServerResponse)
            }
            
            DispatchQueue.main.async {
                self.status = (response as? HTTPURLResponse)?.statusCode == 200 ? .success : .failure
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.status = .failure
            }
            throw error
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
