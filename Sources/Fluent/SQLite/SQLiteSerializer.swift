#if !NO_SQLITE

    import SQLite

    /// SQLite-specific overrides for the GeneralSQLSerializer
    public class SQLiteSerializer<E: Entity>: GeneralSQLSerializer<E> {
        /// Serializes a SQLite data type.
        public override func type(_ type: Field.DataType, primaryKey: Bool) -> String {
            // SQLite has a design where any data type that does not contain `TEXT`,
            // `CLOB`, or `CHAR` will be treated with `NUMERIC` affinity.
            // All SQLite `STRING` fields should instead be declared with `TEXT`.
            // More information: https://www.sqlite.org/datatype3.html
            switch type {
            case .bool:
                return "INTEGER"
            case .bytes:
                return "BLOB"
            case .date:
                return "TEXT"
            case .double:
                return "REAL"
            case .id(let idType):
                let string: String
                switch idType {
                case .int:
                    string = "INTEGER"
                case .uuid:
                    string = "TEXT"
                case .custom(let custom):
                    string = custom
                }
                if primaryKey {
                    return "\(string) PRIMARY KEY"
                } else {
                    return string
                }
            case .int:
                return "INTEGER"
            case .string:
                return "TEXT"
            case .custom(let type):
                return type
            }
        }

        public override func foreignKey(_ foreignKey: RawOr<ForeignKey>) -> String {
            switch foreignKey {
            case .raw(let string, _):
                return string
            case .some(let foreignKey):
                return "FOREIGN KEY (`\(foreignKey.field)`) REFERENCES `\(foreignKey.foreignEntity.entity)` (`\(foreignKey.foreignField)`)"
            }
        }
    }
    
#endif
