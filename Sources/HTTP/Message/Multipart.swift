import Foundation

extension MultipartParser {
    /// Parses a request's body as Multipart
    ///
    /// Uses the boundary that's in the `Content-Type` header to parse the multipart.
    public static func parse(request: Request) throws -> Multipart {
        let multipart = "multipart/"
        
        // Check the header
        guard
            let header = request.headers[.contentType],
            header.starts(with: multipart),
            let range = header.range(of: "boundary=") else {
                throw Error(identifier: "multipart-boundary", reason: "No multipart boundary found in the Content-Type header")
        }
        
        // Extract the boundary from the headers
        let boundary = header[range.upperBound...]
        
        // Parse this multipart using the boundary
        return try self.parse(multipart: request.body.data, boundary: Data(boundary.utf8))
    }
}
