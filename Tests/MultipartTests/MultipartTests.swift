import Multipart
import XCTest

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
        
        let form = try Multipart.Parser.parse(multipart: Data(data.utf8), boundary: Data("----WebKitFormBoundaryPVOZifB9OqEwP2fn".utf8))
        
        XCTAssertEqual(form.parts.count, 3)
        
        XCTAssertEqual(try form.getString(forName: "test"), "eqw-dd-sa----123;1[234")
        XCTAssertEqual(try form.getFile(forName: "named").data, Data(named.utf8))
        XCTAssertEqual(try form.getFile(forName: "multinamed[]").data, Data(multinamed.utf8))
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
        
        let multipart = try Multipart.Parser.parse(multipart: Data(data.utf8), boundary: Data("----WebKitFormBoundaryPVOZifB9OqEwP2fn".utf8))
        
        let files = multipart.getFiles(forName: "multinamed[]")
        
        XCTAssertEqual(files.count, 2)
        let file = try multipart.getFile(forName: "multinamed[]")
        XCTAssertEqual(file.data, Data(named.utf8))
        
        XCTAssertEqual(files.first?.data, Data(named.utf8))
        XCTAssertEqual(files.last?.data, Data(multinamed.utf8))
    }
}
