import Foundation
import HTTP

extension Request {
    /// URL endoed form data from the URI query.
    public var query: URLEncodedForm? {
        get {
            if let existing = storage["query"] as? URLEncodedForm {
                return existing
            } else if let query = uri.query {
                guard let queryData = query.data(using: .utf8) else {
                    return nil
                }
                do {
                    let query = try URLEncodedForm.parse(data: queryData)
                    storage["query"] = query
                    return query
                } catch {
                    print("Failed to parse query: \(error)")
                    return nil
                }
            } else {
                return nil
            }
        }
        set(data) {
            let query: Data?
            do {
                query = try data?.serialize()
            } catch {
                print("Failed to serialize query: \(error)")
                return
            }
            if let query = query, !query.isEmpty {
                uri.query = query.makeString()
                storage["urlencoded:query"] = data
            } else {
                storage["urlencoded:query"] = nil
                uri.query = nil
            }
        }
    }
}


