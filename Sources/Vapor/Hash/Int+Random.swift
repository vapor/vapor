import Random

extension Int {
    public static func random(min: Int, max: Int) -> Int {
        return Random.makeRandom(min: min, max: max)
    }
}
