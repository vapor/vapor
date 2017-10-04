import Debugging

// FIXME: convert to struct

/// Errors that can be thrown when
/// working with entities.
public enum ModelError: Error {
    /// missing database
    case noDatabase(Model.Type)
    /// All entities from db must have an id
    case noId(Model.Type)
    /// All entities from
    case doesntExist(Model.Type)
    /// Reserved for extensions
    case unspecified(Error)
}

extension ModelError: Debuggable {
    public var identifier: String {
        switch self {
        case .noDatabase:
            return "noDatabase"
        case .noId:
            return "noId"
        case .doesntExist:
            return "doesntExist"
        case .unspecified:
            return "unspecified"
        }
    }

    public var reason: String {
        switch self {
        case .noDatabase:
            return "missing database"
        case .noId:
            return "missing id, entities can't exist in a fluent database without their id being set."
        case .doesntExist:
            return "doesn't exist yet"
        case .unspecified(let error):
            return "unspecified \(error)"
        }
    }

    public var possibleCauses: [String] {
        switch self {
        case .noDatabase(let e):
            return [
                "\(e) hasn't been added to Droplet's preparations",
                "\(e) is being used manually, and database hasn't been set"
            ]
        case .noId(let e):
            return [
                "\(e) not fetched properly",
                "loaded manually, forgot to set id"
            ]
        case .doesntExist(let e):
            return [
                "\(e) not fetched properly",
                "loaded manually, forgot to set exists"
            ]
        case .unspecified(_):
            return [
                "received unspecified or unknown error"
            ]
        }
    }

    public var suggestedFixes: [String] {
        switch self {
        case .noDatabase(let e):
            return [
                "make sure to call `database.prepare(\(e).self)` or ensure that it's added to your Droplet's `preparations` with `drop.preprations.append(\(e).self)",
                "you can also set the `.database` property on `\(e)` manually: `\(e).database = db"
            ]
        case .noId(_):
            return [
                "make sure you're fetching properly from fluent or setting 'exists' manually if necessary."
            ]
        case .doesntExist(_):
            return [
                "if you're using custom behavior, make sure to set exists to true after fetching from database"
            ]
        case .unspecified(_):
            return [
                "occasionally upgrading can resolve or give better errors"
            ]
        }
    }
}
