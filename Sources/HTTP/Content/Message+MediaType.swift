// MARK: Message

extension HTTPMessage {
    /// The MediaType inside the `Message` `Headers`' "Content-Type"
    public var mediaType: MediaType? {
        get {
            guard let contentType = headers[.contentType] else {
                return nil
            }
            
            return MediaType(string: contentType)
        }
        set {
            headers[.contentType] = newValue?.description
        }
    }
}
