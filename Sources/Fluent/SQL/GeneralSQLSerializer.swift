/// Serializers a Query into general SQL
open class GeneralSQLSerializer<E: Model>: SQLSerializer {
    public let query: Query<E>
    public required init(_ query: Query<E>) {
        self.query = query
    }

    open func serialize() -> (String, [Node]) {
        switch query.action {
        case .create:
            return insert()
        case .fetch(let computedFields):
            return select(computedFields)
        case .aggregate(let field, let agg):
            return aggregate(field ?? "*", agg)
        case .delete:
            return delete()
        case .modify:
            return modify()
        case .schema(let schema):
            switch schema {
            case .create(let fields, let foreignKeys):
                return create(fields, foreignKeys)
            case .createIndex(let index):
                return createIndex(index)
            case .deleteIndex(let index):
                return deleteIndex(index)
            case .modify(
                let fields,
                let foreignKeys,
                let deleteFields,
                let deleteForeignKeys
            ):
                return alter(
                    add: fields,
                    foreignKeys,
                    delete: deleteFields,
                    deleteForeignKeys
                )
            case .delete:
                return drop()
            }
        }
    }

    // MARK: Data

    open func insert() -> (String, [Node]) {
        var statement: [String] = []

        statement += "INSERT INTO"
        statement += escape(E.entity)

        let bind: [Node]

        if !query.data.isEmpty {
            statement += keys(query.data.keys.array)
            statement += "VALUES"
            let (fragment, nodes) = values(query.data.values.array)
            statement += fragment
            bind = nodes
        } else {
            bind = []
        }

        return (
            concatenate(statement),
            bind
        )
    }

    open func select(_ computedFields: [RawOr<ComputedField>]) -> (String, [Node]) {
        var statement: [String] = []
        var values: [Node] = []

        let table = escape(E.entity)
        
        var columns: [String] = ["\(table).*"]
        
        statement += "SELECT"
        if query.isDistinct {
            statement += "DISTINCT"
        }
        
        for c in computedFields {
            columns += computedField(c)
        }
        
        statement += columns.joined(separator: ", ")
        statement += "FROM"
        statement += table

        if !query.joins.isEmpty {
            statement += joins(query.joins)
        }

        if !query.filters.isEmpty {
            let (filtersClause, filtersValues) = filters(query.filters)
            statement += filtersClause
            values += filtersValues
        }

        if !query.sorts.isEmpty {
            statement += sorts(query.sorts)
        }

        if let l = query.limits.first {
            statement += limit(l)
        }

        return (
            concatenate(statement),
            values
        )
    }

    open func aggregate(_ field: String, _ aggregate: Aggregate) -> (String, [Node]) {
        let fieldEscaped: String
        switch field {
        case "*":
            fieldEscaped = field
            
        default:
            let e = escape(E.entity)
            let f = escape(field)
            fieldEscaped = "\(e).\(f)"
        }
        
        var statement: [String] = []
        var values: [Node] = []

        statement += "SELECT"
        if query.isDistinct {
            statement += "DISTINCT"
        }
        
        let function: String
        switch aggregate {
        case .average: function = "AVG"
        case .count: function = "COUNT"
        case .min: function = "MIN"
        case .max: function = "MAX"
        case .sum: function = "SUM"
        case .custom(let string): function = string
        }
        
        statement += "\(function)(\(fieldEscaped)) as _fluent_aggregate FROM"
        statement += escape(E.entity)

        if !query.joins.isEmpty {
            statement += joins(query.joins)
        }

        if !query.filters.isEmpty {
            let (filtersClause, filtersValues) = filters(query.filters)
            statement += filtersClause
            values += filtersValues
        }

        return (
            concatenate(statement),
            values
        )
    }
    
    open func delete() -> (String, [Node]) {
        var statement: [String] = []
        var values: [Node] = []

        statement += "DELETE"
        if !query.joins.isEmpty {
            statement += escape(E.entity)
        }
        statement += "FROM"
        statement += escape(E.entity)
        
        if !query.joins.isEmpty {
            statement += joins(query.joins)
        }

        if !query.filters.isEmpty {
            let (filtersClause, filtersValues) = filters(query.filters)
            statement += filtersClause
            values += filtersValues
        }
        
        if !query.sorts.isEmpty {
            statement += sorts(query.sorts)
        }

        if let l = query.limits.first {
            statement += limit(l)
        }

        return (
            concatenate(statement),
            values
        )
    }

