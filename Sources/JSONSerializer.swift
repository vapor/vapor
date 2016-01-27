import Foundation

class JSONSerializer {

    class func serializeDict(dict: [String: Any]) -> String {
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
    }

    class func serializeArr(arr: [Any]) -> String {
        var s = "["

        for i in 0 ..< arr.count {
            s += self.serialize(arr[i])

            if i != (arr.count - 1) {
                s += ","
            }
        }

        return s + "]"
    }

    class func serialize(object: Any) -> String {

        if let dict = object as? [String: Any] {
            return self.serializeDict(dict)
        } else if let dict = object as? [String: String] {
            return self.serializeDict(dict)
        } else if let array = object as? [Any] {
            return self.serializeArr(array)
        } else if let array = object as? [String] {
            return self.serializeArr(array)
        } else if let array = object as? [Int] {
            return self.serializeArr(array)
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