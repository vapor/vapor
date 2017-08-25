//import XCTest
//import MySQL
//
//extension MySQL.Database {
//    static func makeTest() -> MySQL.Database {
//        do {
//            let mysql = try MySQL.Database(
//                hostname: "127.0.0.1",
//                user: "ubuntu",
//                password: "",
//                database: "circle_test"
//            )
//            let connection = try mysql.makeConnection()
//            try connection.execute("SELECT @@version")
//
//            return mysql
//        } catch {
//            print()
//            print()
//            print("⚠️  MySQL Not Configured ⚠️")
//            print()
//            print("Error: \(error)")
//            print()
//            print("You must configure MySQL to run with the following configuration: ")
//            print("    user: 'ubuntu'")
//            print("    password: '' // (empty)")
//            print("    host: '127.0.0.1'")
//            print("    database: 'circle_test'")
//            print()
//
//            print()
//
//            XCTFail("Configure MySQL")
//            fatalError("Configure MySQL")
//        }
//    }
//}

