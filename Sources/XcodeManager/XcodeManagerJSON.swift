//  XcodeManagerJSON.swift
//
//  Copyright (c) 2019, ShouDong Zheng
//  All rights reserved.

//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:

//  * Redistributions of source code must retain the above copyright notice, this
//   list of conditions and the following disclaimer.

//  * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.

//  * Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.

//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation

// MARK: - Error
// swiftlint:disable line_length
public enum XcodeManagerJSONError: Int, Swift.Error {
    case unsupportedType = 999
    case indexOutOfBounds = 900
    case elementTooDeep = 902
    case wrongType = 901
    case notExist = 500
    case invalidJSON = 490
}

extension XcodeManagerJSONError: CustomNSError {
    
    /// return the error domain of XcodeManagerJSONError
    public static var errorDomain: String { return "cn.XcodeManager.XcodeManagerJSON" }
    
    /// return the error code of XcodeManagerJSONError
    public var errorCode: Int { return self.rawValue }
    
    /// return the userInfo of XcodeManagerJSONError
    public var errorUserInfo: [String: Any] {
        switch self {
        case .unsupportedType:
            return [NSLocalizedDescriptionKey: "It is an unsupported type."]
        case .indexOutOfBounds:
            return [NSLocalizedDescriptionKey: "Array Index is out of bounds."]
        case .wrongType:
            return [NSLocalizedDescriptionKey: "Couldn't merge, because the JSONs differ in type on top level."]
        case .notExist:
            return [NSLocalizedDescriptionKey: "Dictionary key does not exist."]
        case .invalidJSON:
            return [NSLocalizedDescriptionKey: "JSON is invalid."]
        case .elementTooDeep:
            return [NSLocalizedDescriptionKey: "Element too deep. Increase maxObjectDepth and make sure there is no reference loop."]
        }
    }
}

// MARK: - XcodeManagerJSON Type

/**
 JSON's type definitions.
 
 See http://www.json.org
 */
public enum Type: Int {
    case unknown
    case number
    case string
    case bool
    case array
    case dictionary
    case null
}

// MARK: - XcodeManagerJSON Base

public struct XcodeManagerJSON {
    
    /**
     Creates a JSON using the data.
     
     - parameter data: The NSData used to convert to json.Top level object in data is an NSArray or NSDictionary
     - parameter opt: The JSON serialization reading options. `[]` by default.
     
     - returns: The created JSON
     */
    public init(data: Data, options opt: JSONSerialization.ReadingOptions = []) throws {
        let object: Any = try JSONSerialization.jsonObject(with: data, options: opt)
        self.init(jsonObject: object)
    }
    
    /**
     Creates a JSON object
     - note: this does not parse a `String` into JSON, instead use `init(parseJSON: String)`
     
     - parameter object: the object
     
     - returns: the created JSON object
     */
    public init(_ object: Any) {
        switch object {
        case let object as Data:
            do {
                try self.init(data: object)
            } catch {
                self.init(jsonObject: NSNull())
            }
        default:
            self.init(jsonObject: object)
        }
    }
    
    /**
     Parses the JSON string into a JSON object
     
     - parameter json: the JSON string
     
     - returns: the created JSON object
     */
    public init(parseJSON jsonString: String) {
        if let data = jsonString.data(using: .utf8) {
            self.init(data)
        } else {
            self.init(NSNull())
        }
    }
    
    /**
     Creates a JSON using the object.
     
     - parameter jsonObject:  The object must have the following properties: All objects are NSString/String, NSNumber/Int/Float/Double/Bool, NSArray/Array, NSDictionary/Dictionary, or NSNull; All dictionary keys are NSStrings/String; NSNumbers are not NaN or infinity.
     
     - returns: The created JSON
     */
    fileprivate init(jsonObject: Any) {
        self.object = jsonObject
    }
    
    /**
     Merges another JSON into this JSON, whereas primitive values which are not present in this JSON are getting added,
     present values getting overwritten, array values getting appended and nested JSONs getting merged the same way.
     
     - parameter other: The JSON which gets merged into this JSON
     
     - throws `ErrorWrongType` if the other JSONs differs in type on the top level.
     */
    public mutating func merge(with other: XcodeManagerJSON) throws {
        try self.merge(with: other, typecheck: true)
    }
    
