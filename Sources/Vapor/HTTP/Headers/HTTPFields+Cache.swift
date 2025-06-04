import Foundation
import HTTPTypes

extension HTTPFields {
    /// Determines when the cached data should be expired.
    ///
    /// This first checks to see if the `Cache-Control` header is present.  If it is, and `no-store`
    /// is set, then `nil` is returned.  If `no-store` is not present, and there is a `max-age` then
    /// the expiration will add that many seconds to `requestSentAt`.
    ///
    /// If no `Cache-Control` header is present then it will examine the `Expires` header.
    ///
    /// If you need finer grained details about what type of caching, validation, etc... you should instead
    /// grab the `cacheControl` and `expires` headers yourself.
    ///
    /// - Parameter requestSentAt: Should be passed the `Date` when the request was sent.
    public func expirationDate(requestSentAt: Date) -> Date? {
        // Cache-Control header takes priority over the Expires header
        if let cacheControl = cacheControl {
            guard cacheControl.noStore == false else {
                return nil
            }

            if let age = cacheControl.maxAge {
                return requestSentAt.addingTimeInterval(TimeInterval(age))
            }
        }

        if let expires = expires {
            return expires.expires
        }

        return nil
    }
}
