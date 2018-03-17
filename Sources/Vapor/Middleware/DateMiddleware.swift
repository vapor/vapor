import Async
//import HTTP
import COperatingSystem

fileprivate let DAY_NAMES = [
    "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
]

fileprivate let MONTH_NAMES = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
]

fileprivate let NUMBERS = [
    "00", "01", "02", "03", "04", "05", "06", "07", "08", "09",
    "10", "11", "12", "13", "14", "15", "16", "17", "18", "19",
    "20", "21", "22", "23", "24", "25", "26", "27", "28", "29",
    "30", "31", "32", "33", "34", "35", "36", "37", "38", "39",
    "40", "41", "42", "43", "44", "45", "46", "47", "48", "49",
    "50", "51", "52", "53", "54", "55", "56", "57", "58", "59",
    "60", "61", "62", "63", "64", "65", "66", "67", "68", "69",
    "70", "71", "72", "73", "74", "75", "76", "77", "78", "79",
    "80", "81", "82", "83", "84", "85", "86", "87", "88", "89",
    "90", "91", "92", "93", "94", "95", "96", "97", "98", "99"
]

fileprivate var cachedTimeComponents: (key: time_t, components: COperatingSystem.tm)?

let secondsInDay = 60 * 60 * 24
let accuracy: Int = 1 // seconds

/// Adds the RFC 1123 date to the response.
public final class DateMiddleware: Middleware, Service {
    var cachedTimestamp: (timestamp: String, createdAt: time_t)?

    /// Creates a new `DateMiddleware`
    public init() { }

    /// See `Middleware.respond(to:)`
    public func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        let promise = request.eventLoop.newPromise(Response.self)
        
        try next.respond(to: request).do { res in
            res.http.headers.replaceOrAdd(name: "Date", value: self.getDate())
            promise.succeed(result: res)
        }.catch { error in
            promise.fail(error: error)
        }
        
        return promise.futureResult
    }

    /// Gets the current RFC 1123 date string.
    fileprivate func getDate() -> String {
        var date = COperatingSystem.time(nil)

        if let (timestamp, createdAt) = cachedTimestamp, date <= createdAt + accuracy {
            return timestamp
        }
        
        // generate a key used for caching.
        // this key is a unique id for each day
        let key = date / secondsInDay
        
        // get time components
        let dateComponents: tm
        if let cached = cachedTimeComponents, cached.key == key {
            dateComponents = cached.components
        } else {
            let tc = gmtime(&date).pointee
            dateComponents = tc
            cachedTimeComponents = (key: key, components: tc)
        }
        
        // parse components
        let year: Int = numericCast(dateComponents.tm_year) + 1900 // years since 1900
        let month: Int = numericCast(dateComponents.tm_mon) // months since January [0-11]
        let monthDay: Int = numericCast(dateComponents.tm_mday) // day of the month [1-31]
        let weekDay: Int = numericCast(dateComponents.tm_wday) // days since Sunday [0-6]
        
        // get basic time info
        let time: Int = date % secondsInDay
        let hours: Int = numericCast(time / 3600)
        let minutes: Int = numericCast((time / 60) % 60)
        let seconds: Int = numericCast(time % 60)
        
        var rfc1123 = ""
        rfc1123.reserveCapacity(30)
        
        rfc1123.append(DAY_NAMES[weekDay])
        rfc1123.append(", ")
        rfc1123.append(NUMBERS[monthDay])
        rfc1123.append(" ")
        rfc1123.append(MONTH_NAMES[month])
        rfc1123.append(" ")
        rfc1123.append(NUMBERS[year / 100])
        rfc1123.append(NUMBERS[year % 100])
        rfc1123.append(" ")
        rfc1123.append(NUMBERS[hours])
        rfc1123.append(":")
        rfc1123.append(NUMBERS[minutes])
        rfc1123.append(":")
        rfc1123.append(NUMBERS[seconds])
        rfc1123.append(" GMT")

        cachedTimestamp = (rfc1123, date)
        
        return rfc1123
    }
}
