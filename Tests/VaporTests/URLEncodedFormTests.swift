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
    
    func testDecodeCommaSeparatedArray() throws {
        let data = """
        name=Tanner&age=23&pets=Zizek,Foo&dict[a]=1&dict[b]=2&foos=baz&nums=3.14
        """
        
        let user = try URLEncodedFormDecoder(with: URLEncodedFormCodingConfig(bracketsAsArray: true, flagsAsBool: true, arraySeparator: ",")).decode(User.self, from: data)
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
        let user = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2], foos: [.baz], nums: [3.14], isCool: true)
        let result = try URLEncodedFormEncoder().encode(user)
        XCTAssert(result.contains("pets[]=Zizek"))
        XCTAssert(result.contains("pets[]=Foo"))
        XCTAssert(result.contains("age=23"))
        XCTAssert(result.contains("name=Tanner"))
        XCTAssert(result.contains("dict[a]=1"))
        XCTAssert(result.contains("dict[b]=2"))
        XCTAssert(result.contains("foos[]=baz"))
        XCTAssert(result.contains("nums[]=3.14"))
        XCTAssert(result.contains("isCool=true"))
    }

    func testEncodeWithoutBrackets() throws {
        let user = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2], foos: [.baz], nums: [3.14], isCool: true)
        let result = try URLEncodedFormEncoder(with: URLEncodedFormCodingConfig(bracketsAsArray: false, flagsAsBool: false, arraySeparator: nil)).encode(user)
        XCTAssert(result.contains("pets=Zizek"))
        XCTAssert(result.contains("pets=Foo"))
        XCTAssert(result.contains("age=23"))
        XCTAssert(result.contains("name=Tanner"))
        XCTAssert(result.contains("dict[a]=1"))
        XCTAssert(result.contains("dict[b]=2"))
        XCTAssert(result.contains("foos=baz"))
        XCTAssert(result.contains("nums=3.14"))
        XCTAssert(result.contains("isCool=true"))
    }

    func testEncodeFlagsAsBoolIsNotSupported() throws {
        let user = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2], foos: [.baz], nums: [3.14], isCool: true)
        XCTAssertThrowsError(try URLEncodedFormEncoder(with: URLEncodedFormCodingConfig(bracketsAsArray: false, flagsAsBool: true, arraySeparator: nil)).encode(user))
    }

    func testEncodeWithArraySeparator() throws {
        let user = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2], foos: [.baz], nums: [3.14], isCool: true)
        let result = try URLEncodedFormEncoder(with: URLEncodedFormCodingConfig(bracketsAsArray: false, flagsAsBool: false, arraySeparator: ",")).encode(user)
        XCTAssert(result.contains("pets=Zizek,Foo"))
        XCTAssert(result.contains("age=23"))
        XCTAssert(result.contains("name=Tanner"))
        XCTAssert(result.contains("dict[a]=1"))
        XCTAssert(result.contains("dict[b]=2"))
        XCTAssert(result.contains("foos=baz"))
        XCTAssert(result.contains("nums=3.14"))
        XCTAssert(result.contains("isCool=true"))
    }
    
    func testMultiObjectArrayEncode() throws {
        let tanner = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2], foos: [.baz], nums: [3.14], isCool: true)
        let ravneet = User(name: "Ravneet", age: 33, pets: ["Piku"], dict: ["a": -3, "b": 99], foos: [.baz, .bar], nums: [3.14, 144], isCool: true)
        let usersToEncode = Users(users: [tanner, ravneet])
        let result = try URLEncodedFormEncoder().encode(usersToEncode)
        XCTAssert(result.contains("users[0][pets][]=Zizek"))
        XCTAssert(result.contains("users[0][pets][]=Foo"))
        XCTAssert(result.contains("users[0][age]=23"))
        XCTAssert(result.contains("users[0][name]=Tanner"))
        XCTAssert(result.contains("users[0][dict][a]=1"))
        XCTAssert(result.contains("users[0][dict][b]=2"))
        XCTAssert(result.contains("users[0][foos][]=baz"))
        XCTAssert(result.contains("users[0][nums][]=3.14"))
        XCTAssert(result.contains("users[0][isCool]=true"))
        
        XCTAssert(result.contains("users[1][pets][]=Piku"))
        XCTAssert(result.contains("users[1][age]=33"))
        XCTAssert(result.contains("users[1][name]=Ravneet"))
        XCTAssert(result.contains("users[1][dict][a]=-3"))
        XCTAssert(result.contains("users[1][dict][b]=99"))
        XCTAssert(result.contains("users[1][foos][]=baz"))
        XCTAssert(result.contains("users[1][foos][]=bar"))
        XCTAssert(result.contains("users[1][nums][]=3.14"))
        XCTAssert(result.contains("users[1][nums][]=144"))
        XCTAssert(result.contains("users[1][isCool]=true"))
        
        let decodedUsers = try URLEncodedFormDecoder().decode(Users.self, from: result)
        XCTAssertEqual(decodedUsers, usersToEncode)
    }

    func testMultiObjectWithoutBrackets() throws {
        let codingConfig = URLEncodedFormCodingConfig(bracketsAsArray: false, flagsAsBool: false, arraySeparator: nil)
        let tanner = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2], foos: [.baz], nums: [3.14], isCool: true)
        let ravneet = User(name: "Ravneet", age: 33, pets: ["Piku"], dict: ["a": -3, "b": 99], foos: [.baz, .bar], nums: [3.14, 144], isCool: true)
        let usersToEncode = Users(users: [tanner, ravneet])
        let result = try URLEncodedFormEncoder(with: codingConfig).encode(usersToEncode)
        XCTAssert(result.contains("users[0][pets]=Zizek"))
        XCTAssert(result.contains("users[0][pets]=Foo"))
        XCTAssert(result.contains("users[0][age]=23"))
        XCTAssert(result.contains("users[0][name]=Tanner"))
        XCTAssert(result.contains("users[0][dict][a]=1"))
        XCTAssert(result.contains("users[0][dict][b]=2"))
        XCTAssert(result.contains("users[0][foos]=baz"))
        XCTAssert(result.contains("users[0][nums]=3.14"))
        XCTAssert(result.contains("users[0][isCool]=true"))
        
        XCTAssert(result.contains("users[1][pets]=Piku"))
        XCTAssert(result.contains("users[1][age]=33"))
        XCTAssert(result.contains("users[1][name]=Ravneet"))
        XCTAssert(result.contains("users[1][dict][a]=-3"))
        XCTAssert(result.contains("users[1][dict][b]=99"))
        XCTAssert(result.contains("users[1][foos]=baz"))
        XCTAssert(result.contains("users[1][foos]=bar"))
        XCTAssert(result.contains("users[1][nums]=3.14"))
        XCTAssert(result.contains("users[1][nums]=144"))
        XCTAssert(result.contains("users[1][isCool]=true"))
        
        let decodedUsers = try URLEncodedFormDecoder(with: codingConfig).decode(Users.self, from: result)
        XCTAssertEqual(decodedUsers, usersToEncode)
    }

    func testMultiObjectArrayEncodeWithArraySeparator() throws {
        let codingConfig = URLEncodedFormCodingConfig(bracketsAsArray: true, flagsAsBool: false, arraySeparator: ",")

        let tanner = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2], foos: [.baz], nums: [3.14], isCool: true)
        let ravneet = User(name: "Ravneet", age: 33, pets: ["Piku"], dict: ["a": -3, "b": 99], foos: [.baz, .bar], nums: [3.14, 144], isCool: true)
        let usersToEncode = Users(users: [tanner, ravneet])
        let result = try URLEncodedFormEncoder(with: codingConfig).encode(usersToEncode)
        XCTAssert(result.contains("users[0][pets]=Zizek,Foo"))
        XCTAssert(result.contains("users[0][age]=23"))
        XCTAssert(result.contains("users[0][name]=Tanner"))
        XCTAssert(result.contains("users[0][dict][a]=1"))
        XCTAssert(result.contains("users[0][dict][b]=2"))
        XCTAssert(result.contains("users[0][foos]=baz"))
        XCTAssert(result.contains("users[0][nums]=3.14"))
        XCTAssert(result.contains("users[0][isCool]=true"))
        
        XCTAssert(result.contains("users[1][pets]=Piku"))
        XCTAssert(result.contains("users[1][age]=33"))
        XCTAssert(result.contains("users[1][name]=Ravneet"))
        XCTAssert(result.contains("users[1][dict][a]=-3"))
        XCTAssert(result.contains("users[1][dict][b]=99"))
        XCTAssert(result.contains("users[1][foos]=baz,bar"))
        XCTAssert(result.contains("users[1][nums]=3.14,144"))
        XCTAssert(result.contains("users[1][isCool]=true"))
        
        let decodedUsers = try URLEncodedFormDecoder(with: codingConfig).decode(Users.self, from: result)
        XCTAssertEqual(decodedUsers, usersToEncode)
    }

    func testCodable() throws {
        let a = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2], foos: [], nums: [], isCool: true)
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

    func testFlagDecodingAsBool() throws {
        struct Foo: Codable {
            var flag: Bool
        }
        let foo = try URLEncodedFormDecoder().decode(Foo.self, from: "flag")
        XCTAssertEqual(foo.flag, true)
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
        XCTAssertEqual(form, ["greetings": ["": ["hello", "hola"]]])
    }
  
    func testArrayWithoutBrackets() throws {
        let data = "greetings=hello&greetings=hola"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["greetings": ["hello", "hola"]])
    }
  
    func testSubArray() throws {
        let data = "greetings[sub][]=hello&greetings[sub][]=hola"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["greetings":["sub":["":["hello", "hola"]]]])
    }

    func testSubArray2() throws {
        let data = "greetings[sub]=hello&greetings[sub][]=hola"
        let form = try URLEncodedFormParser().parse(data)
        let expected: URLEncodedFormData = ["greetings": ["sub":
            URLEncodedFormData(values: ["hello"], children: [
                "": "hola"
            ])
        ]]
        XCTAssertEqual(form, expected)
    }
    
    func testSubArray3() throws {
        let data = "greetings[sub][]=hello&greetings[sub]=hola"
        let form = try URLEncodedFormParser().parse(data)
        let expected: URLEncodedFormData = ["greetings": ["sub":
            URLEncodedFormData(values: ["hola"], children: [
                "": "hello"
            ])
        ]]
        XCTAssertEqual(form, expected)
    }

    func testSubArray4() throws {
        let data = "greetings[sub][]=hello&greetings[sub]=hola&greetings[sub]=bonjour"
        let form = try URLEncodedFormParser().parse(data)
        let expected: URLEncodedFormData = ["greetings": ["sub":
            URLEncodedFormData(values: ["hola", "bonjour"], children: [
            "": "hello"
            ])
        ]]
        XCTAssertEqual(form, expected)
    }

    func testBracketsInTheMiddle() throws {
        let data = "greetings[sub][][a]=hello&greetings[sub][][a]=hola"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["greetings": ["sub": ["": ["a": ["hello", "hola"]]]]])
    }

    func testSubArrayWithoutBrackets() throws {
        let data = "greetings[sub]=hello&greetings[sub]=hola"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["greetings":["sub":["hello", "hola"]]])
    }

    func testFlags() throws {
        let data = "hello=&foo"
        let form = try URLEncodedFormParser().parse(data)
        let expected = URLEncodedFormData(values: ["foo"], children:[
            "hello": URLEncodedFormData("")
        ])
        XCTAssertEqual(form, expected)
    }
    
    func testPercentDecoding() throws {
        let data = "aaa%5B%5D=%2Bbbb%20+ccc&d[]=1&d[]=2"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["aaa[]": "+bbb  ccc", "d": ["": ["1","2"]]])
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
        let form: URLEncodedFormData = ["aaa]": "+bbb  ccc"]
        let data = try URLEncodedFormSerializer().serialize(form)
        XCTAssertEqual(data, "aaa%5D=%2Bbbb%20%20ccc")
    }

    func testPercentEncodingWithAmpersand() throws {
        let form: URLEncodedFormData = ["aaa": "b%26&b"]
        let data = try URLEncodedFormSerializer().serialize(form)
        XCTAssertEqual(data, "aaa=b%2526%26b")
    }

    func testNested() throws {
        let form: URLEncodedFormData = ["a": ["b": ["c": ["d": ["hello": "world"]]]]]
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
    var isCool: Bool
}

private struct Users: Codable, Equatable {
    var users: [User]
}

private enum Foo: String, Codable {
    case foo, bar, baz
}
