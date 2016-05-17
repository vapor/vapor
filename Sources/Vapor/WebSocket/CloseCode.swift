// CloseCode.swift
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Zewo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

public enum CloseCode {
    case Normal
    case GoingAway
    case ProtocolError
    case Unsupported
    case NoStatus
    case Abnormal
    case UnsupportedData
    case PolicyViolation
    case TooLarge
    case MissingExtension
    case InternalError
    case ServiceRestart
    case TryAgainLater
    case TLSHandshake
    case Raw(UInt16)
    
    init(code: Int) {
        switch code {
        case 1000: self = Normal
        case 1001: self = GoingAway
        case 1002: self = ProtocolError
        case 1003: self = Unsupported
        case 1005: self = NoStatus
        case 1006: self = Abnormal
        case 1007: self = UnsupportedData
        case 1008: self = PolicyViolation
        case 1009: self = TooLarge
        case 1010: self = MissingExtension
        case 1011: self = InternalError
        case 1012: self = ServiceRestart
        case 1013: self = TryAgainLater
        case 1015: self = TLSHandshake
        default:   self = .Raw(UInt16(code))
        }
    }
    
    var code: UInt16 {
        switch self {
        case .Normal:			return 1000
        case .GoingAway:		return 1001
        case .ProtocolError:	return 1002
        case .Unsupported:		return 1003
        case .NoStatus:			return 1005
        case .Abnormal:			return 1006
        case .UnsupportedData:	return 1007
        case .PolicyViolation:	return 1008
        case .TooLarge:			return 1009
        case .MissingExtension:	return 1010
        case .InternalError:	return 1011
        case .ServiceRestart:	return 1012
        case .TryAgainLater:	return 1013
        case .TLSHandshake:		return 1015
        case .Raw(let code):	return code
        }
    }
}
