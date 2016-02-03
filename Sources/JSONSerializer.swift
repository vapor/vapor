import Foundation

class JSONSerializer {

    class func serialize(object: Any) -> String {

        if let dict = object as? [String: Any] {
            var s = "{"
            var i = 0

            for (key, val) in dict {
                s += "\"\(key)\":\(self.serialize(val))"
                if i != (dict.count - 1) {
                    s += ","
                }
                i += 1
            }

            return s + "}"
        } else if let dict = object as? [String: String] {
            var s = "{"
            var i = 0

            for (key, val) in dict {
                s += "\"\(key)\":\(self.serialize(val))"
                if i != (dict.count - 1) {
                    s += ","
                }
                i += 1
            }

            return s + "}"
        } else if let arr = object as? [Any] {
            var s = "["

            for i in 0 ..< arr.count {
                s += self.serialize(arr[i])

                if i != (arr.count - 1) {
                    s += ","
                }
            }

            return s + "]"
        } else if let arr = object as? [String] {
            var s = "["

            for i in 0 ..< arr.count {
                s += self.serialize(arr[i])

                if i != (arr.count - 1) {
                    s += ","
                }
            }

            return s + "]"
        } else if let arr = object as? [Int] {
            var s = "["

            for i in 0 ..< arr.count {
                s += self.serialize(arr[i])

                if i != (arr.count - 1) {
                    s += ","
                }
            }

            return s + "]"
        } else if let string = object as? String {
            return "\"\(string)\""
        } else if let number = object as? Int {
            return "\(number)"
        } else {
            print(object)
            print(Mirror(reflecting: object))
            return "\"\""
        }

    }
}