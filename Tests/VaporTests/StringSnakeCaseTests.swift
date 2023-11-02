@testable import Vapor
import XCTest

final class StringSnakeCaseTests: XCTestCase {

    func testStringSnakeCase() {
        let toSnakeCaseTests = [
            ("simpleOneTwo", "simple_one_two"),
            ("myURL", "my_url"),
            ("singleCharacterAtEndX", "single_character_at_end_x"),
            ("thisIsAnXMLProperty", "this_is_an_xml_property"),
            ("single", "single"), // no underscore
            ("", ""), // don't die on empty string
            ("a", "a"), // single character
            ("aA", "a_a"), // two characters
            ("version4Thing", "version4_thing"), // numerics
            ("partCAPS", "part_caps"), // only insert underscore before first all caps
            ("partCAPSLowerAGAIN", "part_caps_lower_again"), // switch back and forth caps.
            ("manyWordsInThisThing", "many_words_in_this_thing"), // simple lowercase + underscore + more
            ("asdfĆqer", "asdf_ćqer"),
            ("already_snake_case", "already_snake_case"),
            ("dataPoint22", "data_point22"),
            ("dataPoint22Word", "data_point22_word"),
            ("_oneTwoThree", "_one_two_three"),
            ("oneTwoThree_", "one_two_three_"),
            ("__oneTwoThree", "__one_two_three"),
            ("oneTwoThree__", "one_two_three__"),
            ("_oneTwoThree_", "_one_two_three_"),
            ("__oneTwoThree", "__one_two_three"),
            ("__oneTwoThree__", "__one_two_three__"),
            ("_test", "_test"),
            ("_test_", "_test_"),
            ("__test", "__test"),
            ("test__", "test__"),
            ("m͉̟̹y̦̳G͍͚͎̳r̤͉̤͕ͅea̲͕t͇̥̼͖U͇̝̠R͙̻̥͓̣L̥̖͎͓̪̫ͅR̩͖̩eq͈͓u̞e̱s̙t̤̺ͅ", "m͉̟̹y̦̳_g͍͚͎̳r̤͉̤͕ͅea̲͕t͇̥̼͖_u͇̝̠r͙̻̥͓̣l̥̖͎͓̪̫ͅ_r̩͖̩eq͈͓u̞e̱s̙t̤̺ͅ"), // because Itai wanted to test this
            ("🐧🐟", "🐧🐟"), // fishy emoji example?
            ("URLSession", "url_session"),
            ("RADAR", "radar"),
            ("Sample", "sample"),
            ("_Sample", "_sample"),
            ("_IAmAnAPPDeveloper", "_i_am_an_app_developer")
        ]
        for test in toSnakeCaseTests {
            XCTAssertEqual(test.0.convertedToSnakeCase(), test.1)
        }
    }

    func testStringSnakeCaseWithSeparator() {
        let toSnakeCaseTests = [
            ("simpleOneTwo", "simple-one-two"),
            ("myURL", "my-url"),
            ("singleCharacterAtEndX", "single-character-at-end-x"),
            ("thisIsAnXMLProperty", "this-is-an-xml-property"),
            ("single", "single"), // no underscore
            ("", ""), // don't die on empty string
            ("a", "a"), // single character
            ("aA", "a-a"), // two characters
            ("version4Thing", "version4-thing"), // numerics
            ("partCAPS", "part-caps"), // only insert underscore before first all caps
            ("partCAPSLowerAGAIN", "part-caps-lower-again"), // switch back and forth caps.
            ("manyWordsInThisThing", "many-words-in-this-thing"), // simple lowercase + underscore + more
            ("asdfĆqer", "asdf-ćqer"),
            ("already_snake_case", "already_snake_case"),
            ("dataPoint22", "data-point22"),
            ("dataPoint22Word", "data-point22-word"),
            ("_oneTwoThree", "_one-two-three"),
            ("oneTwoThree_", "one-two-three_"),
            ("__oneTwoThree", "__one-two-three"),
            ("oneTwoThree__", "one-two-three__"),
            ("_oneTwoThree_", "_one-two-three_"),
            ("__oneTwoThree", "__one-two-three"),
            ("__oneTwoThree__", "__one-two-three__"),
            ("_test", "_test"),
            ("_test_", "_test_"),
            ("__test", "__test"),
            ("test__", "test__"),
            ("m͉̟̹y̦̳G͍͚͎̳r̤͉̤͕ͅea̲͕t͇̥̼͖U͇̝̠R͙̻̥͓̣L̥̖͎͓̪̫ͅR̩͖̩eq͈͓u̞e̱s̙t̤̺ͅ", "m͉̟̹y̦̳-g͍͚͎̳r̤͉̤͕ͅea̲͕t͇̥̼͖-u͇̝̠r͙̻̥͓̣l̥̖͎͓̪̫ͅ-r̩͖̩eq͈͓u̞e̱s̙t̤̺ͅ"), // because Itai wanted to test this
            ("🐧🐟", "🐧🐟"), // fishy emoji example?
            ("URLSession", "url-session"),
            ("RADAR", "radar"),
            ("Sample", "sample"),
            ("_Sample", "_-sample"),
            ("_IAmAnAPPDeveloper", "_-i-am-an-app-developer")
        ]
        for test in toSnakeCaseTests {
            XCTAssertEqual(test.0.convertedToSnakeCase(separator: "-"), test.1)
        }
    }
}
