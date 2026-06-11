import NIOPosix
@testable import Vapor
import Testing
import Foundation

@Suite("URL Encoded Form Tests")
struct URLEncodedFormTests {
    // MARK: Codable

    @Test("Test Decode")
    func testDecode() throws {
        let data = """
        name=Tanner&age=23&pets[]=Zizek&pets[]=Foo&dict[a]=1&dict[b]=2&foos[]=baz&nums[]=3.14
        """

        let user = try URLEncodedFormDecoder().decode(User.self, from: data)
        #expect(user.name == "Tanner")
        #expect(user.age == 23)
        #expect(user.pets.count == 2)
        #expect(user.pets.first == "Zizek")
        #expect(user.pets.last == "Foo")
        #expect(user.dict["a"] == 1)
        #expect(user.dict["b"] == 2)
        #expect(user.foos[0] == .baz)
        #expect(user.nums[0] == 3.14)
    }

    @Test("Test Decode Comma Separated Array")
    func testDecodeCommaSeparatedArray() throws {
        let data = """
        name=Tanner&age=23&pets=Zizek,Foo%2C&dict[a]=1&dict[b]=2&foos=baz&nums=3.14
        """
        let user = try URLEncodedFormDecoder().decode(User.self, from: data)
        #expect(user.name == "Tanner")
        #expect(user.age == 23)
        #expect(user.pets.count == 2)
        #expect(user.pets.first == "Zizek")
        #expect(user.pets.last == "Foo,")
        #expect(user.dict["a"] == 1)
        #expect(user.dict["b"] == 2)
        #expect(user.foos[0] == .baz)
        #expect(user.nums[0] == 3.14)
    }

    @Test("Test Decode Without Array Brackets")
    func testDecodeWithoutArrayBrackets() throws {
        let data = """
        name=Tanner&age=23&pets=Zizek&pets=Foo&dict[a]=1&dict[b]=2&foos=baz&nums=3.14
        """

        let user = try URLEncodedFormDecoder().decode(User.self, from: data)
        #expect(user.name == "Tanner")
        #expect(user.age == 23)
        #expect(user.pets.count == 2)
        #expect(user.pets.first == "Zizek")
        #expect(user.pets.last == "Foo")
        #expect(user.dict["a"] == 1)
        #expect(user.dict["b"] == 2)
        #expect(user.foos[0] == .baz)
        #expect(user.nums[0] == 3.14)
    }