    /**
     Merges another JSON into this JSON and returns a new JSON, whereas primitive values which are not present in this JSON are getting added,
     present values getting overwritten, array values getting appended and nested JSONS getting merged the same way.
     
     - parameter other: The JSON which gets merged into this JSON
     
     - throws `ErrorWrongType` if the other JSONs differs in type on the top level.
     
     - returns: New merged JSON
     */
    public func merged(with other: XcodeManagerJSON) throws -> XcodeManagerJSON {
        var merged = self
        try merged.merge(with: other, typecheck: true)
        return merged
    }
    
    /**
     Private woker function which does the actual merging
     Typecheck is set to true for the first recursion level to prevent total override of the source JSON
     */
    fileprivate mutating func merge(with other: XcodeManagerJSON, typecheck: Bool) throws {
        if self.type == other.type {
            switch self.type {
            case .dictionary:
                for (key, _) in other {
                    try self[key].merge(with: other[key], typecheck: false)
                }
            case .array:
                self = XcodeManagerJSON(self.arrayValue + other.arrayValue)
            default:
                self = other
            }
        } else {
            if typecheck {
                throw XcodeManagerJSONError.wrongType
            } else {
                self = other
            }
        }
    }
    
    /// Private object
    fileprivate var rawArray: [Any] = []
    fileprivate var rawDictionary: [String: Any] = [:]
    fileprivate var rawString: String = ""
    fileprivate var rawNumber: NSNumber = 0
    fileprivate var rawNull: NSNull = NSNull()
    fileprivate var rawBool: Bool = false
    
    /// JSON type, fileprivate setter
    public fileprivate(set) var type: Type = .null
    
    /// Error in JSON, fileprivate setter
    public fileprivate(set) var error: XcodeManagerJSONError?
    
    /// Object in JSON
    public var object: Any {
        get {
            switch self.type {
            case .array:
                return self.rawArray
            case .dictionary:
                return self.rawDictionary
            case .string:
                return self.rawString
            case .number:
                return self.rawNumber
            case .bool:
                return self.rawBool
            default:
                return self.rawNull
            }
        }
        set {
            error = nil
            switch unwrap(newValue) {
            case let number as NSNumber:
                if number.isBool {
                    type = .bool
                    self.rawBool = number.boolValue
                } else {
                    type = .number
                    self.rawNumber = number
                }
            case let string as String:
                type = .string
                self.rawString = string
            case _ as NSNull:
                type = .null
            case nil:
                type = .null
            case let array as [Any]:
                type = .array
                self.rawArray = array
            case let dictionary as [String: Any]:
                type = .dictionary
                self.rawDictionary = dictionary
            default:
                type = .unknown
                error = XcodeManagerJSONError.unsupportedType
            }
        }
    }
    
    /// The static null XcodeManagerJSON
    @available(*, unavailable, renamed:"null")
    public static var nullJSON: XcodeManagerJSON { return null }
    public static var null: XcodeManagerJSON { return XcodeManagerJSON(NSNull()) }
}

/// Private method to unwarp an object recursively
private func unwrap(_ object: Any) -> Any {
    switch object {
    case let json as XcodeManagerJSON:
        return unwrap(json.object)
    case let array as [Any]:
        return array.map(unwrap)
    case let dictionary as [String: Any]:
        var unwrappedDic = dictionary
        for (k, v) in dictionary {
            unwrappedDic[k] = unwrap(v)
        }
        return unwrappedDic
    default:
        return object
    }
}

public enum Index<T: Any>: Comparable {
    case array(Int)
    case dictionary(DictionaryIndex<String, T>)
    case null
    
    static public func == (lhs: Index, rhs: Index) -> Bool {
        switch (lhs, rhs) {
        case (.array(let left), .array(let right)):
            return left == right
        case (.dictionary(let left), .dictionary(let right)):
            return left == right
        case (.null, .null): return true
        default:
            return false
        }
    }
    
    static public func < (lhs: Index, rhs: Index) -> Bool {
        switch (lhs, rhs) {
        case (.array(let left), .array(let right)):
            return left < right
        case (.dictionary(let left), .dictionary(let right)):
            return left < right
        default:
            return false
        }
    }
}

public typealias JSONIndex = Index<XcodeManagerJSON>
public typealias JSONRawIndex = Index<Any>

extension XcodeManagerJSON: Swift.Collection {
    
    public typealias Index = JSONRawIndex
    
    public var startIndex: Index {
        switch type {
        case .array:
            return .array(rawArray.startIndex)
        case .dictionary:
            return .dictionary(rawDictionary.startIndex)
        default:
            return .null
        }
    }
    
