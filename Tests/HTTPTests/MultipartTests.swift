import HTTP
import XCTest
import Files

class MultipartTests: XCTestCase {
    let named = """
test123
aijdisadi>SDASD<a|

"""
    
    let multinamed = """
test123
aijdisadi>dwekqie4u219034u129e0wque90qjsd90asffs


SDASD<a|

"""
    
    func testBasics() throws {
        let data = """
------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
Content-Disposition: form-data; name="test"\r
\r
eqw-dd-sa----123;1[234\r
------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
Content-Disposition: form-data; name="named"; filename=""\r
\r
\(named)\r
------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
Content-Disposition: form-data; name="multinamed[]"; filename=""\r
\r
\(multinamed)\r
------WebKitFormBoundaryPVOZifB9OqEwP2fn--\r
"""
        
        let multipart = try MultipartParser.parse(multipart: Data(data.utf8), boundary: Data("----WebKitFormBoundaryPVOZifB9OqEwP2fn".utf8))
        
        XCTAssertEqual(multipart.parts.count, 3)
        
        XCTAssertEqual(try multipart.getString(forName: "test"), "eqw-dd-sa----123;1[234")
        XCTAssertEqual(try multipart.getFile(forName: "named").data, Data(named.utf8))
        XCTAssertEqual(try multipart.getFile(forName: "multinamed[]").data, Data(multinamed.utf8))
        
        XCTAssertEqual(multipart["test"], try multipart.getString(forName: "test"))
        XCTAssertEqual(multipart[fileFor: "test"]?.data, try multipart.getFile(forName: "test").data)
        XCTAssertEqual(multipart[fileFor: "test"]?.data, try multipart.getFile(forName: "test").data)
    }

    func testMultifile() throws {
        let data = """
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
        Content-Disposition: form-data; name="test"\r
        \r
        eqw-dd-sa----123;1[234\r
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
        Content-Disposition: form-data; name="multinamed[]"; filename=""\r
        \r
        \(named)\r
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
        Content-Disposition: form-data; name="multinamed[]"; filename=""\r
        \r
        \(multinamed)\r
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn--\r
        """
        
        let multipart = try MultipartParser.parse(multipart: Data(data.utf8), boundary: Data("----WebKitFormBoundaryPVOZifB9OqEwP2fn".utf8))
        
        let files = multipart[filesFor: "multinamed[]"]
        
        XCTAssertEqual(files.count, 2)
        XCTAssertEqual(multipart[fileFor: "multinamed[]"]?.data, Data(named.utf8))
        
        XCTAssertEqual(files.first?.data, Data(named.utf8))
        XCTAssertEqual(files.last?.data, Data(multinamed.utf8))
    }
}
