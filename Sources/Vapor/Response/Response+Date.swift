import Foundation
import libc

extension Response {
    static let DAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    static let MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    
    public static var date: String {
        var now = Int(NSDate().timeIntervalSince1970)
        
        var days = now / 86400
        let weekday = (4 + days) & 7
        
        now %= 86400
        
        let hours = now / 3600
        
        now %= 3600
        
        let minutes = now / 60
        let seconds = now % 60
        
        days = days - (31 + 28) + 719527
        
        var year = (days + 2) * 400 / (365 * 400 + 100 - 4 + 1)
        
        var yearDay = days - (365 * year + year / 4 - year / 100 + year / 400)
        
        if yearDay < 0 {
            let fourthYear = (year % 4 == 0)
            let hundredthYear = (year % 100 > 0)
            let fourHundredthYear = (year % 400 == 0)
            
            let leap = fourthYear && (hundredthYear || fourHundredthYear)
            
            yearDay = 365 + yearDay
            
            if leap {
                yearDay += 1
            }
            
            year -= 1
        }
        
        var month = (yearDay + 31) * 10 / 306
        
        let monthDay = yearDay - (367 * month / 12 - 30) + 1
        
        if yearDay >= 306 {
            year += 1
            month -= 10
        } else {
            month += 2
        }
        
        let mdString: String
        
        if monthDay < 10 {
            mdString = "0\(monthDay)"
        } else {
            mdString = String(monthDay)
        }
        
        return "\(Response.DAY_NAMES[weekday - 1]), \(mdString) \(Response.MONTH_NAMES[month - 1]) \(year) \(hours):\(minutes):\(seconds) GMT"
//
    }
}