    public var endIndex: Index {
        switch type {
        case .array:
            return .array(rawArray.endIndex)
        case .dictionary:
            return .dictionary(rawDictionary.endIndex)
        default:
            return .null
        }
    }
    
    public func index(after i: Index) -> Index {
        switch i {
        case .array(let idx):
            return .array(rawArray.index(after: idx))
        case .dictionary(let idx):
            return .dictionary(rawDictionary.index(after: idx))
        default:
            return .null
        }
    }
    
    public subscript (position: Index) -> (String, XcodeManagerJSON) {
        switch position {
        case .array(let idx):
            return (String(idx), XcodeManagerJSON(self.rawArray[idx]))
        case .dictionary(let idx):
            let (key, value) = self.rawDictionary[idx]
            return (key, XcodeManagerJSON(value))
        default:
            return ("", XcodeManagerJSON.null)
        }
    }
}

// MARK: - Subscript

/**
 *  To mark both String and Int can be used in subscript.
 */
public enum JSONKey {
    case index(Int)
    case key(String)
}

public protocol JSONSubscriptType {
    var jsonKey: JSONKey { get }
}

extension Int: JSONSubscriptType {
    public var jsonKey: JSONKey {
        return JSONKey.index(self)
    }
}

extension String: JSONSubscriptType {
    public var jsonKey: JSONKey {
        return JSONKey.key(self)
    }
}

extension XcodeManagerJSON {
    
    /// If `type` is `.array`, return json whose object is `array[index]`, otherwise return null json with error.
    fileprivate subscript(index index: Int) -> XcodeManagerJSON {
        get {
            if self.type != .array {
                var r = XcodeManagerJSON.null
                r.error = self.error ?? XcodeManagerJSONError.wrongType
                return r
            } else if self.rawArray.indices.contains(index) {
                return XcodeManagerJSON(self.rawArray[index])
            } else {
                var r = XcodeManagerJSON.null
                r.error = XcodeManagerJSONError.indexOutOfBounds
                return r
            }
        }
        set {
            if self.type == .array &&
                self.rawArray.indices.contains(index) &&
                newValue.error == nil {
                self.rawArray[index] = newValue.object
            }
        }
    }
    
    /// If `type` is `.dictionary`, return json whose object is `dictionary[key]` , otherwise return null json with error.
    fileprivate subscript(key key: String) -> XcodeManagerJSON {
        get {
            var r = XcodeManagerJSON.null
            if self.type == .dictionary {
                if let o = self.rawDictionary[key] {
                    r = XcodeManagerJSON(o)
                } else {
                    r.error = XcodeManagerJSONError.notExist
                }
            } else {
                r.error = self.error ?? XcodeManagerJSONError.wrongType
            }
            return r
        }
        set {
            if self.type == .dictionary && newValue.error == nil {
                self.rawDictionary[key] = newValue.object
            }
        }
    }
    
    /// If `sub` is `Int`, return `subscript(index:)`; If `sub` is `String`,  return `subscript(key:)`.
    fileprivate subscript(sub sub: JSONSubscriptType) -> XcodeManagerJSON {
        get {
            switch sub.jsonKey {
            case .index(let index): return self[index: index]
            case .key(let key): return self[key: key]
            }
        }
        set {
            switch sub.jsonKey {
            case .index(let index): self[index: index] = newValue
            case .key(let key): self[key: key] = newValue
            }
        }
    }
    
    /**
     Find a json in the complex data structures by using array of Int and/or String as path.
     
     Example:
     
     ```
     let json = XcodeManagerJSON[data]
     let path = [9,"list","person","name"]
     let name = json[path]
     ```
     
     The same as: let name = json[9]["list"]["person"]["name"]
     
     - parameter path: The target json's path.
     
     - returns: Return a json found by the path or a null json with error
     */
    public subscript(path: [JSONSubscriptType]) -> XcodeManagerJSON {
        get {
            return path.reduce(self) { $0[sub: $1] }
        }
        set {
            switch path.count {
            case 0:
                return
            case 1:
                self[sub:path[0]].object = newValue.object
            default:
                var aPath = path
                aPath.remove(at: 0)
                var nextJSON = self[sub: path[0]]
                nextJSON[aPath] = newValue
                self[sub: path[0]] = nextJSON
            }
        }
    }
    