    @Test("Test Decode Arrays To Single Value Fails")
    func testDecodeArraysToSingleValueFails() throws {
        let data = """
        name[]=Tanner&age[]=23&pets[]=Zizek&pets[]=Foo&dict[a][]=1&dict[b][]=2&foos[]=baz&nums[]=3.14
        """
        #expect(throws: DecodingError.self) {
            try URLEncodedFormDecoder().decode(User.self, from: data)
        }
    }

    @Test("Test Decode String With Commas")
    func testDecodeStringWithCommas() throws {
        let data = """
        name=Vapor, Tanner&age=23&pets[]=Zizek&pets[]=Foo&dict[a]=1&dict[b]=2&foos[]=baz&nums[]=3.14
        """
        let user = try URLEncodedFormDecoder().decode(User.self, from: data)
        #expect(user.name == "Vapor, Tanner")
        #expect(user.age == 23)
        #expect(user.pets.count == 2)
        #expect(user.pets.first == "Zizek")
        #expect(user.pets.last == "Foo")
        #expect(user.dict["a"] == 1)
        #expect(user.dict["b"] == 2)
        #expect(user.foos[0] == .baz)
        #expect(user.nums[0] == 3.14)
    }

    @Test("Test Decode Without Flags As Bool Fails When Bool Is Required")
    func testDecodeWithoutFlagsAsBoolFailsWhenBoolIsRequired() throws {
        let decoder = URLEncodedFormDecoder(configuration: .init(boolFlags: false))
        let dataWithoutBool = """
        name=Tanner&age=23&pets[]=Zizek&pets[]=Foo&dict[a]=1&dict[b]=2&foos[]=baz&nums[]=3.14
        """
        #expect(throws: DecodingError.self) {
            try decoder.decode(User.self, from: dataWithoutBool)
        }

        let dataWithBool = """
        name=Tanner&age=23&pets[]=Zizek&pets[]=Foo&dict[a]=1&dict[b]=2&foos[]=baz&nums[]=3.14&isCool=false
        """
        let user = try decoder.decode(User.self, from: dataWithBool)
        #expect(user.name == "Tanner")
        #expect(user.age == 23)
        #expect(user.pets.count == 2)
        #expect(user.pets.first == "Zizek")
        #expect(user.pets.last == "Foo")
        #expect(user.dict["a"] == 1)
        #expect(user.dict["b"] == 2)
        #expect(user.foos[0] == .baz)
        #expect(user.nums[0] == 3.14)
        #expect(user.isCool == false)
    }

    @Test("Test Decode Indexed Array")
    func testDecodeIndexedArray() throws {
        struct Test: Decodable {
            let array: [String]
        }

        let data = """
        array[0]=a&array[1]=&array[2]=b&array[3]=
        """
        let test = try URLEncodedFormDecoder().decode(Test.self, from: data)
        #expect(test.array[0] == "a")
        #expect(test.array[1] == "")
        #expect(test.array[2] == "b")
        #expect(test.array[3] == "")
    }

    @Test("Test Decode Unindexed Array")
    func testDecodeUnindexedArray() throws {
        struct Test: Decodable {
            let array: [String]
        }

        let data = """
        array[]=a&array[]=&array[]=b&array[]=
        """
        let test = try URLEncodedFormDecoder().decode(Test.self, from: data)
        #expect(test.array[0] == "a")
        #expect(test.array[1] == "")
        #expect(test.array[2] == "b")
        #expect(test.array[3] == "")
    }

    @Test("Test Decode Indexed Array (dictionary)")
    func testDecodeIndexedArray_dictionary() throws {
        struct Test: Decodable {
            let array: [Int: String]
        }

        let data = """
        array[0]=a&array[1]=b
        """
        let test = try URLEncodedFormDecoder().decode(Test.self, from: data)
        #expect(test.array[0] == "a")
        #expect(test.array[1] == "b")
    }

    @Test("Test Encode")
    func testEncode() throws {
        let user = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2], foos: [.baz], nums: [3.14], isCool: true)
        let result = try URLEncodedFormEncoder().encode(user)
        #expect(result.contains("pets[]=Zizek"))
        #expect(result.contains("pets[]=Foo"))
        #expect(result.contains("age=23"))
        #expect(result.contains("name=Tanner"))
        #expect(result.contains("dict[a]=1"))
        #expect(result.contains("dict[b]=2"))
        #expect(result.contains("foos[]=baz"))
        #expect(result.contains("nums[]=3.14"))
        #expect(result.contains("isCool=true"))
    }

    @Test("Test Date Array Coding")
    func testDateArrayCoding() throws {
        let toEncode = DateArrayCoding(
            dates: [
                Date(timeIntervalSince1970: 0),
                Date(timeIntervalSince1970: 10000),
                Date(timeIntervalSince1970: 20000),
                Date(timeIntervalSince1970: 30000),
                Date(timeIntervalSince1970: 40000),
                Date(timeIntervalSince1970: 50000),
            ]
        )

        let decodedDefaultFromUnixTimestamp = try URLEncodedFormDecoder().decode(DateArrayCoding.self, from: "dates[]=0.0&dates[]=10000.0&dates[]=20000.0&dates[]=30000.0&dates[]=40000.0&dates[]=50000.0")
        #expect(decodedDefaultFromUnixTimestamp == toEncode)

        let resultForDefault = try URLEncodedFormEncoder().encode(toEncode)
        #expect(resultForDefault == "dates[]=0.0&dates[]=10000.0&dates[]=20000.0&dates[]=30000.0&dates[]=40000.0&dates[]=50000.0")

        let decodedDefault = try URLEncodedFormDecoder().decode(DateArrayCoding.self, from: resultForDefault)
        #expect(decodedDefault == toEncode)

        let resultForTimeIntervalSince1970 = try URLEncodedFormEncoder(
            configuration: .init(dateEncodingStrategy: .secondsSince1970)
        ).encode(toEncode)
        #expect(resultForDefault == "dates[]=0.0&dates[]=10000.0&dates[]=20000.0&dates[]=30000.0&dates[]=40000.0&dates[]=50000.0")

        let decodedTimeIntervalSince1970 = try URLEncodedFormDecoder(
            configuration: .init(dateDecodingStrategy: .secondsSince1970)
        ).decode(DateArrayCoding.self, from: resultForTimeIntervalSince1970)
        #expect(decodedTimeIntervalSince1970 == toEncode)

        let resultForInternetDateTime = try URLEncodedFormEncoder(
            configuration: .init(dateEncodingStrategy: .iso8601)
        ).encode(toEncode)
        #expect(resultForInternetDateTime == "dates[]=1970-01-01T00%3A00%3A00Z&dates[]=1970-01-01T02%3A46%3A40Z&dates[]=1970-01-01T05%3A33%3A20Z&dates[]=1970-01-01T08%3A20%3A00Z&dates[]=1970-01-01T11%3A06%3A40Z&dates[]=1970-01-01T13%3A53%3A20Z")

        let decodedInternetDateTime = try URLEncodedFormDecoder(
            configuration: .init(dateDecodingStrategy: .iso8601)
        ).decode(DateArrayCoding.self, from: resultForInternetDateTime)
        #expect(decodedInternetDateTime == toEncode)

        #expect(throws: DecodingError.self) {
            try URLEncodedFormDecoder(
                configuration: .init(dateDecodingStrategy: .iso8601)
            ).decode(DateArrayCoding.self, from: "dates=bad-date")
        }

        final class DateFormatterFactory: Sendable {
            var currentValue: DateFormatter {
                self.newDateFormatter
            }

            private var newDateFormatter: DateFormatter {
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.dateFormat = "'Date:' yyyy-MM-dd 'Time:' HH:mm:ss 'Timezone:' ZZZZZ"
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                return dateFormatter
            }
        }
        let factory = DateFormatterFactory()
        let resultCustom = try URLEncodedFormEncoder(
            configuration: .init(dateEncodingStrategy: .custom { date, encoder in
                var container = encoder.singleValueContainer()
                try container.encode(factory.currentValue.string(from: date))
            })
        ).encode(toEncode)
        #expect("dates[]=Date%3A%201970-01-01%20Time%3A%2000%3A00%3A00%20Timezone%3A%20Z&dates[]=Date%3A%201970-01-01%20Time%3A%2002%3A46%3A40%20Timezone%3A%20Z&dates[]=Date%3A%201970-01-01%20Time%3A%2005%3A33%3A20%20Timezone%3A%20Z&dates[]=Date%3A%201970-01-01%20Time%3A%2008%3A20%3A00%20Timezone%3A%20Z&dates[]=Date%3A%201970-01-01%20Time%3A%2011%3A06%3A40%20Timezone%3A%20Z&dates[]=Date%3A%201970-01-01%20Time%3A%2013%3A53%3A20%20Timezone%3A%20Z" == resultCustom)

        let decodedCustom = try URLEncodedFormDecoder(
            configuration: .init(dateDecodingStrategy: .custom { decoder -> Date in
                let container = try decoder.singleValueContainer()
                let string = try container.decode(String.self)
                guard let date = factory.currentValue.date(from: string) else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode date from string '\(string)'")
                }
                return date
            })
        ).decode(DateArrayCoding.self, from: resultCustom)
        #expect(decodedCustom == toEncode)
    }

    @Test("Test Date Coding")
    func testDateCoding() throws {
        let toEncode = DateCoding(date: Date(timeIntervalSince1970: 0))

        let decodedDefaultFromUnixTimestamp = try URLEncodedFormDecoder().decode(DateCoding.self, from: "date=0")
        #expect(decodedDefaultFromUnixTimestamp == toEncode)

        let resultForDefault = try URLEncodedFormEncoder().encode(toEncode)
        #expect(resultForDefault == "date=0.0")

        let decodedDefault = try URLEncodedFormDecoder().decode(DateCoding.self, from: resultForDefault)
        #expect(decodedDefault == toEncode)

        let resultForTimeIntervalSince1970 = try URLEncodedFormEncoder(
            configuration: .init(dateEncodingStrategy: .secondsSince1970)
        ).encode(toEncode)
        #expect(resultForTimeIntervalSince1970 == "date=0.0")

        let decodedTimeIntervalSince1970 = try URLEncodedFormDecoder(
            configuration: .init(dateDecodingStrategy: .secondsSince1970)
        ).decode(DateCoding.self, from: resultForTimeIntervalSince1970)
        #expect(decodedTimeIntervalSince1970 == toEncode)

        let resultForInternetDateTime = try URLEncodedFormEncoder(
            configuration: .init(dateEncodingStrategy: .iso8601)
        ).encode(toEncode)
        #expect(resultForInternetDateTime == "date=1970-01-01T00%3A00%3A00Z")

        let decodedInternetDateTime = try URLEncodedFormDecoder(
            configuration: .init(dateDecodingStrategy: .iso8601)
        ).decode(DateCoding.self, from: resultForInternetDateTime)
        #expect(decodedInternetDateTime == toEncode)

        #expect(throws: DecodingError.self) {
            try URLEncodedFormDecoder(
                configuration: .init(dateDecodingStrategy: .iso8601)
            ).decode(DateCoding.self, from: "date=bad-date")
        }

        final class DateFormatterFactory: Sendable {
            var currentValue: DateFormatter {
                self.newDateFormatter
            }

            private var newDateFormatter: DateFormatter {
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.dateFormat = "'Date:' yyyy-MM-dd 'Time:' HH:mm:ss 'Timezone:' ZZZZZ"
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                return dateFormatter
            }
        }
        let factory = DateFormatterFactory()
        let resultCustom = try URLEncodedFormEncoder(
            configuration: .init(dateEncodingStrategy: .custom { date, encoder in
                var container = encoder.singleValueContainer()
                try container.encode(factory.currentValue.string(from: date))
            })
        ).encode(toEncode)
        #expect("date=Date%3A%201970-01-01%20Time%3A%2000%3A00%3A00%20Timezone%3A%20Z" == resultCustom)

        let decodedCustom = try URLEncodedFormDecoder(
            configuration: .init(dateDecodingStrategy: .custom { decoder -> Date in
                let container = try decoder.singleValueContainer()
                let string = try container.decode(String.self)
                guard let date = factory.currentValue.date(from: string) else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode date from string '\(string)'")
                }
                return date
            })
        ).decode(DateCoding.self, from: resultCustom)
        #expect(decodedCustom == toEncode)
    }

    @Test("Test Optional Date Encoding and Decoding", .bug("https://github.com/vapor/vapor/issues/2518"))
    func testOptionalDateEncodingAndDecoding_GH2518() throws {
        let optionalDate: Date? = Date(timeIntervalSince1970: 0)
        let dateString = "1970-01-01T00%3A00%3A00Z"

        let resultForDecodedOptionalDate = try URLEncodedFormDecoder(
            configuration: .init(dateDecodingStrategy: .iso8601)
        ).decode(Date?.self, from: dateString)
        #expect(optionalDate == resultForDecodedOptionalDate)

        let resultForEncodedOptionalDate = try URLEncodedFormEncoder(
            configuration: .init(dateEncodingStrategy: .iso8601)
        ).encode(optionalDate)
        #expect(dateString == resultForEncodedOptionalDate)
    }

    @Test("Test Encoded Array Values")
    func testEncodedArrayValues() throws {
        let user = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2], foos: [.baz], nums: [3.14], isCool: true)
        let result = try URLEncodedFormEncoder(
            configuration: .init(arrayEncoding: .values)
        ).encode(user)
        #expect(result.contains("pets=Zizek"))
        #expect(result.contains("pets=Foo"))
        #expect(result.contains("age=23"))
        #expect(result.contains("name=Tanner"))
        #expect(result.contains("dict[a]=1"))
        #expect(result.contains("dict[b]=2"))
        #expect(result.contains("foos=baz"))
        #expect(result.contains("nums=3.14"))
        #expect(result.contains("isCool=true"))
    }

    @Test("Test Encoded Array Separator")
    func testEncodeArraySeparator() throws {
        let user = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2], foos: [.baz], nums: [3.14], isCool: true)
        let result = try URLEncodedFormEncoder(
            configuration: .init(arrayEncoding: .separator(","))
        ).encode(user)
        #expect(result.contains("pets=Zizek,Foo"))
        #expect(result.contains("age=23"))
        #expect(result.contains("name=Tanner"))
        #expect(result.contains("dict[a]=1"))
        #expect(result.contains("dict[b]=2"))
        #expect(result.contains("foos=baz"))
        #expect(result.contains("nums=3.14"))
        #expect(result.contains("isCool=true"))
    }

    @Test("Test Multi Object Array Encode")
    func testMultiObjectArrayEncode() throws {
        let tanner = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2], foos: [.baz], nums: [3.14], isCool: true)
        let ravneet = User(name: "Ravneet", age: 33, pets: ["Piku"], dict: ["a": -3, "b": 99], foos: [.baz, .bar], nums: [3.14, 144], isCool: true)
        let usersToEncode = Users(users: [tanner, ravneet])
        let result = try URLEncodedFormEncoder().encode(usersToEncode)
        #expect(result.contains("users[0][pets][]=Zizek"))
        #expect(result.contains("users[0][pets][]=Foo"))
        #expect(result.contains("users[0][age]=23"))
        #expect(result.contains("users[0][name]=Tanner"))
        #expect(result.contains("users[0][dict][a]=1"))
        #expect(result.contains("users[0][dict][b]=2"))
        #expect(result.contains("users[0][foos][]=baz"))
        #expect(result.contains("users[0][nums][]=3.14"))
        #expect(result.contains("users[0][isCool]=true"))

        #expect(result.contains("users[1][pets][]=Piku"))
        #expect(result.contains("users[1][age]=33"))
        #expect(result.contains("users[1][name]=Ravneet"))
        #expect(result.contains("users[1][dict][a]=-3"))
        #expect(result.contains("users[1][dict][b]=99"))
        #expect(result.contains("users[1][foos][]=baz"))
        #expect(result.contains("users[1][foos][]=bar"))
        #expect(result.contains("users[1][nums][]=3.14"))
        #expect(result.contains("users[1][nums][]=144"))
        #expect(result.contains("users[1][isCool]=true"))

        let decodedUsers = try URLEncodedFormDecoder().decode(Users.self, from: result)
        #expect(decodedUsers == usersToEncode)
    }

    @Test("Test Multi Object Values Array Encoding")
    func testMultiObjectValuesArrayEncoding() throws {
        let tanner = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2], foos: [.baz], nums: [3.14], isCool: true)
        let ravneet = User(name: "Ravneet", age: 33, pets: ["Piku"], dict: ["a": -3, "b": 99], foos: [.baz, .bar], nums: [3.14, 144], isCool: true)
        let usersToEncode = Users(users: [tanner, ravneet])
        let result = try URLEncodedFormEncoder(
            configuration: .init(arrayEncoding: .values)
        ).encode(usersToEncode)

        #expect(result.contains("users[0][pets]=Zizek"))
        #expect(result.contains("users[0][pets]=Foo"))
        #expect(result.contains("users[0][age]=23"))
        #expect(result.contains("users[0][name]=Tanner"))
        #expect(result.contains("users[0][dict][a]=1"))
        #expect(result.contains("users[0][dict][b]=2"))
        #expect(result.contains("users[0][foos]=baz"))
        #expect(result.contains("users[0][nums]=3.14"))
        #expect(result.contains("users[0][isCool]=true"))

        #expect(result.contains("users[1][pets]=Piku"))
        #expect(result.contains("users[1][age]=33"))
        #expect(result.contains("users[1][name]=Ravneet"))
        #expect(result.contains("users[1][dict][a]=-3"))
        #expect(result.contains("users[1][dict][b]=99"))
        #expect(result.contains("users[1][foos]=baz"))
        #expect(result.contains("users[1][foos]=bar"))
        #expect(result.contains("users[1][nums]=3.14"))
        #expect(result.contains("users[1][nums]=144"))
        #expect(result.contains("users[1][isCool]=true"))

        let decodedUsers = try URLEncodedFormDecoder().decode(Users.self, from: result)
        #expect(decodedUsers == usersToEncode)
    }

    @Test("Test Arrays of Arrays of Objects")
    func testArraysOfArraysOfObjects() throws {
        let toEncode = [[User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2], foos: [.baz], nums: [3.14], isCool: true)]]
        let result = try URLEncodedFormEncoder().encode(toEncode)
        let kvs = result.split(separator: "&")
        #expect(kvs.contains("0[0][name]=Tanner"))

        let decoded = try URLEncodedFormDecoder().decode([[User]].self, from: result)
        #expect(decoded == toEncode)
    }

    @Test("Test Multi Object Array Encode With Array Separator")
    func testMultiObjectArrayEncodeWithArraySeparator() throws {
        let tanner = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2], foos: [.baz], nums: [3.14], isCool: true)
        let ravneet = User(name: "Ravneet", age: 33, pets: ["Piku"], dict: ["a": -3, "b": 99], foos: [.baz, .bar], nums: [3.14, 144], isCool: true)
        let usersToEncode = Users(users: [tanner, ravneet])
        let result = try URLEncodedFormEncoder(
            configuration: .init(arrayEncoding: .separator(","))
        ).encode(usersToEncode)

        #expect(result.contains("users[0][pets]=Zizek,Foo"))
        #expect(result.contains("users[0][age]=23"))
        #expect(result.contains("users[0][name]=Tanner"))
        #expect(result.contains("users[0][dict][a]=1"))
        #expect(result.contains("users[0][dict][b]=2"))
        #expect(result.contains("users[0][foos]=baz"))
        #expect(result.contains("users[0][nums]=3.14"))
        #expect(result.contains("users[0][isCool]=true"))

        #expect(result.contains("users[1][pets]=Piku"))
        #expect(result.contains("users[1][age]=33"))
        #expect(result.contains("users[1][name]=Ravneet"))
        #expect(result.contains("users[1][dict][a]=-3"))
        #expect(result.contains("users[1][dict][b]=99"))
        #expect(result.contains("users[1][foos]=baz,bar"))
        #expect(result.contains("users[1][nums]=3.14,144"))
        #expect(result.contains("users[1][isCool]=true"))

        let decodedUsers = try URLEncodedFormDecoder().decode(Users.self, from: result)
        #expect(decodedUsers == usersToEncode)
    }

    @Test("Test Codable")
    func testCodable() throws {
        let a = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2], foos: [], nums: [], isCool: true)
        let body = try URLEncodedFormEncoder().encode(a)
        let b = try URLEncodedFormDecoder().decode(User.self, from: body)
        #expect(a == b)
    }

    @Test("Test Decode Int Array")
    func testDecodeIntArray() throws {
        let data = "array[]=1&array[]=2&array[]=3"
        let content = try URLEncodedFormDecoder().decode([String: [Int]].self, from: data)
        #expect(content["array"] == [1, 2, 3])
    }

    @Test("Test Sparse Array")
    func testSparseArray() throws {
        let data = "array[0]=0&array[1]=1&array[3]=3"
        #expect(throws: DecodingError.self) {
            try URLEncodedFormDecoder().decode([String: [Int]].self, from: data)
        }
    }

    @Test("Test Raw Enum")
    func testRawEnum() throws {
        enum PetType: String, Codable {
            case cat, dog
        }
        struct Pet: Codable {
            var name: String
            var type: PetType
        }
        let ziz = try URLEncodedFormDecoder().decode(Pet.self, from: "name=Ziz&type=cat")
        #expect(ziz.name == "Ziz")
        #expect(ziz.type == .cat)

        let string = try URLEncodedFormEncoder().encode(ziz)
        #expect(string.contains("name=Ziz"))
        #expect(string.contains("type=cat"))
    }

    @Test("Test Flag Decoding As Bool")
    func testFlagDecodingAsBool() throws {
        struct Foo: Codable {
            var flag: Bool
        }
        let foo = try URLEncodedFormDecoder().decode(Foo.self, from: "flag")
        #expect(foo.flag == true)
    }
    
    @Test("Test Flag Decoding As Optional Bool")
    func testFlagDecodingAsOptionalBool() throws {
        struct Foo: Codable {
            var flag: Bool?
        }

        let foo1 = try URLEncodedFormDecoder().decode(Foo.self, from: "flag")
        #expect(foo1.flag == true)
        let foo2 = try URLEncodedFormDecoder().decode(Foo.self, from: "somethingelse")
        #expect(foo2.flag == nil)
        let foo3 = try URLEncodedFormDecoder().decode(Foo.self, from: "")
        #expect(foo3.flag == nil)
        let foo4 = try URLEncodedFormDecoder().decode(Foo.self, from: "flag=true")
        #expect(foo4.flag == true)
        let foo5 = try URLEncodedFormDecoder().decode(Foo.self, from: "flag=false")
        #expect(foo5.flag == false)
    }

    @Test("Test Flag 'on' Decoding As Bool")
    func testFlagIsOnDecodingAsBool() throws {
        struct Foo: Codable {
            var flag: Bool
        }
        let foo = try URLEncodedFormDecoder().decode(Foo.self, from: "flag=on")
        #expect(foo.flag == true)
    }

    @Test("Test Converting '1' to true", .bug("https://github.com/vapor/url-encoded-form/issues/3"))
    func testGH3() throws {
        struct Foo: Codable {
            var flag: Bool
        }
        let foo = try URLEncodedFormDecoder().decode(Foo.self, from: "flag=1")
        #expect(foo.flag == true)
    }

    // MARK: Parser

    @Test("Test Basic Parsing")
    func testBasic() throws {
        let data = "hello=world&foo=bar"
        let form = try URLEncodedFormParser().parse(data)
        #expect(form == ["hello": "world", "foo": "bar"])
    }

    @Test("Test Basic Parsing With Ampersand")
    func testBasicWithAmpersand() throws {
        let data = "hello=world&foo=bar%26bar"
        let form = try URLEncodedFormParser().parse(data)
        #expect(form == ["hello": "world", "foo": "bar&bar"])
    }

    @Test("Test Dictionary Parsing")
    func testDictionary() throws {
        let data = "greeting[en]=hello&greeting[es]=hola"
        let form = try URLEncodedFormParser().parse(data)
        #expect(form == ["greeting": ["es": "hola", "en": "hello"]])
    }

    @Test("Test Array Parsing")
    func testArray() throws {
        let data = "greetings[]=hello&greetings[]=hola"
        let form = try URLEncodedFormParser().parse(data)
        #expect(form == ["greetings": ["": ["hello", "hola"]]])
    }

    @Test("Test Array Parsing Without Brackets")
    func testArrayWithoutBrackets() throws {
        let data = "greetings=hello&greetings=hola"
        let form = try URLEncodedFormParser().parse(data)
        #expect(form == ["greetings": ["hello", "hola"]])
    }

    @Test("Test Sub Array Parsing")
    func testSubArray() throws {
        let data = "greetings[sub][]=hello&greetings[sub][]=hola"
        let form = try URLEncodedFormParser().parse(data)
        #expect(form == ["greetings": ["sub": ["": ["hello", "hola"]]]])
    }

    @Test("Test Sub Array Parsing Case 2")
    func testSubArray2() throws {
        let data = "greetings[sub]=hello&greetings[sub][]=hola"
        let form = try URLEncodedFormParser().parse(data)
        let expected: URLEncodedFormData = ["greetings": ["sub":
                URLEncodedFormData(values: ["hello"], children: [
                    "": "hola",
                ]),
        ]]
        #expect(form == expected)
    }

    @Test("Test Sub Array Parsing Case 3")
    func testSubArray3() throws {
        let data = "greetings[sub][]=hello&greetings[sub]=hola"
        let form = try URLEncodedFormParser().parse(data)
        let expected: URLEncodedFormData = ["greetings": ["sub":
                URLEncodedFormData(values: ["hola"], children: [
                    "": "hello",
                ]),
        ]]
        #expect(form == expected)
    }

    @Test("Test Sub Array Parsing Case 4")
    func testSubArray4() throws {
        let data = "greetings[sub][]=hello&greetings[sub]=hola&greetings[sub]=bonjour"
        let form = try URLEncodedFormParser().parse(data)
        let expected: URLEncodedFormData = ["greetings": ["sub":
                URLEncodedFormData(values: ["hola", "bonjour"], children: [
                    "": "hello",
                ]),
        ]]
        #expect(form == expected)
    }

    @Test("Test Brackets in the Middle")
    func testBracketsInTheMiddle() throws {
        let data = "greetings[sub][][a]=hello&greetings[sub][][a]=hola"
        let form = try URLEncodedFormParser().parse(data)
        #expect(form == ["greetings": ["sub": ["": ["a": ["hello", "hola"]]]]])
    }

    @Test("Test Sub Array Without Brackets")
    func testSubArrayWithoutBrackets() throws {
        let data = "greetings[sub]=hello&greetings[sub]=hola"
        let form = try URLEncodedFormParser().parse(data)
        #expect(form == ["greetings": ["sub": ["hello", "hola"]]])
    }

    @Test("Test Flags in URL Encoding")
    func testFlags() throws {
        let data = "hello=&foo"
        let form = try URLEncodedFormParser().parse(data)
        let expected = URLEncodedFormData(values: ["foo"], children: [
            "hello": URLEncodedFormData(""),
        ])
        #expect(form == expected)
    }

    @Test("Test Percent Decoding")
    func testPercentDecoding() throws {
        let data = "aaa%5B%5D=%2Bbbb%20+ccc&d[]=1&d[]=2"
        let form = try URLEncodedFormParser().parse(data)
        #expect(form == ["aaa": ["": "+bbb  ccc"], "d": ["": ["1", "2"]]])
    }

    @Test("Test Nested Parsing")
    func testNestedParsing() throws {
        // a[][b]=c&a[][b]=c
        // [a:[[b:c],[b:c]]
        let data = "a[b][c][d][hello]=world"
        let form = try URLEncodedFormParser().parse(data)
        #expect(form == ["a": ["b": ["c": ["d": ["hello": "world"]]]]])
    }

    // MARK: Serializer

    @Test("Test Percent Encoding")
    func testPercentEncoding() throws {
        let form: URLEncodedFormData = ["aaa]": "+bbb  ccc"]
        let data = try URLEncodedFormSerializer().serialize(form)
        #expect(data == "aaa%5D=%2Bbbb%20%20ccc")
    }

    @Test("Test Percent Encoding With Ampersand")
    func testPercentEncodingWithAmpersand() throws {
        let form: URLEncodedFormData = ["aaa": "b%26&b"]
        let data = try URLEncodedFormSerializer().serialize(form)
        #expect(data == "aaa=b%2526%26b")
    }

    @Test("Test Nested Encoding")
    func testNested() throws {
        let form: URLEncodedFormData = ["a": ["b": ["c": ["d": ["hello": "world"]]]]]
        let data = try URLEncodedFormSerializer().serialize(form)
        #expect(data == "a[b][c][d][hello]=world")
    }

    @Test("Test Percent Encoding Special Characters")
    func testPercentEncodingSpecial() throws {
        let data = try URLEncodedFormSerializer().serialize([
            "test": "&;!$'(),/:=?@~",
        ])
        #expect(data == "test=%26%3B%21%24%27%28%29%2C%2F%3A%3D%3F%40%7E")
    }

    @Test("Test Heavily Nested Array Parsing")
    func testHeavilyNestedArray() throws {
        var body = "x"
        body += String(repeating: "[]", count: 80000)
        body += "=y"

        struct Foo: Content {}

        #expect(throws: URLEncodedFormError.reachedNestingLimit) {
            try URLEncodedFormDecoder().decode(Foo.self, from: body)
        }

        #expect(true, "We should not have crashed")
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

struct DateCoding: Codable, Equatable {
    let date: Date
}

struct DateArrayCoding: Codable, Equatable {
    let dates: [Date]
}
