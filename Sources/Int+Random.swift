//
//  Int+Random.swift
//  Vapor
//
//  Created by Tanner Nelson on 2/7/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//


#if os(Linux)
    import Glibc
#else
    import Foundation
#endif

extension Int {
    public static func random(min min: Int, max: Int) -> Int {
        let top = max - min + 1
        #if os(Linux)
            let j = Int(Glibc.random() % (top)) + min
        #else
            return Int(arc4random_uniform(UInt32(top))) + min
        #endif
    }
}