    /**
     Find a json in the complex data structures by using array of Int and/or String as path.
     
     - parameter path: The target json's path. Example:
     
     let name = json[9,"list","person","name"]
     
     The same as: let name = json[9]["list"]["person"]["name"]
     
     - returns: Return a json found by the path or a null json with error
     */
    public subscript(path: JSONSubscriptType...) -> XcodeManagerJSON {
        get {
            return self[path]
        }
        set {
            self[path] = newValue
        }
    }
}

// MARK: - LiteralConvertible

extension XcodeManagerJSON: Swift.ExpressibleByStringLiteral {
    
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
    
    public init(extendedGraphemeClusterLiteral value: StringLiteralType) {
        self.init(value)
    }
    
    public init(unicodeScalarLiteral value: StringLiteralType) {
        self.init(value)
    }
}

extension XcodeManagerJSON: Swift.ExpressibleByIntegerLiteral {
    
    public init(integerLiteral value: IntegerLiteralType) {
        self.init(value)
    }
}

extension XcodeManagerJSON: Swift.ExpressibleByBooleanLiteral {
    
    public init(booleanLiteral value: BooleanLiteralType) {
        self.init(value)
    }
}

extension XcodeManagerJSON: Swift.ExpressibleByFloatLiteral {
    
    public init(floatLiteral value: FloatLiteralType) {
        self.init(value)
    }
}

extension XcodeManagerJSON: Swift.ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        let dictionary = elements.reduce(into: [String: Any](), { $0[$1.0] = $1.1})
        self.init(dictionary)
    }
}

extension XcodeManagerJSON: Swift.ExpressibleByArrayLiteral {
    
    public init(arrayLiteral elements: Any...) {
        self.init(elements)
    }
}

// MARK: - Raw

extension XcodeManagerJSON: Swift.RawRepresentable {
    
    public init?(rawValue: Any) {
        if XcodeManagerJSON(rawValue).type == .unknown {
            return nil
        } else {
            self.init(rawValue)
        }
    }
    
    public var rawValue: Any {
        return self.object
    }
    
    public func rawData(options opt: JSONSerialization.WritingOptions = JSONSerialization.WritingOptions(rawValue: 0)) throws -> Data {
        guard JSONSerialization.isValidJSONObject(self.object) else {
            throw XcodeManagerJSONError.invalidJSON
        }
        
        return try JSONSerialization.data(withJSONObject: self.object, options: opt)
    }
    
    public func rawString(_ encoding: String.Encoding = .utf8, options opt: JSONSerialization.WritingOptions = .prettyPrinted) -> String? {
        do {
            return try _rawString(encoding, options: [.jsonSerialization: opt])
        } catch {
            print("Could not serialize object to JSON because:", error.localizedDescription)
            return nil
        }
    }
    
    public func rawString(_ options: [writingOptionsKeys: Any]) -> String? {
        let encoding = options[.encoding] as? String.Encoding ?? String.Encoding.utf8
        let maxObjectDepth = options[.maxObjextDepth] as? Int ?? 10
        do {
            return try _rawString(encoding, options: options, maxObjectDepth: maxObjectDepth)
        } catch {
            print("Could not serialize object to JSON because:", error.localizedDescription)
            return nil
        }
    }
    
