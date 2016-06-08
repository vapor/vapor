import libc

extension Response {
    public static var date: String {
        let DAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

        let RFC1123_TIME_LEN = 29
        var t: time_t = 0
        var tm: libc.tm = libc.tm()

        let buf = UnsafeMutablePointer<Int8>.init(allocatingCapacity: RFC1123_TIME_LEN + 1)
        defer { buf.deallocateCapacity(RFC1123_TIME_LEN + 1) }

        time(&t)
        gmtime_r(&t, &tm)

        strftime(buf, RFC1123_TIME_LEN+1, "---, %d --- %Y %H:%M:%S GMT", &tm)
        memcpy(buf, DAY_NAMES[Int(tm.tm_wday)], 3)
        memcpy(buf+8, MONTH_NAMES[Int(tm.tm_mon)], 3)


        return String(pointer: buf, length: RFC1123_TIME_LEN + 1) ?? ""
    }
}
