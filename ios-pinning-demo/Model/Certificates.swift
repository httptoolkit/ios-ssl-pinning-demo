import Foundation

struct BundledCertificates {
    
    static let isrgRootCert: SecCertificate = BundledCertificates.loadCertificate(filename: "isrg-root")
    
    private static func loadCertificate(filename: String) -> SecCertificate {
        let filePath = Bundle.main.path(forResource: filename, ofType: "der")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: filePath))
        let certificate = SecCertificateCreateWithData(nil, data as CFData)!
        return certificate
    }
}