    fileprivate func _rawString(_ encoding: String.Encoding = .utf8, options: [writingOptionsKeys: Any], maxObjectDepth: Int = 10) throws -> String? {
        guard maxObjectDepth > 0 else { throw XcodeManagerJSONError.invalidJSON }
        switch self.type {
        case .dictionary:
            do {
                if !(options[.castNilToNSNull] as? Bool ?? false) {
                    let jsonOption = options[.jsonSerialization] as? JSONSerialization.WritingOptions ?? JSONSerialization.WritingOptions.prettyPrinted
                    let data = try self.rawData(options: jsonOption)
                    return String(data: data, encoding: encoding)
                }
                
                guard let dict = self.object as? [String: Any?] else {
                    return nil
                }
                let body = try dict.keys.map { key throws -> String in
                    guard let value = dict[key] else {
                        return "\"\(key)\": null"
                    }
                    guard let unwrappedValue = value else {
                        return "\"\(key)\": null"
                    }
                    
                    let nestedValue = XcodeManagerJSON(unwrappedValue)
                    guard let nestedString = try nestedValue._rawString(encoding, options: options, maxObjectDepth: maxObjectDepth - 1) else {
                        throw XcodeManagerJSONError.elementTooDeep
                    }
                    if nestedValue.type == .string {
                        return "\"\(key)\": \"\(nestedString.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
                    } else {
                        return "\"\(key)\": \(nestedString)"
                    }
                }
                
                return "{\(body.joined(separator: ","))}"
            } catch _ {
                return nil
            }
        case .array:
            do {
                if !(options[.castNilToNSNull] as? Bool ?? false) {
                    let jsonOption = options[.jsonSerialization] as? JSONSerialization.WritingOptions ?? JSONSerialization.WritingOptions.prettyPrinted
                    let data = try self.rawData(options: jsonOption)
                    return String(data: data, encoding: encoding)
                }
                
                guard let array = self.object as? [Any?] else {
                    return nil
                }
                let body = try array.map { value throws -> String in
                    guard let unwrappedValue = value else {
                        return "null"
                    }
                    
                    let nestedValue = XcodeManagerJSON(unwrappedValue)
                    guard let nestedString = try nestedValue._rawString(encoding, options: options, maxObjectDepth: maxObjectDepth - 1) else {
                        throw XcodeManagerJSONError.invalidJSON
                    }
                    if nestedValue.type == .string {
                        return "\"\(nestedString.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
                    } else {
                        return nestedString
                    }
                }
                
                return "[\(body.joined(separator: ","))]"
            } catch _ {
                return nil
            }
        case .string:
            return self.rawString
        case .number:
            return self.rawNumber.stringValue
        case .bool:
            return self.rawBool.description
        case .null:
            return "null"
        default:
            return nil
        }
    }
}

// MARK: - Printable, DebugPrintable

extension XcodeManagerJSON: Swift.CustomStringConvertible, Swift.CustomDebugStringConvertible {
    
    public var description: String {
        if let string = self.rawString(options: .prettyPrinted) {
            return string
        } else {
            return "unknown"
        }
    }
    
    public var debugDescription: String {
        return description
    }
}

// MARK: - Array

extension XcodeManagerJSON {
    
    //Optional [XcodeManagerJSON]
    public var array: [XcodeManagerJSON]? {
        if self.type == .array {
            return self.rawArray.map { XcodeManagerJSON($0) }
        } else {
            return nil
        }
    }
    
    //Non-optional [XcodeManagerJSON]
    public var arrayValue: [XcodeManagerJSON] {
        return self.array ?? []
    }
    
    //Optional [Any]
    public var arrayObject: [Any]? {
        get {
            switch self.type {
            case .array:
                return self.rawArray
            default:
                return nil
            }
        }
        set {
            if let array = newValue {
                self.object = array
            } else {
                self.object = NSNull()
            }
        }
    }
}

// MARK: - Dictionary

extension XcodeManagerJSON {
    
    //Optional [String : XcodeManagerJSON]
    public var dictionary: [String: XcodeManagerJSON]? {
        if self.type == .dictionary {
            var d = [String: XcodeManagerJSON](minimumCapacity: rawDictionary.count)
            for (key, value) in rawDictionary {
                d[key] = XcodeManagerJSON(value)
            }
            return d
        } else {
            return nil
        }
    }
    
    //Non-optional [String : XcodeManagerJSON]
    public var dictionaryValue: [String: XcodeManagerJSON] {
        return self.dictionary ?? [:]
    }
    
    //Optional [String : Any]
    
    public var dictionaryObject: [String: Any]? {
        get {
            switch self.type {
            case .dictionary:
                return self.rawDictionary
            default:
                return nil
            }
        }
        set {
            if let v = newValue {
                self.object = v
            } else {
                self.object = NSNull()
            }
        }
    }
}

// MARK: - Bool

extension XcodeManagerJSON { // : Swift.Bool
    
    //Optional bool
    public var bool: Bool? {
        get {
            switch self.type {
            case .bool:
                return self.rawBool
            default:
                return nil
            }
        }
        set {
            if let newValue = newValue {
                self.object = newValue as Bool
            } else {
                self.object = NSNull()
            }
        }
    }
    
    //Non-optional bool
    public var boolValue: Bool {
        get {
            switch self.type {
            case .bool:
                return self.rawBool
            case .number:
                return self.rawNumber.boolValue
            case .string:
                return ["true", "y", "t", "yes", "1"].contains { self.rawString.caseInsensitiveCompare($0) == .orderedSame }
            default:
                return false
            }
        }
        set {
            self.object = newValue
        }
    }
}

// MARK: - String

extension XcodeManagerJSON {
    
