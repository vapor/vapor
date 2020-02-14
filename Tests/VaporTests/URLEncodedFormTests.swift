@testable import Vapor
import XCTest

final class URLEncodedFormTests: XCTestCase {
    // MARK: Codable
    
    func testDecode() throws {
        let data = """
        name=Tanner&age=23&pets[]=Zizek&pets[]=Foo&dict[a]=1&dict[b]=2&foos[]=baz&nums[]=3.14
        """
        
        let user = try URLEncodedFormDecoder().decode(User.self, from: data)
        XCTAssertEqual(user.name, "Tanner")
        XCTAssertEqual(user.age, 23)
        XCTAssertEqual(user.pets.count, 2)
        XCTAssertEqual(user.pets.first, "Zizek")
        XCTAssertEqual(user.pets.last, "Foo")
        XCTAssertEqual(user.dict["a"], 1)
        XCTAssertEqual(user.dict["b"], 2)
        XCTAssertEqual(user.foos[0], .baz)
        XCTAssertEqual(user.nums[0], 3.14)
    }

    func testDecodeWithoutArrayBrackets() throws {
        let data = """
        name=Tanner&age=23&pets=Zizek&pets=Foo&dict[a]=1&dict[b]=2&foos=baz&nums=3.14
        """
        
        let user = try URLEncodedFormDecoder().decode(User.self, from: data)
        XCTAssertEqual(user.name, "Tanner")
        XCTAssertEqual(user.age, 23)
        XCTAssertEqual(user.pets.count, 2)
        XCTAssertEqual(user.pets.first, "Zizek")
        XCTAssertEqual(user.pets.last, "Foo")
        XCTAssertEqual(user.dict["a"], 1)
        XCTAssertEqual(user.dict["b"], 2)
        XCTAssertEqual(user.foos[0], .baz)
        XCTAssertEqual(user.nums[0], 3.14)
    }

    func testDecodeArraysToSingleValue() throws {
        let data = """
        name[]=Tanner&age[]=23&pets[]=Zizek&pets[]=Foo&dict[a][]=1&dict[b][]=2&foos[]=baz&nums[]=3.14
        """
        
        let user = try URLEncodedFormDecoder().decode(User.self, from: data)
        XCTAssertEqual(user.name, "Tanner")
        XCTAssertEqual(user.age, 23)
        XCTAssertEqual(user.pets.count, 2)
        XCTAssertEqual(user.pets.first, "Zizek")
        XCTAssertEqual(user.pets.last, "Foo")
        XCTAssertEqual(user.dict["a"], 1)
        XCTAssertEqual(user.dict["b"], 2)
        XCTAssertEqual(user.foos[0], .baz)
        XCTAssertEqual(user.nums[0], 3.14)
    }

