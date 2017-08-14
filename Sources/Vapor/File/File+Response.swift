import Foundation
import HTTP

public extension Response {
    /// If you are simply looking to serve files from your public directory,
    /// it may be useful to look at 'FileMiddleware' instead.
    ///
    /// Use this to initialize a file response for the exact file path.
    /// If using from a public folder for example, the file name should be appended
    /// to the public directory, ie: `drop.publicDir + "myFile.cool"`
    ///
    /// If none match represents an ETag that will be used to check if the file has
    /// changed since the last load by the client. This allows clients like browsers
    /// to cache their files and avoid downloading resources unnecessarily.
    /// Most often calculated w/
    /// https://tools.ietf.org/html/rfc7232#section-3.2
    ///
    /// For an example of how this is used, look at 'FileMiddleware'
    public convenience init(filePath: String, ifNoneMatch: String? = nil, chunkSize: Int = 2048) throws {
        guard
            let attributes = try? Foundation.FileManager.default.attributesOfItem(atPath: filePath),
            let modifiedAt = attributes[.modificationDate] as? Date,
            let fileSize = attributes[.size] as? NSNumber
        else {
            throw Abort.notFound
        }

        var headers: [HeaderKey: String] = [:]

        // Generate ETag value, "HEX value of last modified date" + "-" + "file size"
        let fileETag = "\(modifiedAt.timeIntervalSince1970)-\(fileSize.intValue)"
        headers["ETag"] = fileETag

        // Check if file has been cached already and return NotModified response if the etags match
        if fileETag == ifNoneMatch {
            self.init(status: .notModified, headers: headers, body: .data([]))
            return
        }

        // Set Content-Type header based on the media type
        // Only set Content-Type if file not modified and returned above.
        if
            let fileExtension = filePath.components(separatedBy: ".").last,
            let type = Request.mediaTypes[fileExtension]
        {
            headers["Content-Type"] = type
        }

        // Try to open the file for reading, keeping it open until the chunking finishes.
        // This is the last chance to report a Not Found error to the client.
        guard let file = fopen(filePath, "r") else {
            throw Abort.notFound
        }

        // return chunked response
        self.init(status: .ok, headers: headers, chunked: { stream in
            // the deferred fclose call must stay inside the chunking closure,
            // so the file does not get prematurely closed.
            defer {
                fclose(file)
            }

            var buffer = Array(repeating: 0, count: chunkSize)
            var bytesRead: size_t = 0

            repeat {
                bytesRead = fread(&buffer, 1, chunkSize, file)
                if bytesRead > 0 {
                    // copy the buffer into an array
                    let chunk = Array(UnsafeRawBufferPointer(
                        start: buffer,
                        count: bytesRead
                    ))

                    // write the chunk to the chunk stream
                    try stream.write(chunk)
                }
            } while bytesRead == chunkSize

            try stream.close()
        })

    }
}