    //Optional string
    public var string: String? {
        get {
            switch self.type {
            case .string:
                return self.object as? String
            default:
                return nil
            }
        }
        set {
            if let newValue = newValue {
                self.object = NSString(string: newValue)
            } else {
                self.object = NSNull()
            }
        }
    }
    
    //Non-optional string
    public var stringValue: String {
        get {
            switch self.type {
            case .string:
                return self.object as? String ?? ""
            case .number:
                return self.rawNumber.stringValue
            case .bool:
                return (self.object as? Bool).map { String($0) } ?? ""
            default:
                return ""
            }
        }
        set {
            self.object = NSString(string: newValue)
        }
    }
}

// MARK: - Number

extension XcodeManagerJSON {
    
    //Optional number
    public var number: NSNumber? {
        get {
            switch self.type {
            case .number:
                return self.rawNumber
            case .bool:
                return NSNumber(value: self.rawBool ? 1 : 0)
            default:
                return nil
            }
        }
        set {
            self.object = newValue ?? NSNull()
        }
    }
    
    //Non-optional number
    public var numberValue: NSNumber {
        get {
            switch self.type {
            case .string:
                let decimal = NSDecimalNumber(string: self.object as? String)
                if decimal == NSDecimalNumber.notANumber {  // indicates parse error
                    return NSDecimalNumber.zero
                }
                return decimal
            case .number:
                return self.object as? NSNumber ?? NSNumber(value: 0)
            case .bool:
                return NSNumber(value: self.rawBool ? 1 : 0)
            default:
                return NSNumber(value: 0.0)
            }
        }
        set {
            self.object = newValue
        }
    }
}

// MARK: - Null

extension XcodeManagerJSON {
    
    public var null: NSNull? {
        get {
            switch self.type {
            case .null:
                return self.rawNull
            default:
                return nil
            }
        }
        set {
            self.object = NSNull()
        }
    }
    public func exists() -> Bool {
        if let errorValue = error, (400...1000).contains(errorValue.errorCode) {
            return false
        }
        return true
    }
}

// MARK: - URL

extension XcodeManagerJSON {
    
    //Optional URL
    public var url: URL? {
        get {
            switch self.type {
            case .string:
                // Check for existing percent escapes first to prevent double-escaping of % character
                if self.rawString.range(of: "%[0-9A-Fa-f]{2}", options: .regularExpression, range: nil, locale: nil) != nil {
                    return Foundation.URL(string: self.rawString)
                } else if let encodedString_ = self.rawString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) {
                    // We have to use `Foundation.URL` otherwise it conflicts with the variable name.
                    return Foundation.URL(string: encodedString_)
                } else {
                    return nil
                }
            default:
                return nil
            }
        }
        set {
            self.object = newValue?.absoluteString ?? NSNull()
        }
    }
}

// MARK: - Int, Double, Float, Int8, Int16, Int32, Int64

extension XcodeManagerJSON {
    
