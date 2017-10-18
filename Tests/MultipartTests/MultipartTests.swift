import Multipart
import Bits
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
        
        let body = Data(data.utf8)
            
        let form = try body.withUnsafeBytes { (pointer: BytesPointer) in
            return try MultipartParser.parse(multipart: ByteBuffer(start: pointer, count: body.count), boundary: Data("----WebKitFormBoundaryPVOZifB9OqEwP2fn".utf8))
        }
        
        XCTAssertEqual(form.parts.count, 3)
        
        XCTAssertEqual(try form.getString(forName: "test"), "eqw-dd-sa----123;1[234")
        XCTAssertEqual(try form.getFile(forName: "named"), Data(named.utf8))
        XCTAssertEqual(try form.getFile(forName: "multinamed[]"), Data(multinamed.utf8))
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
        
        let body = Data(data.utf8)
        
        let multipart = try body.withUnsafeBytes { (pointer: BytesPointer) in
            return try MultipartParser.parse(multipart: ByteBuffer(start: pointer, count: body.count), boundary: Data("----WebKitFormBoundaryPVOZifB9OqEwP2fn".utf8))
        }
        
        let files = multipart.getFiles(forName: "multinamed[]")
        
        XCTAssertEqual(files.count, 2)
        let file = try multipart.getFile(forName: "multinamed[]")
        XCTAssertEqual(file, Data(named.utf8))
        
        XCTAssertEqual(files.first, Data(named.utf8))
        XCTAssertEqual(files.last, Data(multinamed.utf8))
    }
    
    static let allTests = [
        ("testBasics", testBasics),
        ("testMultifile", testMultifile)
    ]
}
