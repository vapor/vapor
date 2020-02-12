extension HTTPHeaders {
    /// Gets the value of the `Cache-Control` header, if present.
    public func getCacheControl() -> HTTPHeaderCacheControl? {
        guard let cacheControl = firstValue(name: .cacheControl) else {
            return nil
        }

        return HTTPHeaderCacheControl(stringLiteral: cacheControl)
    }

    /// Gets the value of the `Expires` header, if present.
    /// ### Note ###
    /// `Expires` is legacy and you should switch to using `Cache-Control` if possible.
    public func getExpires() -> HTTPHeaderExpires? {
        HTTPHeaderExpires(headers: self)
    }

    /// Determines when the cached data should be expired.
    ///
    /// This first checks to see if the `Cache-Control` header is present.  If it is, and `no-store`
    /// is set, then `nil` is returned.  If `no-store` is not present, and there is a `max-age` then
    /// the expiration will add that many seconds to `requestSentAt`.
    ///
    /// If no `Cache-Control` header is present then it will examine the `Expires` header.
    ///
    /// - Parameter requestSentAt: Should be passed the `Date` when the request was sent.
    public func getExpirationDate(requestSentAt: Date) -> Date? {
        // Cache-Control header takes priority over the Expires header
        if let cacheControl = getCacheControl() {
            guard !cacheControl.contains(.noStore) else {
                return nil
            }

            if let age = cacheControl.maxAge {
                return requestSentAt.addingTimeInterval(TimeInterval(age))
            }
        }

        if let expires = getExpires() {
            return expires.expires
        }

        return nil
    }
}
