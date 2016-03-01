var _module_nsstring = true

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


var _module_dispatch = true

#if os(Linux)
import Glibc

let DISPATCH_QUEUE_CONCURRENT = 0, DISPATCH_QUEUE_PRIORITY_HIGH = 0, DISPATCH_QUEUE_PRIORITY_LOW = 0, DISPATCH_QUEUE_PRIORITY_BACKGROUND = 0

func dispatch_get_global_queue( type: Int, _ flags: Int ) -> Int {
    return 0
}

func dispatch_queue_create( name: String, _ type: Int ) -> Int {
    return 0
}

func dispatch_sync( queue: Int, _ block: () -> () ) {
    block()
}

private class pthreadBlock {

    let block: () -> ()

    init( block: () -> () ) {
        self.block = block
    }
}

private func pthreadRunner( arg: UnsafeMutablePointer<Void> ) -> UnsafeMutablePointer<Void> {
    let unmanaged = Unmanaged<pthreadBlock>.fromOpaque( COpaquePointer( arg ) )
    unmanaged.takeUnretainedValue().block()
    unmanaged.release()
    return arg
}

func dispatch_async( queue: Int, _ block: () -> () ) {
    let holder = Unmanaged.passRetained( pthreadBlock( block: block ) )
    let pointer = UnsafeMutablePointer<Void>( holder.toOpaque() )
    #if os(Linux)
    var pthread: pthread_t = 0
    #else
    var pthread: pthread_t = nil
    #endif
    if pthread_create( &pthread, nil, pthreadRunner, pointer ) == 0 {
        pthread_detach( pthread )
    }
    else {
        Log.error( "pthread_create() error" )
    }
}

let DISPATCH_TIME_NOW = 0, NSEC_PER_SEC = 1_000_000_000

func dispatch_time( now: Int, _ nsec: Int64 ) -> Int64 {
    return nsec
}

func dispatch_after( delay: Int64, _ queue: Int, _ block: () -> () ) {
    dispatch_async( queue, {
        sleep( UInt32(Int(delay)/NSEC_PER_SEC) )
        block()
    } )
}

#endif