    func testEncode() throws {
        let user = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2], foos: [.baz], nums: [3.14])
        let result = try URLEncodedFormEncoder().encode(user)
        XCTAssert(result.contains("pets[]=Zizek"))
        XCTAssert(result.contains("pets[]=Foo"))
        XCTAssert(result.contains("age=23"))
        XCTAssert(result.contains("name=Tanner"))
        XCTAssert(result.contains("dict[a]=1"))
        XCTAssert(result.contains("dict[b]=2"))
        XCTAssert(result.contains("foos[]=baz"))
        XCTAssert(result.contains("nums[]=3.14"))
    }
    
    func testCodable() throws {
        let a = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2], foos: [], nums: [])
        let body = try URLEncodedFormEncoder().encode(a)
        print(body)
        let b = try! URLEncodedFormDecoder().decode(User.self, from: body)
        XCTAssertEqual(a, b)
    }
    
    func testDecodeIntArray() throws {
        let data = """
        array[]=1&array[]=2&array[]=3
        """
        
        let content = try URLEncodedFormDecoder().decode([String: [Int]].self, from: data)
        XCTAssertEqual(content["array"], [1, 2, 3])
    }
    
    func testRawEnum() throws {
        enum PetType: String, Codable {
            case cat, dog
        }
        struct Pet: Codable {
            var name: String
            var type: PetType
        }
        let ziz = try URLEncodedFormDecoder().decode(Pet.self, from: "name=Ziz&type=cat")
        XCTAssertEqual(ziz.name, "Ziz")
        XCTAssertEqual(ziz.type, .cat)
        let string = try URLEncodedFormEncoder().encode(ziz)
        XCTAssertEqual(string.contains("name=Ziz"), true)
        XCTAssertEqual(string.contains("type=cat"), true)
    }
    
    /// https://github.com/vapor/url-encoded-form/issues/3
    func testGH3() throws {
        struct Foo: Codable {
            var flag: Bool
        }
        let foo = try URLEncodedFormDecoder().decode(Foo.self, from: "flag=1")
        XCTAssertEqual(foo.flag, true)
    }
    
    // MARK: Parser
    
    func testBasic() throws {
        let data = "hello=world&foo=bar"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["hello": "world", "foo": "bar"])
    }
    
    func testBasicWithAmpersand() throws {
        let data = "hello=world&foo=bar%26bar"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["hello": "world", "foo": "bar&bar"])
    }
    
    func testDictionary() throws {
        let data = "greeting[en]=hello&greeting[es]=hola"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["greeting": ["es": "hola", "en": "hello"]])
    }
    
    func testArray() throws {
        let data = "greetings[]=hello&greetings[]=hola"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["greetings": ["hello", "hola"]])
    }
  
    func testArrayWithoutBrackets() throws {
      let data = "greetings=hello&greetings=hola"
      let form = try URLEncodedFormParser().parse(data)
      XCTAssertEqual(form, ["greetings": ["hello", "hola"]])
    }
  
    func testSubArray() throws {
        let data = "greetings[sub][]=hello&greetings[sub][]=hola"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["greetings": ["sub":["hello", "hola"]]])
    }

    func testSubArray2() throws {
        let data = "greetings[sub]=hello&greetings[sub][]=hola"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["greetings": ["sub":["hello", "hola"]]])
    }
    
    func testSubArray3() throws {
        let data = "greetings[sub][]=hello&greetings[sub]=hola"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["greetings": ["sub":["hello", "hola"]]])
    }

    func testSubArray4() throws {
        let data = "greetings[sub][]=hello&greetings[sub]=hola&greetings[sub]=bonjour"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["greetings": ["sub":["hello", "hola", "bonjour"]]])
    }

    //If we do want to be able to address arrays that are in the "middle" we need to support indexing like greetings[sub][0][a]=hello
    func testInvalidDict() throws {
        let data = "greetings[sub][][a]=hello&greetings[sub][][a]=hola"
        XCTAssertThrowsError(try URLEncodedFormParser().parse(data))
    }

    func testSubArrayWithoutBrackets() throws {
        let data = "greetings[sub]=hello&greetings[sub]=hola"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["greetings": ["sub":["hello", "hola"]]])
    }

    func testOptions() throws {
        let data = "hello=&foo"
        let normal = try URLEncodedFormParser().parse(data)
        let noEmpty = try URLEncodedFormParser(omitEmptyValues: true).parse(data)
        let noFlags = try URLEncodedFormParser(omitFlags: true).parse(data)
        
        XCTAssertEqual(normal, ["hello": "", "foo": "true"])
        XCTAssertEqual(noEmpty, ["foo": "true"])
        XCTAssertEqual(noFlags, ["hello": ""])
    }
    
    func testPercentDecoding() throws {
        let data = "aaa%5B%5D=%2Bbbb%20+ccc&d[]=1&d[]=2"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["aaa[]": "+bbb  ccc", "d": ["1","2"]])
    }
    
    func testNestedParsing() throws {
        // a[][b]=c&a[][b]=c
        // [a:[[b:c],[b:c]]
        let data = "a[b][c][d][hello]=world"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["a": ["b": ["c": ["d": ["hello": "world"]]]]])
    }
    
    // MARK: Serializer
    
    func testPercentEncoding() throws {
        let form: [String: URLEncodedFormData] = ["aaa]": "+bbb  ccc"]
        let data = try URLEncodedFormSerializer().serialize(form)
        XCTAssertEqual(data, "aaa%5D=%2Bbbb%20%20ccc")
    }

    func testPercentEncodingWithAmpersand() throws {
        let form: [String: URLEncodedFormData] = ["aaa": "b%26&b"]
        let data = try URLEncodedFormSerializer().serialize(form)
        XCTAssertEqual(data, "aaa=b%2526%26b")
    }

    func testNested() throws {
        let form: [String: URLEncodedFormData] = ["a": ["b": ["c": ["d": ["hello": "world"]]]]]
        let data = try URLEncodedFormSerializer().serialize(form)
        XCTAssertEqual(data, "a[b][c][d][hello]=world")
    }
    
    func testPercentEncodingSpecial() throws {
        let data = try URLEncodedFormSerializer().serialize([
            "test": "&;!$'(),/:=?@~"
        ])
        XCTAssertEqual(data, "test=%26%3B!$'(),/:%3D%3F@~")
    }
}

private struct User: Codable, Equatable {
    var name: String
    var age: Int
    var pets: [String]
    var dict: [String: Int]
    var foos: [Foo]
    var nums: [Decimal]
}

private enum Foo: String, Codable {
    case foo, bar, baz
}
