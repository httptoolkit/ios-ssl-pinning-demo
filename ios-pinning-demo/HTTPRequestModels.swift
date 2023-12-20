import Foundation

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
        guard let url = URL(string: url) else { throw URLError(.badURL) }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = 10

        let session = URLSession(configuration: .default)

        let (_, response) = try await session.data(for: urlRequest)
        return (response as! HTTPURLResponse).statusCode
    }
}

class URLSessionPinnedRequest: BaseHTTPRequest {
    
    let pinnedCertificate: String?
    
    init(name: String, url: String, pinnedCertificate: String? = nil) {
        self.pinnedCertificate = pinnedCertificate
        super.init(name: name, url: url)
    }
    
    override func performRequest() async throws -> Int {
        guard let url = URL(string: url) else { throw URLError(.badURL) }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = 10

        let delegate = PinningURLSessionDelegate(pinnedCertificate: pinnedCertificate)
        let session = URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )

        let (_, response) = try await session.data(for: urlRequest)
        return (response as! HTTPURLResponse).statusCode
    }
}
