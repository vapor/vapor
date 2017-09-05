import HTTP
import XCTest

class MultipartTests: XCTestCare {
    func testRequest() throws {
        let named = """
test123
aijdisadi>SDASD<a|

"""
        
let multinamed = """
test123
aijdisadi>dwekqie4u219034u129e0wque90qjsd90asffs


SDASD<a|

"""
        
        let data = """
------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
Content-Disposition: form-data; name="test"\r
\r
eqw-dd-sa----123;1[234\r
------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
Content-Disposition: form-data; name="named"; filename=""\r
\r
\(named)
\r
------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
Content-Disposition: form-data; name="multinamed[]"; filename=""\r
\r
\(multinamed)\r
------WebKitFormBoundaryPVOZifB9OqEwP2fn--\r
"""
        
        let multipart = try MultipartParser.parse(multipart: Data(data.utf8), boundary: Data("----WebKitFormBoundaryPVOZifB9OqEwP2fn".utf8))
        
        XCTAssertEqual(multipart.count, 3)
    }
}
