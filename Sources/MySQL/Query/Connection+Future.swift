import Async
import JunkDrawer

extension MySQLConnection {
    /// Collects all resulting rows and returs them in the future
    ///
    /// - parameter query: The query to be executed to receive results from
    /// - returns: A future containing all results
    internal func allRows(in query: MySQLQuery) -> Future<[Row]> {
        var rows = [Row]()
        
        return forEachRow(in: query) { rows.append($0) }.transform(to: rows)
    }
    
    /// Collects all decoded results and returs them in the future
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/mysql/basics/#futures)
    ///
    /// - parameter query: The query to be executed to receive results from
    /// - returns: A future containing all results
    public func all<D: Decodable>(_ type: D.Type, in query: MySQLQuery) -> Future<[D]> {
        var results = [D]()
        
        return forEach(D.self, in: query) { results.append($0) }.transform(to: results)
    }
}