    open func modify() -> (String, [Node]) {
        var statement: [String] = []

        var values: [Node] = []

        statement += "UPDATE"
        statement += escape(E.entity)
        statement += "SET"

        if !query.data.isEmpty {
            var fragments: [String] = []

            query.data.forEach { (key, value) in
                let keyString: String
                switch key {
                case .raw(let raw, _):
                    keyString = raw
                case .some(let some):
                    keyString = escape(some)
                }
                
                
                let valueString: String
                switch value {
                case .raw(let raw, _):
                    valueString = raw
                case .some(let some):
                    valueString = placeholder(some)
                    values.append(some)
                }
                fragments += keyString + " = " + valueString
            }

            statement += fragments.joined(separator: ", ")
        }

        if !query.filters.isEmpty {
            let (filterclause, filterValues) = filters(query.filters)
            statement += filterclause
            values += filterValues
        }

        return (
            concatenate(statement),
            values
        )
    }

    // MARK: Schema


    open func create(
        _ fields: [RawOr<Field>],
        _ fkeys: [RawOr<ForeignKey>]
    ) -> (String, [Node]) {
        var statement: [String] = []

        statement += "CREATE TABLE"
        statement += escape(E.entity)
        
        let items: [String] = columns(fields) + foreignKeys(fkeys)
        statement += "(" + items.joined(separator: ", ") + ")"

        return (
            concatenate(statement),
            []
        )
    }
    
    open func createIndex(_ idx: RawOr<Index>) -> (String, [Node]) {
        var statement: [String] = []
        
        statement += "CREATE"
        statement += index(idx)
        
        return (
            concatenate(statement),
            []
        )
    }
    
    open func deleteIndex(_ idx: RawOr<Index>) -> (String, [Node]) {
        var statement: [String] = []
        
        statement += "DROP INDEX"
        switch idx {
        case .raw(let string, _):
            statement += string
        case .some(let idx):
            statement += escape(idx.name)
        }
        
        return (
            concatenate(statement),
            []
        )
    }

    open func alter(
        add fs: [RawOr<Field>],
        _ fks: [RawOr<ForeignKey>],
        delete dfs: [RawOr<Field>],
        _ dfks: [RawOr<ForeignKey>]
    ) -> (String, [Node]) {
        var statement: [String] = []

        statement += "ALTER TABLE"
        statement += escape(E.entity)

        var subclause: [String] = []

        for field in fs {
            subclause += "ADD " + column(field)
        }
        
        for fk in fks {
            subclause += "ADD " + foreignKey(fk)
        }

        for field in dfs {
            let name: String
            switch field {
            case .raw(let raw, _):
                name = raw
            case .some(let some):
                name = some.name
            }
            subclause += "DROP " + escape(name)
        }
        
        for fk in dfks {
            switch fk {
            case .raw(let raw, _):
                subclause += "DROP " + raw
            case .some(let some):
                subclause += "DROP " + escape(some.name)
            }
        }

        statement += subclause.joined(separator: ", ")

        return (
            concatenate(statement),
            []
        )
    }

    open func drop() -> (String, [Node]) {
        var statement: [String] = []

        statement += "DROP TABLE IF EXISTS"
        statement += escape(E.entity)

        return (
            concatenate(statement),
            []
        )
    }
    
    open func index(_ idx: RawOr<Index>) -> String {
        switch idx {
        case .raw(let string, _):
            return string
        case .some(let idx):
            let list = idx.fields.map(escape).joined(separator: ", ")
            return "INDEX \(escape(idx.name)) ON \(escape(E.entity)) (\(list))"
        }
    }

    
    open func foreignKeys(_ foreignKeys: [RawOr<ForeignKey>]) -> [String] {
        return foreignKeys.map(foreignKey)
    }
    
    open func foreignKey(_ foreignKey: RawOr<ForeignKey>) -> String {
        switch foreignKey {
        case .raw(let string, _):
            return string
        case .some(let foreignKey):
            return "CONSTRAINT \(escape(foreignKey.name)) FOREIGN KEY (\(escape(foreignKey.field))) REFERENCES \(escape(foreignKey.foreignEntity.entity)) (\(escape(foreignKey.foreignField)))"
        }
    }

    open func columns(_ fields: [RawOr<Field>]) -> [String] {
        return fields.map(column)
    }

    open func column(_ field: RawOr<Field>) -> String {
        switch field {
        case .raw(let raw, _):
            return raw
        case .some(let some):
            return column(some)
        }
    }
    
