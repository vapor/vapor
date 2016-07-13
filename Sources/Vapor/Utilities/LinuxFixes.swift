import Foundation

#if os(Linux)
    extension NSData {
        var count: Int {
            return length
        }

        func copyBytes(to bytes: UnsafeMutablePointer<Void>, count: Int) {
            getBytes(bytes, length: count)
        }
    }

    typealias JSONSerialization = Foundation.NSJSONSerialization

    extension Foundation.NSMutableDictionary {
        public subscript(key: String) -> AnyObject? {
            get {
                return self.objectForKey(NSString(string: key))
            }
            set {
                guard let value = newValue else {
                    return
                }
                self.setObject(value, forKey: NSString(string: key))
            }
        }
    }

    extension Foundation.NSMutableArray {
        public func add(_ object: AnyObject) {
            self.addObject(object)
        }
    }
#endif