    public var double: Double? {
        get {
            return self.number?.doubleValue
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object = NSNull()
            }
        }
    }
    
    public var doubleValue: Double {
        get {
            return self.numberValue.doubleValue
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }
    
    public var float: Float? {
        get {
            return self.number?.floatValue
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object = NSNull()
            }
        }
    }
    
    public var floatValue: Float {
        get {
            return self.numberValue.floatValue
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }
    
    public var int: Int? {
        get {
            return self.number?.intValue
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object = NSNull()
            }
        }
    }
    
    public var intValue: Int {
        get {
            return self.numberValue.intValue
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }
    
    public var uInt: UInt? {
        get {
            return self.number?.uintValue
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object = NSNull()
            }
        }
    }
    
    public var uIntValue: UInt {
        get {
            return self.numberValue.uintValue
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }
    
    public var int8: Int8? {
        get {
            return self.number?.int8Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: Int(newValue))
            } else {
                self.object =  NSNull()
            }
        }
    }
    
    public var int8Value: Int8 {
        get {
            return self.numberValue.int8Value
        }
        set {
            self.object = NSNumber(value: Int(newValue))
        }
    }
    
    public var uInt8: UInt8? {
        get {
            return self.number?.uint8Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }
    
    public var uInt8Value: UInt8 {
        get {
            return self.numberValue.uint8Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }
    
    public var int16: Int16? {
        get {
            return self.number?.int16Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }
    
    public var int16Value: Int16 {
        get {
            return self.numberValue.int16Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }
    
    public var uInt16: UInt16? {
        get {
            return self.number?.uint16Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }
    
    public var uInt16Value: UInt16 {
        get {
            return self.numberValue.uint16Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }
    
    public var int32: Int32? {
        get {
            return self.number?.int32Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }
    
    public var int32Value: Int32 {
        get {
            return self.numberValue.int32Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }
    
    public var uInt32: UInt32? {
        get {
            return self.number?.uint32Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }
    
    public var uInt32Value: UInt32 {
        get {
            return self.numberValue.uint32Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }
    
    public var int64: Int64? {
        get {
            return self.number?.int64Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }
    
    public var int64Value: Int64 {
        get {
            return self.numberValue.int64Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }
    
    public var uInt64: UInt64? {
        get {
            return self.number?.uint64Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }
    
    public var uInt64Value: UInt64 {
        get {
            return self.numberValue.uint64Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }
}

// MARK: - Comparable

extension XcodeManagerJSON: Swift.Comparable {}

public func == (lhs: XcodeManagerJSON, rhs: XcodeManagerJSON) -> Bool {
    
    switch (lhs.type, rhs.type) {
    case (.number, .number):
        return lhs.rawNumber == rhs.rawNumber
    case (.string, .string):
        return lhs.rawString == rhs.rawString
    case (.bool, .bool):
        return lhs.rawBool == rhs.rawBool
    case (.array, .array):
        return lhs.rawArray as NSArray == rhs.rawArray as NSArray
    case (.dictionary, .dictionary):
        return lhs.rawDictionary as NSDictionary == rhs.rawDictionary as NSDictionary
    case (.null, .null):
        return true
    default:
        return false
    }
}

public func <= (lhs: XcodeManagerJSON, rhs: XcodeManagerJSON) -> Bool {
    
    switch (lhs.type, rhs.type) {
    case (.number, .number):
        return lhs.rawNumber <= rhs.rawNumber
    case (.string, .string):
        return lhs.rawString <= rhs.rawString
    case (.bool, .bool):
        return lhs.rawBool == rhs.rawBool
    case (.array, .array):
        return lhs.rawArray as NSArray == rhs.rawArray as NSArray
    case (.dictionary, .dictionary):
        return lhs.rawDictionary as NSDictionary == rhs.rawDictionary as NSDictionary
    case (.null, .null):
        return true
    default:
        return false
    }
}

public func >= (lhs: XcodeManagerJSON, rhs: XcodeManagerJSON) -> Bool {
    
    switch (lhs.type, rhs.type) {
    case (.number, .number):
        return lhs.rawNumber >= rhs.rawNumber
    case (.string, .string):
        return lhs.rawString >= rhs.rawString
    case (.bool, .bool):
        return lhs.rawBool == rhs.rawBool
    case (.array, .array):
        return lhs.rawArray as NSArray == rhs.rawArray as NSArray
    case (.dictionary, .dictionary):
        return lhs.rawDictionary as NSDictionary == rhs.rawDictionary as NSDictionary
    case (.null, .null):
        return true
    default:
        return false
    }
}

public func > (lhs: XcodeManagerJSON, rhs: XcodeManagerJSON) -> Bool {
    
    switch (lhs.type, rhs.type) {
    case (.number, .number):
        return lhs.rawNumber > rhs.rawNumber
    case (.string, .string):
        return lhs.rawString > rhs.rawString
    default:
        return false
    }
}

public func < (lhs: XcodeManagerJSON, rhs: XcodeManagerJSON) -> Bool {
    
    switch (lhs.type, rhs.type) {
    case (.number, .number):
        return lhs.rawNumber < rhs.rawNumber
    case (.string, .string):
        return lhs.rawString < rhs.rawString
    default:
        return false
    }
}

private let trueNumber = NSNumber(value: true)
private let falseNumber = NSNumber(value: false)
private let trueObjCType = String(cString: trueNumber.objCType)
private let falseObjCType = String(cString: falseNumber.objCType)

// MARK: - NSNumber: Comparable

extension NSNumber {
    fileprivate var isBool: Bool {
        let objCType = String(cString: self.objCType)
        if (self.compare(trueNumber) == .orderedSame && objCType == trueObjCType) || (self.compare(falseNumber) == .orderedSame && objCType == falseObjCType) {
            return true
        } else {
            return false
        }
    }
}

func == (lhs: NSNumber, rhs: NSNumber) -> Bool {
    switch (lhs.isBool, rhs.isBool) {
    case (false, true):
        return false
    case (true, false):
        return false
    default:
        return lhs.compare(rhs) == .orderedSame
    }
}

func != (lhs: NSNumber, rhs: NSNumber) -> Bool {
    return !(lhs == rhs)
}

func < (lhs: NSNumber, rhs: NSNumber) -> Bool {
    
    switch (lhs.isBool, rhs.isBool) {
    case (false, true):
        return false
    case (true, false):
        return false
    default:
        return lhs.compare(rhs) == .orderedAscending
    }
}

func > (lhs: NSNumber, rhs: NSNumber) -> Bool {
    
    switch (lhs.isBool, rhs.isBool) {
    case (false, true):
        return false
    case (true, false):
        return false
    default:
        return lhs.compare(rhs) == ComparisonResult.orderedDescending
    }
}

func <= (lhs: NSNumber, rhs: NSNumber) -> Bool {
    
    switch (lhs.isBool, rhs.isBool) {
    case (false, true):
        return false
    case (true, false):
        return false
    default:
        return lhs.compare(rhs) != .orderedDescending
    }
}

func >= (lhs: NSNumber, rhs: NSNumber) -> Bool {
    
    switch (lhs.isBool, rhs.isBool) {
    case (false, true):
        return false
    case (true, false):
        return false
    default:
        return lhs.compare(rhs) != .orderedAscending
    }
}

public enum writingOptionsKeys {
    case jsonSerialization
    case castNilToNSNull
    case maxObjextDepth
    case encoding
}

// MARK: - XcodeManagerJSON: Codable
extension XcodeManagerJSON: Codable {
    private static var codableTypes: [Codable.Type] {
        return [
            Bool.self,
            Int.self,
            Int8.self,
            Int16.self,
            Int32.self,
            Int64.self,
            UInt.self,
            UInt8.self,
            UInt16.self,
            UInt32.self,
            UInt64.self,
            Double.self,
            String.self,
            [XcodeManagerJSON].self,
            [String: XcodeManagerJSON].self
        ]
    }
    public init(from decoder: Decoder) throws {
        var object: Any?
        
        if let container = try? decoder.singleValueContainer(), !container.decodeNil() {
            for type in XcodeManagerJSON.codableTypes {
                if object != nil {
                    break
                }
                // try to decode value
                switch type {
                case let boolType as Bool.Type:
                    object = try? container.decode(boolType)
                case let intType as Int.Type:
                    object = try? container.decode(intType)
                case let int8Type as Int8.Type:
                    object = try? container.decode(int8Type)
                case let int32Type as Int32.Type:
                    object = try? container.decode(int32Type)
                case let int64Type as Int64.Type:
                    object = try? container.decode(int64Type)
                case let uintType as UInt.Type:
                    object = try? container.decode(uintType)
                case let uint8Type as UInt8.Type:
                    object = try? container.decode(uint8Type)
                case let uint16Type as UInt16.Type:
                    object = try? container.decode(uint16Type)
                case let uint32Type as UInt32.Type:
                    object = try? container.decode(uint32Type)
                case let uint64Type as UInt64.Type:
                    object = try? container.decode(uint64Type)
                case let doubleType as Double.Type:
                    object = try? container.decode(doubleType)
                case let stringType as String.Type:
                    object = try? container.decode(stringType)
                case let jsonValueArrayType as [XcodeManagerJSON].Type:
                    object = try? container.decode(jsonValueArrayType)
                case let jsonValueDictType as [String: XcodeManagerJSON].Type:
                    object = try? container.decode(jsonValueDictType)
                default:
                    break
                }
            }
        }
        self.init(object ?? NSNull())
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if object is NSNull {
            try container.encodeNil()
            return
        }
        switch object {
        case let intValue as Int:
            try container.encode(intValue)
        case let int8Value as Int8:
            try container.encode(int8Value)
        case let int32Value as Int32:
            try container.encode(int32Value)
        case let int64Value as Int64:
            try container.encode(int64Value)
        case let uintValue as UInt:
            try container.encode(uintValue)
        case let uint8Value as UInt8:
            try container.encode(uint8Value)
        case let uint16Value as UInt16:
            try container.encode(uint16Value)
        case let uint32Value as UInt32:
            try container.encode(uint32Value)
        case let uint64Value as UInt64:
            try container.encode(uint64Value)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case is [Any]:
            let jsonValueArray = array ?? []
            try container.encode(jsonValueArray)
        case is [String: Any]:
            let jsonValueDictValue = dictionary ?? [:]
            try container.encode(jsonValueDictValue)
        default:
            break
        }
    }
}