    open func column(_ field: Field) -> String {
        var clause: [String] = []

        clause += escape(field.name)
        clause += type(field.type, primaryKey: field.primaryKey)

        if !field.optional {
            clause += "NOT NULL"
        }

        if field.unique {
            clause += "UNIQUE"
        }

        if let d = field.default {
            let dc: String

            switch d.wrapped {
            case .number(let n):
                dc = "'\(n.description)'"
            case .null:
                dc = "NULL"
            case .bool(let b):
                dc = b ? "TRUE" : "FALSE"
            default:
                dc = "'\((d.string ?? ""))'"
            }

            clause += "DEFAULT \(dc)"
        }

        return clause.joined(separator: " ")
    }


    open func type(_ type: Field.DataType, primaryKey: Bool) -> String {
        switch type {
        case .id(let type):
            let typeString: String
            switch type {
            case .int:
                typeString = "INTEGER"
            case .uuid:
                typeString = "STRING"
            case .custom(let dataType):
                typeString = dataType
            }
            if primaryKey {
                return typeString + " PRIMARY KEY"
            } else {
                return typeString
            }
        case .int:
            return "INTEGER"
        case .string(_):
            return "STRING"
        case .double:
            return "DOUBLE"
        case .bool:
            return "BOOL"
        case .bytes:
            return "BLOB"
        case .date:
            return "DATETIME"
        case .custom(let type):
            return type
        }
    }

    // MARK: Query Types

    open func limit(_ limit: RawOr<Limit>) -> String {
        var statement: [String] = []

        statement += "LIMIT"
        switch limit {
        case .raw(let raw, _):
            statement += raw
        case .some(let some):
            statement += "\(some.offset), \(some.count)"
        }

        return statement.joined(separator: " ")
    }


    open func filters(_ f: [RawOr<Filter>]) -> (String, [Node]) {
        var fragments: [String] = []

        fragments += "WHERE"

        let (clause, values) = filters(f, .and)

        fragments += clause

        return (
            concatenate(fragments),
            values
        )
    }

    open func filters(_ filters: [RawOr<Filter>], _ r: Filter.Relation) -> (String, [Node]) {
        var fragments: [String] = []
        var values: [Node] = []


        var subFragments: [String] = []

        for f in filters {
            let (clause, subValues) = filter(f)
            subFragments += clause
            values += subValues
        }

        fragments += subFragments.joined(separator: " \(relation(r)) ")

        return (
            concatenate(fragments),
            values
        )
    }

    open func relation(_ relation: Filter.Relation) -> String {
        let word: String
        switch relation {
        case .and:
            word = "AND"
        case .or:
            word = "OR"
        }
        return word
    }

    open func filter(_ f: RawOr<Filter>) -> (String, [Node]) {
        switch f {
        case .raw(let string, let values):
            return (string, values)
        case .some(let f):
            return filter(f)
        }
    }

    open func filter(_ filter: Filter) -> (String, [Node]) {
        var statement: [String] = []
        var values: [Node] = []

        switch filter.method {
        case .compare(let key, let c, let value):
            // `.null` needs special handling in the case of `.equals` or `.notEquals`.
            if c == .equals && value == .null {
                statement += escape(filter.entity.entity) + "." + escape(key) + " IS NULL"
            }
            else if c == .notEquals && value == .null {
                statement += escape(filter.entity.entity) + "." + escape(key) + " IS NOT NULL"
            }
            else {
                statement += escape(filter.entity.entity) + "." + escape(key)
                statement += comparison(c)
                statement += placeholder(value)

                /// `.like` comparison operator requires additional
                /// processing of `value`
                switch c {
                case .hasPrefix:
                    values += hasPrefix(value)
                case .hasSuffix:
                    values += hasSuffix(value)
                case .contains:
                    values += contains(value)
                default:
                    values += value
                }
            }
        case .subset(let key, let s, let subValues):
            if subValues.count == 0 {
                switch s {
                case .in:
                    // where in empty set should
                    // not match any rows
                    statement += "false"
                case .notIn:
                    // where not in empty set should
                    // match all rows
                    statement += "true"
                }
            } else {
                statement += escape(filter.entity.entity) + "." + escape(key)
                statement += scope(s)
                statement += placeholders(subValues)
                values += subValues
            }
        case .group(let relation, let f):
            if f.count == 0 {
                // empty subqueries should result
                // to false to protect unfiltered data
                // from being returned
                statement += "false"
            } else {
                let (clause, subvals) = filters(f, relation)
                statement += "(\(clause))"
                values += subvals
            }
        }

        return (
            concatenate(statement),
            values
        )
    }

