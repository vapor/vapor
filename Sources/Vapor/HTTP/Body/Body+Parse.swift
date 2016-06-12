extension Body {
    /*
        4.3 Message Body

        The message-body (if any) of an HTTP message is used to carry the
        entity-body associated with the request or response. The message-body
        differs from the entity-body only when a transfer-coding has been
        applied, as indicated by the Transfer-Encoding header field (section
        14.41).
    */
    init(headers: Headers, stream: Stream) throws {
        let body: Bytes

        if let contentLength = headers["content-length"]?.int {
            body = try stream.receive(max: contentLength)
        } else if
            let transferEncoding = headers["transfer-encoding"]?.string
            where transferEncoding.lowercased() == "chunked"
        {
            /*
                3.6.1 Chunked Transfer Coding

                The chunked encoding modifies the body of a message in order to
                transfer it as a series of chunks, each with its own size indicator,
                followed by an OPTIONAL trailer containing entity-header fields. This
                allows dynamically produced content to be transferred along with the
                information necessary for the recipient to verify that it has
                received the full message.
            */
            var buffer: Bytes = []

            while true {
                let lengthData = try stream.nextLine(timeout: 30)

                // size must be sent
                guard lengthData.count > 0 else {
                    break
                }

                // convert hex length data to int
                let length = lengthData.int

                // end of chunked encoding
                if length == 0 {
                    break
                }

                let content = try stream.receive(max: length + 2)
                buffer += content
            }
            
            body = buffer
        } else {
            body = []
        }

        self = .buffer(Data(body))
    }
}
