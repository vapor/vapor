/**
 Used to capture URLForm Coding Configuration used for encoding and decoding
 */
public struct URLEncodedFormCodingConfig {
    let bracketsAsArray: Bool
    let flagsAsBool: Bool
    let arraySeparator: Character?
    
    /**
     - parameters:
     - bracketsAsArray: Set to `true` allows you to parse `arr[]=v1&arr[]=v2` as an array with key `arr`. Otherwise you would use  `arr` without  a bracket like `arr=v1&arr=v2`
     - flagsAsBool: Set to `true` allows you to parse `flag1&flag2` as boolean variables where object with variable `flag1` and `flag2` would decode to `true` or `false` depending on if the value was present or not.
     If this flag is set to true, it will always resolve for an optional `Bool`.
     - arraySeparator: Uses this character to create arrays. If set to `,`, `arr=v1,v2` would populate a key named `arr` of type `Array` to be decoded as `["v1", "v2"]`
     
     */
    public init(bracketsAsArray: Bool, flagsAsBool: Bool, arraySeparator: Character?) {
        //We don't provide default values as the defaults for encoder differ from the decoder flagsAsBool is enabled for decoder, but not encoder.
        self.bracketsAsArray = bracketsAsArray
        self.flagsAsBool = flagsAsBool
        self.arraySeparator = arraySeparator
    }
}
