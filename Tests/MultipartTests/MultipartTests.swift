import Multipart
import HTTP
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
        let string = """
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
        
        let data = Data(string.utf8)
        let body = HTTPBody(data)
        
        XCTAssertEqual(Array("----WebKitFormBoundaryPVOZifB9OqEwP2fn".utf8), try MultipartParser.boundary(for: data))
        
        let form = try MultipartParser(body: body, boundary: Array("----WebKitFormBoundaryPVOZifB9OqEwP2fn".utf8)).parse()
        
        XCTAssertEqual(form.parts.count, 3)
        
        XCTAssertEqual(try form.getString(named: "test"), "eqw-dd-sa----123;1[234")
        XCTAssertEqual(try form.getFile(named: "named").data, Data(named.utf8))
        XCTAssertEqual(try form.getFile(named: "multinamed[]").data, Data(multinamed.utf8))
        
        XCTAssertEqual(MultipartSerializer(form: form).serialize(), data)
    }

    func testMultifile() throws {
        let string = """
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
        
        let data = Data(string.utf8)
        let body = HTTPBody(data)
        
        let multipart = try MultipartParser(body: body, boundary: Array("----WebKitFormBoundaryPVOZifB9OqEwP2fn".utf8)).parse()
        
        let files = try multipart.getFiles(named: "multinamed[]")
        
        XCTAssertEqual(files.count, 2)
        let file = try multipart.getFile(named: "multinamed[]")
        XCTAssertEqual(file.data, Data(named.utf8))
        
        XCTAssertEqual(files.first?.data, Data(named.utf8))
        XCTAssertEqual(files.last?.data, Data(multinamed.utf8))
        
        XCTAssertEqual(MultipartSerializer(form: multipart).serialize(), data)
    }
    
    static let allTests = [
        ("testBasics", testBasics),
        ("testMultifile", testMultifile)
    ]
}
