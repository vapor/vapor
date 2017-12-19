/// A reference type wrapper around LeafData for passing
/// between multiple encoders.
internal final class PartialLeafData {
    /// The in-progress leaf data.
    var context: LeafData

    /// Creates a new partial leaf data.
    init() {
        self.context = .dictionary([:])
    }

    /// Sets the partial leaf data to a value at the given path.
    func set(to value: LeafData, at path: [CodingKey]) {
        set(&context, to: value, at: path)
    }

    /// Sets mutable leaf input to a value at the given path.
    private func set(_ context: inout LeafData, to value: LeafData?, at path: [CodingKey]) {
        guard path.count >= 1 else {
            context = value ?? .null
            return
        }

        let end = path[0]

        var child: LeafData?
        switch path.count {
        case 1:
            child = value
        case 2...:
            if let index = end.intValue {
                let array = context.array ?? []
                if array.count > index {
                    child = array[index]
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

        if let index = end.intValue {
            if case .array(var arr) = context {
                if arr.count > index {
                    arr[index] = child ?? .null
                } else {
                    arr.append(child ?? .null)
                }
                context = .array(arr)
            } else if let child = child {
                context = .array([child])
            }
        } else {
            if case .dictionary(var dict) = context {
                dict[end.stringValue] = child
                context = .dictionary(dict)
            } else if let child = child {
                context = .dictionary([
                    end.stringValue: child
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
