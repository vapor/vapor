/// Capable of serializing SQL queries into strings.
/// This protocol has free implementations for most of the requirements
/// and tries to conform to general (flavor-agnostic) SQL.
///
/// You are expected to implement only the methods that require
/// different serialization logic for your given SQL flavor.
public protocol SQLSerializer {
    // MARK: Data

    /// Serializes a SQL `DataQuery` to a string.
    ///
    ///     SELECT `users`.* FROM `users`
    ///
    /// Note: Avoid overriding this method if possible
    /// as it is the most complex. Much of what this method
    /// serializes can be modified by overriding other methods.
    func serialize(data query: DataQuery) -> String

    /// Serializes a SQL `DataColumn` to a string.
    ///
    ///     `foo`.`id`
    ///
    func serialize(column: DataColumn) -> String

    /// Serializes a SQL `DataComputed` to a string.
    ///
    ///     average(`users`.`age`) as `averageAge`
    ///
    func serialize(computed: DataComputed) -> String

    /// Serializes multiple SQL `DataJoin`s to a string.
    ///
    ///     JOIN `bar` ON `foo`.`bar_id` = `bar`.`id`
    ///
    func serialize(joins: [DataJoin]) -> String

    /// Serializes a single SQL `DataJoin` to a string.
    ///
    ///     JOIN `bar` ON `foo`.`bar_id` = `bar`.`id`
    ///
    func serialize(join: DataJoin) -> String

    /// Serializes multiple SQL `DataOrderBy`s to a string.
    ///
    ///     ORDER BY `users`.`age` DESC, `foo`.`bar` ASC
    ///
    func serialize(orderBys: [DataOrderBy]) -> String

    /// Serializes a single SQL `DataOrderBy` to a string.
    ///
    ///     `users`.`age` DESC
    ///
    func serialize(orderBy: DataOrderBy) -> String

    /// Serializes a SQL `OrderByDirection` to a string.
    ///
    ///     DESC
    ///
    func serialize(orderByDirection: OrderByDirection) -> String

    /// Serializes a SQL `DataPredicateGroup` to a string.
    ///
    ///     (`id` = ? AND `age` = ?)
    ///
    func serialize(predicateGroup: DataPredicateGroup) -> String

    /// Serializes a SQL `DataPredicateGroupRelation` to a string.
    ///
    ///     AND
    ///
    func serialize(predicateGroupRelation: DataPredicateGroupRelation) -> String

    /// Serializes a SQL `DataPredicate` to a string.
    ///
    ///     `user`.`id` = ?
    ///
    func serialize(predicate: DataPredicate) -> String

    /// Serializes a placeholder for the supplied predicate.
    ///
    ///     ?
    ///
    func makePlaceholder(predicate: DataPredicate) -> String

    /// Serializes a SQL `DataPredicateComparison` to a string.
    ///
    ///     =
    ///
    func serialize(comparison: DataPredicateComparison) -> String

    // MARK: Schema

    /// Serializes a SQL `SchemaQuery` to a string.
    ///
    ///     CREATE TABLE `foo` (`id` INT PRIMARY KEY)
    ///
    func serialize(schema query: SchemaQuery) -> String

    /// Serializes a SQL `SchemaColumn` to a string.
    ///
    ///     `id` INT PRIMARY KEY
    ///
    func serialize(column: SchemaColumn) -> String

    /// Serializes a SQL `SchemaColumn` to a string.
    ///
    ///     FOREIGN KEY (`trackartist`) REFERENCES `artist`(`artistid`)
    ///
    func serialize(foreignKey: SchemaForeignKey) -> String

    // MARK: Utility

    /// Creates a placeholder for the supplied column name.
    ///
    ///     ?
    ///
    func makePlaceholder(name: String) -> String

    /// Escapes the supplied string.
    ///
    /// Important: This is not guaranteed to be injection safe and
    /// should _not_ be relied upon to prevent injection.
    ///
    /// This method should be used for ensuring table, column,
    /// and key names are not mistaken for SQL syntax.
    ///
    ///     `foo`
    ///
    func makeEscapedString(from string: String) -> String
}












