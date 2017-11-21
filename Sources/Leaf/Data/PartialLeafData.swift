internal final class PartialLeafData {
    var context: LeafData
    init() {
        self.context = .dictionary([:])
    }

    func set(to value: LeafData, at path: [CodingKey]) {
        print()
        print("\(path): \(self.context)")

        set(&context, to: value, at: path)

        print("\(path): \(self.context)")
        print()
    }

    private func set(_ context: inout LeafData, to value: LeafData?, at path: [CodingKey]) {
        let end = path[0]

        var child: LeafData?
        switch path.count {
        case 0:
            context = value ?? .null
        case 1:
            child = value
        case 2...:
            if let index = end as? ArrayKey {
                let array = context.array ?? []
                if array.count > index.index {
                    child = array[index.index]
                } else {
                    child = LeafData.array([])
                }
                set(&child!, to: value, at: Array(path[1...]))
            } else {
                child = context.dictionary?[end.stringValue] ?? LeafData.dictionary([:])
                set(&child!, to: value, at: Array(path[1...]))
            }
        default: break
        }

        if let index = end as? ArrayKey {
            if case .array(var arr) = context {
                if arr.count > index.index {
                    arr[index.index] = child ?? .null
                } else {
                    arr.append(child ?? .null)
                }
                context = .array(arr)
            } else if let child = child {
                context = .array([child])
            }
        } else {
            if case .dictionary(var dict) = context {
                dict[path[0].stringValue] = child
                context = .dictionary(dict)
            } else if let child = child {
                context = .dictionary([
                    path[0].stringValue: child
                ])
            }
        }
    }

    /// Returns the value, if one at from the given path.
    func get(at path: [CodingKey]) -> LeafData? {
        var child = context

        for seg in path {
            guard let c = child.dictionary?[seg.stringValue] else {
                return nil
            }
            child = c
        }

        return child
    }
}
