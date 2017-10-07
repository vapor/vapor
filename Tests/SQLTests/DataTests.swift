import SQL
import XCTest

final class DataTests: XCTestCase {
    func testBasicSelectStar() {
        let select = DataQuery(statement: .select, table: "foo")
        XCTAssertEqual(
            GeneralSQLSerializer.shared.serialize(data: select),
            "SELECT `foo`.* FROM `foo`"
        )
    }

    func testSelectWithPredicates() {
        var select = DataQuery(statement: .select, table: "foo")

        let predicateA = Predicate(column: "id", comparison: .equal)
        select.predicates.append(predicateA)

        let predicateB = Predicate(table: "foo", column: "name", comparison: .equal)
        select.predicates.append(predicateB)

        XCTAssertEqual(
            GeneralSQLSerializer.shared.serialize(data: select),
            "SELECT `foo`.* FROM `foo` WHERE `id` = ? AND `foo`.`name` = ?"
        )
    }
}