    open func sorts(_ sorts: [RawOr<Sort>]) -> String {
        var clause: [String] = []

        clause += "ORDER BY"
        
        var fragments: [String] = []
        sorts.forEach { sort in
            switch sort {
            case .raw(let raw, _):
                fragments.append(raw)
            case .some(let some):
                fragments.append(self.sort(some))
            }
        }
        clause.append(fragments.joined(separator: ", "))

        return clause.joined(separator: " ")
    }

    open func sort(_ sort: Sort) -> String {
        var clause: [String] = []

        clause += escape(sort.entity.entity) + "." + escape(sort.field)

        switch sort.direction {
        case .ascending:
            clause += "ASC"
        case .descending:
            clause += "DESC"
        }

        return clause.joined(separator: " ")
    }

    open func comparison(_ comparison: Filter.Comparison) -> String {
        switch comparison {
        case .equals:
            return "="
        case .greaterThan:
            return ">"
        case .greaterThanOrEquals:
            return ">="
        case .lessThan:
            return "<"
        case .lessThanOrEquals:
            return "<="
        case .notEquals:
            return "!="
        case .hasSuffix:
            fallthrough
        case .hasPrefix:
            fallthrough
        case .contains:
            return "LIKE"
        case .custom(let string):
            return string
        }
    }

    open func hasPrefix(_ value: Node) -> Node {
        guard let string = value.string else {
            return value
        }

        return .string("\(string)%")
    }

    open func hasSuffix(_ value: Node) -> Node {
        guard let string = value.string else {
            return value
        }

        return .string("%\(string)")
    }

    open func contains(_ value: Node) -> Node {
        guard let string = value.string else {
            return value
        }

        return .string("%\(string)%")
    }

    open func scope(_ scope: Filter.Scope) -> String {
        switch scope {
        case .in:
            return "IN"
        case .notIn:
            return "NOT IN"
        }
    }

    open func joins(_ joins: [RawOr<Join>]) -> String {
        var fragments: [String] = []

        for j in joins {
            fragments += join(j)
        }

        return concatenate(fragments)
    }

    open func join(_ rawOrJoin: RawOr<Join>) -> String {
        switch rawOrJoin {
        case .raw(let string, _):
            return string
        case .some(let j):
            return join(j)
        }
    }

    open func join(_ join: Join) -> String {
        var fragments: [String] = []

        switch join.kind {
        case .inner:
            fragments += "INNER JOIN"
        case .outer:
            fragments += "LEFT OUTER JOIN"
        }
        fragments += escape(join.joined.entity)
        fragments += "ON"

        fragments += "\(escape(join.base.entity)).\(escape(join.baseKey))"
        fragments += "="
        fragments += "\(escape(join.joined.entity)).\(escape(join.joinedKey))"

        return concatenate(fragments)
    }
    
    open func computedField(_ computedField: RawOr<ComputedField>) -> String {
        switch computedField {
        case .raw(let raw, _):
            return raw
        case .some(let some):
            return self.computedField(some)
        }
    }

    open func computedField(_ computedField: ComputedField) -> String {
        var fragments: [String] = []
        
        fragments += computedField.function
        fragments += "("
        fragments += computedField.fields.map(escape).joined(separator: ", ")
        fragments += ") as "
        fragments += escape(computedField.key)
        
        return fragments.joined(separator: "")
    }
    
    // MARK: Convenience

    open func concatenate(_ fragments: [String]) -> String {
        return fragments.joined(separator: " ")
    }

    open func keys(_ keys: [RawOr<String>]) -> String {
        let parsed: [String] = keys.map { key in
            switch key {
            case .raw(let raw, _):
                return raw
            case .some(let some):
                return escape(some)
            }
        }
        return list(parsed)
    }

    open func list(_ list: [String]) -> String {
        let string = list.joined(separator: ", ")
        return "(\(string))"
    }

    open func values(_ values: [RawOr<Node>]) -> (String, [Node]) {
        var v: [Node] = []
        
        let parsed: [String] = values.map { value in
            switch value {
            case .raw(let string, _):
                return string
            case .some(let some):
                v.append(some)
                return placeholder(some)
            }
        }
        
        let string = parsed.joined(separator: ", ")
        return (
            "(" + string + ")",
            v
        )
    }
    
    open func placeholders(_ values: [Node]) -> String {
        let strings: [String] = values.map(placeholder)
        return "(" + strings.joined(separator: ", ") + ")"
    }

    open func placeholder(_ value: Node) -> String {
        return "?"
    }

    open func escape(_ string: String) -> String {
        return "`\(string)`"
    }
}

public func +=(lhs: inout [String], rhs: String) {
    lhs.append(rhs)
}

public func +=(lhs: inout [Encodable], rhs: Encodable) {
    lhs.append(rhs)
}
