//
//  NSString.swift
//  NSLinux
//
//  Created by John Holdsworth on 11/06/2015.
//  Copyright (c) 2015 John Holdsworth. All rights reserved.
//
//  $Id: //depot/NSLinux/Sources/NSString.swift#11 $
//
//  Repo: https://github.com/johnno1962/NSLinux
//

// Hastily put together NSString substitutes

#if os(Linux)
import Foundation
import Glibc

private let O = "0".ord, A = "A".ord, percent = "%".ord

private func unhex( char: Int8 ) -> Int8 {
    return char < A ? char - O : char - A + 10
}

extension String {

    var ord: Int8 {
        return Int8(utf8.first!)
    }

    var stringByRemovingPercentEncoding: String? {
        var arr = [Int8]( count: 100000, repeatedValue: 0 )
        var out = UnsafeMutablePointer<Int8>( arr )

        withCString { (bytes) in
            var bytes = UnsafeMutablePointer<Int8>(bytes)

            while out < &arr + arr.count {
                let start = strchr( bytes, Int32(percent) ) - UnsafeMutablePointer<Int8>( bytes )

                let extralen = start < 0 ? Int(strlen( bytes )) : start + 1
                let required = out - UnsafeMutablePointer<Int8>(arr) + extralen
                if required > arr.count {
                    var newarr = [Int8]( count: Int(Double(required) * 1.5), repeatedValue: 0 )
                    strcpy( &newarr, arr )
                    arr = newarr
                    out = &arr + Int(strlen( arr ))
                }

                if start < 0 {
                    strcat( out, bytes )
                    break
                }

                bytes[start] = 0
                strcat( out, bytes )
                bytes += start + 3
                out += start + 1
                out[-1] = (unhex( bytes[-2] ) << 4) + unhex( bytes[-1] )
            }
        }
        
        return String.fromCString( arr )
    }

    func stringByAddingPercentEscapesUsingEncoding( encoding: UInt ) -> String? {
        return self
    }

    func stringByTrimmingCharactersInSet( cset: NSCharacterSet ) -> String {
        return self
    }
    
    func componentsSeparatedByString( sep: String ) -> [String] {
        var out = [String]()

        withCString { (bytes) in
            sep.withCString { (sbytes) in
                var bytes = UnsafeMutablePointer<Int8>( bytes )

                while true {
                    let start = strstr( bytes, sbytes ) - UnsafeMutablePointer<Int8>( bytes )
                    if start < 0 {
                        out.append( String.fromCString( bytes )! )
                        break
                    }
                    bytes[start] = 0
                    out.append( String.fromCString( bytes )! )
                    bytes += start + Int(strlen( sbytes ))
                }
            }
        }

        return out
    }

    func stringByReplacingOccurrencesOfString( str1: String, withString str2: String ) -> String {
        return componentsSeparatedByString( str1 ).joinWithSeparator( str2 )
    }

    func rangeOfString( str: String ) -> Range<Int>? {
        var start = -1
        withCString { (bytes) in
            str.withCString { (sbytes) in
                start = strstr( bytes, sbytes ) - UnsafeMutablePointer<Int8>( bytes )
            }
        }
        return start < 0 ? nil : start..<start+str.utf8.count
    }

    func substringToIndex( index: Int ) -> String {
        var out = self
        withCString { (bytes) in
            let bytes = UnsafeMutablePointer<Int8>(bytes)
            bytes[index] = 0
            out = String.fromCString( bytes )!
        }
        return out
    }
    
    func substringFromIndex( index: Int ) -> String {
        var out = self
        withCString { (bytes) in
            out = String.fromCString( bytes+index )!
        }
        return out
    }
    
}
#endif
