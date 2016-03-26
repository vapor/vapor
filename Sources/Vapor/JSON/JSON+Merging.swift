extension Json {

    /** Recursively merges two Json objects */
    mutating func merge(with json: Json) {
        switch json {
            case .Object(let object):
                guard case let .Object(object2) = self else {
                    self = json
                    return
                }

                var merged = object2

                for (key, value) in object {
                    if let original = merged[key] {
                        var newValue = original
                        newValue.merge(with: value)
                        merged[key] = newValue
                    } else {
                        merged[key] = value
                    }
                }

                self = .Object(merged)
            case .Array(let array):
                guard case let .Array(array2) = self else {
                    self = json
                    return
                }

                self = .Array(array + array2)
            default:
                self = json
        }

    }

}
