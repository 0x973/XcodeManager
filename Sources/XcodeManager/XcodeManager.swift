//  XcodeManager.swift
//
//  Copyright (c) 2018, ShouDong Zheng
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
import SwiftyJSON

public struct XcodeManager {
    
    /// cache
    private var _hashTag: Int = Int()
    private var _cacheProjet: JSON = JSON()
    private var _filePath: String = String()
    
    /// logger
    private var _logger: XcodeManagerLogger = XcodeManagerLogger()
    
    /// main group uuid
    private var _mainGroupUUID: String = String()
    /// root object uuid
    private var _rootObjectUUID: String = String()
    /// current project name
    private var _currentProjectName: String = String()
    
    public enum CodeSignStyleType: String {
        case automatic = "Automatic"
        case manual = "Manual"
    }
    
    public enum XcodeManagerErrorCode: Int {
        case unInitialized = -1
        case invalidParameters = 600
        case failedInitialized = 601
        case parsedError = 602
    }
    
    private enum XcodeManagerError: Error {
        case invalidParameters(code: XcodeManagerErrorCode , reason: String)
        case failedInitialized(code: XcodeManagerErrorCode, reason: String)
        case saveFailed(code: XcodeManagerErrorCode, reason: String)
    }
    
    public init(projectFile: String, printLog: Bool = true) throws {
        _logger.isPrintLog = printLog
        do {
            _ = try self.parseProject(projectFile)
        }catch {
            _logger.xcodeManagerPrintLog("\(error)", type: .error)
            throw error
        }
    }
    
    public mutating func initProject(projectFile: String, printLog: Bool = true) throws {
        _logger.isPrintLog = printLog
        do {
            _ = try self.parseProject(projectFile)
        }catch {
            _logger.xcodeManagerPrintLog("\(error)", type: .error)
            throw error
        }
    }
    
    /// parse ProjectFile
    private mutating func parseProject(_ filePath: String) throws -> JSON {
        
        if (filePath.isEmpty || !FileManager.default.fileExists(atPath: filePath)) {
            _logger.xcodeManagerPrintLog("Invalid parameters", type: .error)
            throw XcodeManagerError.invalidParameters(code: .invalidParameters, reason: "file not found!")
        }
        
        var fileUrl = URL(fileURLWithPath: filePath)
        
        if (!fileUrl.isFileURL) {
            throw XcodeManagerError.invalidParameters(code: .invalidParameters, reason: "read project file failed.")
        }
        
        if fileUrl.pathExtension == "xcodeproj" {
            fileUrl.appendPathComponent("project.pbxproj")
        }
        
        do {
            let fileData = try Data(contentsOf: fileUrl)
            
            let totalHashValue = fileData.hashValue ^ filePath.hashValue &* 1024
            
            if (self._hashTag == totalHashValue && !self._cacheProjet.isEmpty) {
                return self._cacheProjet
            }
            
            self._filePath = filePath
            self._hashTag = totalHashValue
            
            let data = try PropertyListSerialization.propertyList(from: fileData, options: .mutableContainersAndLeaves, format: nil)
            self._cacheProjet = JSON(data)
            self._rootObjectUUID = self._cacheProjet["rootObject"].string ?? String()
            let obj = self._cacheProjet["objects"].dictionary ?? Dictionary()
            let rootObject = obj[self._rootObjectUUID]?.dictionary ?? Dictionary()
            self._mainGroupUUID = rootObject["mainGroup"]?.string ?? String()
            
            if (rootObject.isEmpty || self._mainGroupUUID.isEmpty) {
                _logger.xcodeManagerPrintLog("read project file failed. error: file data is incomplete", type: .error)
                throw XcodeManagerError.failedInitialized(code: .failedInitialized, reason: "file data is incomplete!")
            }
            
            for (_, value) in rootObject {
                if (!value.isEmpty) {
                    if (value["isa"].stringValue == "PBXNativeTarget" &&
                        value["productType"].stringValue == "com.apple.product-type.application") {
                        self._currentProjectName = value["name"].stringValue
                        break
                    }
                }
            }
            return self._cacheProjet
        } catch {
            _logger.xcodeManagerPrintLog("read project file failed. error: \(error.localizedDescription)", type: .error)
            throw XcodeManagerError.failedInitialized(code: .failedInitialized, reason: "read project file failed.\(error)")
        }
    }
    
    private func saveProject(fileURL: URL, withPropertyList list: Any) -> Bool {
        let url = fileURL
        
        func handleEncode(fileURL: URL) -> Bool {
            func encodeString(_ str: String) -> String {
                var result = String()
                for scalar in str.unicodeScalars {
                    if (scalar.value > 0x4e00 && scalar.value < 0x9fff) {
                        result += String(format: "&#%04d;", scalar.value)
                    } else {
                        result += scalar.description
                    }
                }
                return result
            }
            do {
                var txt = try String(contentsOf: fileURL, encoding: .utf8)
                txt = encodeString(txt)
                try txt.write(to: fileURL, atomically: true, encoding: .utf8)
                return true
            } catch {
                _logger.xcodeManagerPrintLog("Translate chinese characters to mathematical symbols error: \(error.localizedDescription)", type: .error)
                return false
            }
        }
        
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: list, format: .xml, options: 0)
            try data.write(to: url, options: .atomic)
            return handleEncode(fileURL: url)
        } catch {
            _logger.xcodeManagerPrintLog("Save project file failed: \(error.localizedDescription)", type: .error)
            return false
        }
    }
    
    /// Get all objects uuid
    private func getAllUUIDs(_ projectDict: JSON) -> Array<String> {
        let objects = projectDict["objects"].dictionaryObject ?? Dictionary()
        
        var uuids = Array<String>()
        
        objects.forEach { (key, value) in
            if (key.lengthOfBytes(using: .utf8) == 24) {
                uuids.append(key)
            }
        }
        return uuids
    }
    
    
    /// Generate new uuid
    private func generateUUID() -> String {
        assert(!self._cacheProjet.isEmpty, "Uninitialized!")
        
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "").suffix(24).uppercased()
        let array = self.getAllUUIDs(self._cacheProjet)
        if (array.index(of: uuid) ?? -1 >= 0) {
            return generateUUID()
        }
        return uuid
    }
    
    /// in project root node generate the 'PBX' group, mount and write in memory cache
    ///
    /// - Parameter name: needed generate the 'PBX' group
    /// - Returns: return a new uuid with added 'PBX' group
    private mutating func generatePBXGroup(name: String) -> String {
        assert(!name.isEmpty, "Invalid parameters")
        
        let newUUID = generateUUID()
        let newDict = [
            "children": [],
            "isa": "PBXGroup",
            "name": name,
            "sourceTree": "<group>",
            "path": String(format: "%@/%@", _currentProjectName, name)
            ] as [String : Any]
        self._cacheProjet["objects"][newUUID] = JSON(newDict)
        
        var mainGroupObj = self._cacheProjet["objects"][self._mainGroupUUID]
        var mainGroupObjChildren = mainGroupObj["children"].arrayObject ?? Array()
        
        mainGroupObjChildren.append(newUUID)
        mainGroupObj["children"] = JSON(mainGroupObjChildren)
        self._cacheProjet["objects"][self._mainGroupUUID] = mainGroupObj
        
        return newUUID
    }
    
    
    /// Add framework to project
    ///
    /// - Parameter frameworkFilePath: framework path
    public mutating func linkFramework(_ frameworkFilePath: String) {
        assert(!self._cacheProjet.isEmpty, "Uninitialized!")
        assert(!frameworkFilePath.isEmpty && FileManager.default.fileExists(atPath: frameworkFilePath),
               "Invalid parameters")
        
        var objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        assert(!objects.isEmpty, "Objects parsed error!")
        
        var dict = Dictionary<String, Any>()
        dict["isa"] = "PBXFileReference"
        dict["lastKnownFileType"] = "wrapper.framework"
        dict["sourceTree"] = "<group>"
        dict["name"] = frameworkFilePath.split(separator: "/").last ?? frameworkFilePath
        dict["path"] = frameworkFilePath
        let jsonObj = JSON(dict)
        
        for object in objects {
            if (object.value == jsonObj) {
                _logger.xcodeManagerPrintLog("Current object already exists.")
                return
            }
        }
        
        let PBXFileReferenceUUID = generateUUID()
        objects[PBXFileReferenceUUID] = jsonObj
        
        let PBXBuildFileUUID = generateUUID()
        var dict2 = Dictionary<String, Any>()
        dict2["fileRef"] = PBXFileReferenceUUID
        dict2["isa"] = "PBXBuildFile"
        dict2["settings"] = ["ATTRIBUTES": ["Required"]] // Required OR Weak
        objects[PBXBuildFileUUID] = JSON(dict2)
        
        for object in objects {
            if var obj = object.value.dictionaryObject {
                if (obj["isa"] as? String == "PBXFrameworksBuildPhase") {
                    var files = obj["files"] as? Array<String> ?? Array()
                    files.append(PBXBuildFileUUID)
                    obj["files"] = files
                    objects[object.key] = JSON(obj)
                }
            }
            
        }
        
        self._cacheProjet["objects"] = JSON(objects)
        
        let newPath = frameworkFilePath.replacingOccurrences(of: frameworkFilePath.split(separator: "/").last ?? "", with: "")
        self.setFrameworkSearchPathValue(newPath)
    }
    
    
    /// Add static library to project
    ///
    /// - Parameter staticLibraryFilePath: static library file path
    public mutating func linkStaticLibrary(_ staticLibraryFilePath: String) {
        assert(!self._cacheProjet.isEmpty, "Uninitialized!")
        
        assert(!staticLibraryFilePath.isEmpty && FileManager.default.fileExists(atPath: staticLibraryFilePath),
               "Invalid parameters")
        
        var objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        assert(!objects.isEmpty, "Objects parsed error!")
        
        var dict = Dictionary<String, Any>()
        dict["isa"] = "PBXFileReference"
        dict["lastKnownFileType"] = "archive.ar"
        dict["sourceTree"] = "<group>"
        dict["name"] = staticLibraryFilePath.split(separator: "/").last ?? staticLibraryFilePath
        dict["path"] = staticLibraryFilePath
        let jsonObj = JSON(dict)
        
        for object in objects {
            if (object.value == jsonObj) {
                _logger.xcodeManagerPrintLog("Current object already exists.")
                return
            }
        }
        
        let PBXFileReferenceUUID = generateUUID()
        objects[PBXFileReferenceUUID] = jsonObj
        
        let PBXBuildFileUUID = generateUUID()
        var dict2 = Dictionary<String, Any>()
        dict2["fileRef"] = PBXFileReferenceUUID
        dict2["isa"] = "PBXBuildFile"
        dict2["settings"] = ["ATTRIBUTES": ["Required"]] // Required OR Weak
        objects[PBXBuildFileUUID] = JSON(dict2)
        
        for object in objects {
            if var obj = object.value.dictionaryObject {
                if (obj["isa"] as? String == "PBXFrameworksBuildPhase") {
                    var files = obj["files"] as? Array<String> ?? Array()
                    files.append(PBXBuildFileUUID)
                    obj["files"] = files
                    objects[object.key] = JSON(obj)
                }
            }
        }
        self._cacheProjet["objects"] = JSON(objects)
        
        let newPath = staticLibraryFilePath.replacingOccurrences(of: staticLibraryFilePath.split(separator: "/").last ?? "", with: "")
        self.setLibrarySearchPathValue(newPath)
    }
    
    
    /// Remove a static library
    ///
    /// - Parameter staticLibraryFilePath: static library file path
    public mutating func unlinkStaticLibrary(_ staticLibraryFilePath: String) {
        assert(!self._cacheProjet.isEmpty, "Uninitialized!")
        assert(!staticLibraryFilePath.isEmpty, "Invalid parameters!")
        
        var objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        assert(!objects.isEmpty, "Objects parsed error!")
        
        var dict = Dictionary<String, Any>()
        dict["isa"] = "PBXFileReference"
        dict["lastKnownFileType"] = "archive.ar"
        dict["sourceTree"] = "<group>"
        dict["name"] = staticLibraryFilePath.split(separator: "/").last ?? staticLibraryFilePath
        dict["path"] = staticLibraryFilePath
        let jsonObj = JSON(dict)
        
        var uuid = String()
        for (key, value) in objects {
            if (value == jsonObj) {
                if let _ = objects.removeValue(forKey: key) {
                    uuid = key
                }
                break
            }
        }
        
        if (uuid.isEmpty) {
            _logger.xcodeManagerPrintLog("uuid is empty!", type: .error)
            return
        }
        
        // 检索"PBXFrameworksBuildPhase"
        for (key, value) in objects {
            if var obj = value.dictionaryObject {
                if let isa = obj["isa"] as? String {
                    
                    if (isa == "PBXBuildFile") {
                        if let fileRef = obj["fileRef"] as? String {
                            if (fileRef == uuid) {
                                // 找到指针树,移除并回写
                                if let _ = objects.removeValue(forKey: key) {
                                    self._cacheProjet["objects"] = JSON(objects)
                                }
                            }
                        }
                    }
                    
                    if (isa == "PBXFrameworksBuildPhase") {
                        if let fileUuids = obj["files"] as? Array<String> {
                            obj["files"] = fileUuids.filter{ $0 != uuid }
                            // 移除完毕, 开始回写缓存
                            objects[key] = JSON(obj)
                            self._cacheProjet["objects"] = JSON(objects)
                        }
                    }
                    /// !!! 注意:此处未删除LIBRARY_SEARCH_PATHS中的任何值,因为可能会有其他库文件在使用
                    /// !!! LIBRARY_SEARCH_PATHS中即使没有库在使用留着也无关紧要
                }
            }
        }
    }
    
    
    /// Remove framework to project
    ///
    /// - Parameter frameworkFilePath: framework path
    public mutating func unlinkFramework(_ frameworkFilePath: String) {
        assert(!self._cacheProjet.isEmpty, "Uninitialized!")
        assert(!frameworkFilePath.isEmpty, "Invalid parameters!")
        
        var objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        assert(!objects.isEmpty, "Objects parsed error!")
        
        var dict = Dictionary<String, Any>()
        dict["isa"] = "PBXFileReference"
        dict["lastKnownFileType"] = "wrapper.framework"
        dict["sourceTree"] = "<group>"
        dict["name"] = frameworkFilePath.split(separator: "/").last ?? frameworkFilePath
        dict["path"] = frameworkFilePath
        let jsonObj = JSON(dict)
        
        var uuid = String()
        for (key, value) in objects {
            if (value == jsonObj) {
                if let _ = objects.removeValue(forKey: key) {
                    uuid = key
                }
                break
            }
        }
        
        if (uuid.isEmpty) {
            _logger.xcodeManagerPrintLog("uuid is empty!", type: .error)
            return
        }
        
        // 检索"PBXFrameworksBuildPhase"
        for (key, value) in objects {
            var obj = value.dictionaryObject ?? Dictionary()
            if (obj.isEmpty) {
                continue
            }
            let isa = obj["isa"] as? String ?? String()
            if (isa.isEmpty) {
                continue
            }
            if (isa == "PBXBuildFile") {
                let fileRef = obj["fileRef"] as? String ?? String()
                if (fileRef == uuid) {
                    // 找到指针树,移除并回写
                    if let _ = objects.removeValue(forKey: key) {
                        self._cacheProjet["objects"] = JSON(objects)
                    }
                }
            }
            
            if (isa == "PBXFrameworksBuildPhase") {
                let fileUuids = obj["files"] as? Array<String> ?? Array()
                if (fileUuids.isEmpty) {
                    _logger.xcodeManagerPrintLog("`files` parse error!", type: .error)
                    continue
                }
                
                obj["files"] = fileUuids.filter{ $0 != uuid }
                // 移除完毕, 开始回写缓存
                objects[key] = JSON(obj)
                self._cacheProjet["objects"] = JSON(objects)
            }
        }
        /// !!! 注意:此处未删除FRAMEWORK_SEARCH_PATHS中的任何值,因为可能会有其他库文件在使用
        /// !!! FRAMEWORK_SEARCH_PATHS中即使没有库在使用留着也无关紧要
    }
    
    /// Add folder to project
    ///
    /// - Parameter folderPath: folder path
    public mutating func addFolder(_ folderPath: String) {
        assert(!self._cacheProjet.isEmpty, "Uninitialized!")
        assert(!folderPath.isEmpty && FileManager.default.fileExists(atPath: folderPath), "Invalid parameters!")
        
        var objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        assert(!objects.isEmpty, "Objects parsed error!")
        
        var dict = Dictionary<String, Any>()
        dict["isa"] = "PBXFileReference"
        dict["lastKnownFileType"] = "folder"
        dict["sourceTree"] = "<group>"
        dict["name"] = folderPath.split(separator: "/").last ?? folderPath
        dict["path"] = folderPath
        let jsonObj = JSON(dict)
        
        for object in objects {
            if (object.value == jsonObj) {
                _logger.xcodeManagerPrintLog("Current object already exists.")
                return
            }
        }
        
        let PBXFileReferenceUUID = generateUUID()
        objects[PBXFileReferenceUUID] = jsonObj
        
        let PBXBuildFileUUID = generateUUID()
        var dict2 = Dictionary<String, Any>()
        dict2["fileRef"] = PBXFileReferenceUUID
        dict2["isa"] = "PBXBuildFile"
        objects[PBXBuildFileUUID] = JSON(dict2)
        
        for object in objects {
            var obj = object.value.dictionaryObject ?? Dictionary()
            if (!obj.isEmpty && obj["isa"] as? String == "PBXResourcesBuildPhase") {
                var files = obj["files"] as? Array<String> ?? Array()
                files.append(PBXBuildFileUUID)
                obj["files"] = files
                objects[object.key] = JSON(obj)
            }
        }
        self._cacheProjet["objects"] = JSON(objects)
    }
    
    
    /// Add resources file to Project (Copy Bundle Rsources)
    ///
    /// - Parameter filePath: resources file
    public mutating func addFile(_ filePath: String) {
        assert(!self._cacheProjet.isEmpty, "Uninitialized!")
        assert(!filePath.isEmpty && FileManager.default.fileExists(atPath: filePath), "Invalid parameters!")
        
        var objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        assert(!objects.isEmpty, "Objects parsed error!")
        
        var dict = Dictionary<String, Any>()
        dict["isa"] = "PBXFileReference"
        dict["lastKnownFileType"] = XcodeManagerFile().detectionType(path: filePath)
        dict["sourceTree"] = "<group>"
        dict["name"] = filePath.split(separator: "/").last ?? filePath
        dict["path"] = filePath
        let jsonObj = JSON(dict)
        
        for object in objects {
            if (object.value == jsonObj) {
                _logger.xcodeManagerPrintLog("Current object already exists.")
                return
            }
        }
        
        let PBXFileReferenceUUID = generateUUID()
        objects[PBXFileReferenceUUID] = jsonObj
        
        let PBXBuildFileUUID = generateUUID()
        var dict2 = Dictionary<String, Any>()
        dict2["fileRef"] = PBXFileReferenceUUID
        dict2["isa"] = "PBXBuildFile"
        objects[PBXBuildFileUUID] = JSON(dict2)
        
        for object in objects {
            var obj = object.value.dictionaryObject ?? Dictionary()
            if (!obj.isEmpty && obj["isa"] as? String == "PBXResourcesBuildPhase") {
                var files = obj["files"] as? Array<String> ?? Array()
                files.append(PBXBuildFileUUID)
                obj["files"] = files
                objects[object.key] = JSON(obj)
            }
        }
        self._cacheProjet["objects"] = JSON(objects)
    }
    
    
    /// Add FrameworkSearchPath Value
    ///
    /// - Parameter newPath: path
    public mutating func setFrameworkSearchPathValue(_ newPath: String) {
        assert(!self._cacheProjet.isEmpty, "Uninitialized!")
        assert(!newPath.isEmpty, "Invalid parameters!")
        
        let objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        assert(!objects.isEmpty, "Objects parsed error!")
        
        objectsFor:
            for element in objects {
                var dict = element.value
                if let isa = dict["isa"].string {
                    if (isa != "XCBuildConfiguration") {
                        continue
                    }
                    var buildSettings = dict["buildSettings"].dictionary ?? Dictionary<String, JSON>()
                    if (buildSettings.isEmpty) {
                        continue
                    }
                    
                    let frameworkSearchPaths = buildSettings["FRAMEWORK_SEARCH_PATHS"]
                    let varType = frameworkSearchPaths?.type ?? Type.unknown
                    switch varType {
                    case .string:
                        let string = frameworkSearchPaths?.string ?? String()
                        if (newPath == string) {
                            _logger.xcodeManagerPrintLog("Current object already exists.")
                            return
                        }
                        var newArray = Array<String>()
                        newArray.append(string)
                        newArray.append(newPath)
                        
                        buildSettings["FRAMEWORK_SEARCH_PATHS"] = JSON(newArray)
                        dict["buildSettings"] = JSON(buildSettings)
                        self._cacheProjet["objects"][element.key] = dict
                        break
                    case .array:
                        var newArray = frameworkSearchPaths?.array ?? Array()
                        
                        for ele in newArray {
                            let str = ele.string ?? String()
                            if (str == newPath) {
                                break objectsFor
                            }
                        }
                        
                        newArray.append(JSON(newPath))
                        
                        buildSettings["FRAMEWORK_SEARCH_PATHS"] = JSON(newArray)
                        dict["buildSettings"] = JSON(buildSettings)
                        self._cacheProjet["objects"][element.key] = dict
                        break
                    default:
                        var newArray = Array<String>()
                        newArray.append("$(inherited)")
                        newArray.append(newPath)
                        
                        buildSettings["FRAMEWORK_SEARCH_PATHS"] = JSON(newArray)
                        dict["buildSettings"] = JSON(buildSettings)
                        self._cacheProjet["objects"][element.key] = dict
                        break
                    }
                }
        }
    }
    
    
    /// Add LibrarySearchPath Value
    ///
    /// - Parameter newPath: path
    public mutating func setLibrarySearchPathValue(_ newPath: String) {
        assert(!self._cacheProjet.isEmpty, "Uninitialized!")
        assert(!newPath.isEmpty, "Invalid parameters!")
        
        let objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        assert(!objects.isEmpty, "Objects parsed error!")
        
        objectsFor:
            for element in objects {
                var dict = element.value
                if let isa = dict["isa"].string {
                    if (isa != "XCBuildConfiguration") {
                        continue
                    }
                    
                    var buildSettings = dict["buildSettings"].dictionary ?? Dictionary<String, JSON>()
                    if (buildSettings.isEmpty) {
                        continue
                    }
                    
                    let librarySearchPaths = buildSettings["LIBRARY_SEARCH_PATHS"]
                    let varType = librarySearchPaths?.type ?? Type.unknown
                    switch varType {
                    case .string:
                        let string = librarySearchPaths?.string ?? String()
                        if (newPath == string) {
                            _logger.xcodeManagerPrintLog("Current object already exists.")
                            return
                        }
                        var newArray = Array<String>()
                        newArray.append(string)
                        newArray.append(newPath)
                        
                        buildSettings["LIBRARY_SEARCH_PATHS"] = JSON(newArray)
                        dict["buildSettings"] = JSON(buildSettings)
                        self._cacheProjet["objects"][element.key] = dict
                        break
                    case .array:
                        var newArray = librarySearchPaths?.array ?? Array()
                        
                        for ele in newArray {
                            let str = ele.string ?? String()
                            if (str == newPath) {
                                break objectsFor
                            }
                        }
                        
                        newArray.append(JSON(newPath))
                        
                        buildSettings["LIBRARY_SEARCH_PATHS"] = JSON(newArray)
                        dict["buildSettings"] = JSON(buildSettings)
                        self._cacheProjet["objects"][element.key] = dict
                        break
                    default:
                        var newArray = Array<String>()
                        newArray.append("$(inherited)")
                        newArray.append(newPath)
                        
                        buildSettings["LIBRARY_SEARCH_PATHS"] = JSON(newArray)
                        dict["buildSettings"] = JSON(buildSettings)
                        self._cacheProjet["objects"][element.key] = dict
                        break
                    }
                }
        }
    }
    
    /// Remove FrameworkSearchPath Value
    ///
    /// - Parameter removePath: path
    public mutating func removeFrameworkSearchPathValue(_ removePath: String) {
        assert(!self._cacheProjet.isEmpty, "Uninitialized!")
        assert(!removePath.isEmpty, "Invalid parameters!")
        
        let objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        assert(!objects.isEmpty, "Objects parsed error!")
        
        for element in objects {
            var dict = element.value
            if let isa = dict["isa"].string {
                if (isa != "XCBuildConfiguration") {
                    continue
                }
                
                var buildSettings = dict["buildSettings"].dictionary ?? Dictionary<String, JSON>()
                if (buildSettings.isEmpty) {
                    continue
                }
                
                let framework_search_paths = buildSettings["FRAMEWORK_SEARCH_PATHS"]
                let varType = framework_search_paths?.type ?? Type.unknown
                switch varType {
                case .string:
                    let string = framework_search_paths?.string ?? String()
                    if (removePath == string) {
                        var newArray = Array<String>()
                        newArray.append("$(inherited)")
                        buildSettings["FRAMEWORK_SEARCH_PATHS"] = JSON(newArray)
                        dict["buildSettings"] = JSON(buildSettings)
                        self._cacheProjet["objects"][element.key] = dict
                    }
                    break
                case .array:
                    let newArray = framework_search_paths?.array ?? Array()
                    let array = newArray.filter { $0.stringValue != removePath }
                    buildSettings["FRAMEWORK_SEARCH_PATHS"] = JSON(array)
                    dict["buildSettings"] = JSON(buildSettings)
                    self._cacheProjet["objects"][element.key] = dict
                    break
                default:
                    let newArray = ["$(inherited)"]
                    buildSettings["FRAMEWORK_SEARCH_PATHS"] = JSON(newArray)
                    dict["buildSettings"] = JSON(buildSettings)
                    self._cacheProjet["objects"][element.key] = dict
                    break
                }
            }
        }
    }
    
    /// Remove LibrarySearchPath Value
    ///
    /// - Parameter removePath: path
    public mutating func removeLibrarySearchPathValue(_ removePath: String) {
        assert(!self._cacheProjet.isEmpty, "Uninitialized!")
        assert(!removePath.isEmpty, "Invalid parameters!")
        
        let objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        assert(!objects.isEmpty, "Objects parsed error!")
        
        for element in objects {
            var dict = element.value
            if let isa = dict["isa"].string {
                if (isa != "XCBuildConfiguration") {
                    continue
                }
                
                var buildSettings = dict["buildSettings"].dictionary ?? Dictionary<String, JSON>()
                if (buildSettings.isEmpty) {
                    continue
                }
                
                let librarySearchPaths = buildSettings["LIBRARY_SEARCH_PATHS"]
                let varType = librarySearchPaths?.type ?? Type.unknown
                switch varType {
                case .string:
                    let string = librarySearchPaths?.string ?? String()
                    if (removePath == string) {
                        buildSettings["LIBRARY_SEARCH_PATHS"] = JSON(["$(inherited)"])
                        dict["buildSettings"] = JSON(buildSettings)
                        self._cacheProjet["objects"][element.key] = dict
                    }
                    break
                case .array:
                    let newArray = librarySearchPaths?.array ?? Array()
                    let array = newArray.filter { $0.stringValue != removePath }
                    buildSettings["LIBRARY_SEARCH_PATHS"] = JSON(array)
                    dict["buildSettings"] = JSON(buildSettings)
                    self._cacheProjet["objects"][element.key] = dict
                    break
                default:
                    let newArray = ["$(inherited)"]
                    buildSettings["LIBRARY_SEARCH_PATHS"] = JSON(newArray)
                    dict["buildSettings"] = JSON(buildSettings)
                    self._cacheProjet["objects"][element.key] = dict
                    break
                }
            }
        }
    }
    
    /// Update Product Name
    ///
    /// - Parameter productName: productName
    public mutating func setProductName(_ productName: String) {
        assert(!self._cacheProjet.isEmpty, "Uninitialized!")
        assert(!productName.isEmpty, "Invalid parameters!")
        
        let objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        assert(!objects.isEmpty, "Objects parsed error!")
        for element in objects {
            var dict = element.value
            if let isa = dict["isa"].string {
                if (isa == "XCBuildConfiguration") {
                    var buildSettings = dict["buildSettings"].dictionary ?? Dictionary<String, JSON>()
                    let originalProductName = buildSettings["PRODUCT_NAME"]?.string ?? String()
                    if (!originalProductName.isEmpty) {
                        buildSettings["PRODUCT_NAME"] = JSON(productName)
                        dict["buildSettings"] = JSON(buildSettings)
                        self._cacheProjet["objects"][element.key] = JSON(dict)
                    }
                }
            }
        }
    }
    
    /// Update project's bundleid
    ///
    /// - Parameter bundleid: bundleid, eg: cn.zhengshoudong.xxx
    public mutating func setBundleId(_ bundleId: String) {
        assert(!self._cacheProjet.isEmpty, "Uninitialized!")
        assert(!bundleId.isEmpty, "Invalid parameters!")
        
        let objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        assert(!objects.isEmpty, "Objects parsed error!")
        for element in objects {
            var dict = element.value
            if let isa = dict["isa"].string {
                if (isa == "XCBuildConfiguration") {
                    var buildSettings = dict["buildSettings"].dictionary ?? Dictionary<String, JSON>()
                    let productBundleIdentifier = buildSettings["PRODUCT_BUNDLE_IDENTIFIER"]?.string ?? String()
                    if (!productBundleIdentifier.isEmpty) {
                        buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] = JSON(bundleId)
                        dict["buildSettings"] = JSON(buildSettings)
                        self._cacheProjet["objects"][element.key] = JSON(dict)
                    }
                }
            }
        }
    }
    
    /// Update project's codeSign style
    ///
    /// - Parameter type: enum CodeSignStyleType
    public mutating func setCodeSignStyle(type: CodeSignStyleType) {
        assert(!self._cacheProjet.isEmpty, "Uninitialized!")
        
        var objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        assert(!objects.isEmpty, "Objects parsed error!")
        
        for (key, value) in objects {
            if let isa = value["isa"].string {
                if (isa == "XCBuildConfiguration") {
                    var dict = value
                    var buildSettings = dict["buildSettings"].dictionary ?? Dictionary<String, JSON>()
                    let codeSignStyle = buildSettings["CODE_SIGN_STYLE"]?.string ?? String()
                    if (!codeSignStyle.isEmpty) {
                        buildSettings["CODE_SIGN_STYLE"] = JSON(type.rawValue)
                        dict["buildSettings"] = JSON(buildSettings)
                        objects[key] = JSON(dict)
                    }
                }
            }
        }
        
        let rootObj = objects[self._rootObjectUUID]?.dictionary ?? Dictionary<String, JSON>()
        var attributes = rootObj["attributes"]?.dictionary ?? Dictionary<String, JSON>()
        var targetAttributes = attributes["TargetAttributes"]?.dictionary ?? Dictionary<String, JSON>()
        var newTargetAttributes = Dictionary<String, JSON>()
        
        for attribute in targetAttributes {
            var singleAttribute = targetAttributes[attribute.key]?.dictionary ?? Dictionary<String, JSON>()
            for att in singleAttribute {
                if (att.key == "ProvisioningStyle") {
                    singleAttribute[att.key] = JSON(type.rawValue)
                    newTargetAttributes[attribute.key] = JSON(singleAttribute)
                }
            }
        }
        
        if (!newTargetAttributes.isEmpty) {
            objects[self._rootObjectUUID]!["attributes"]["TargetAttributes"] = JSON(newTargetAttributes)
        }
        
        self._cacheProjet["objects"] = JSON(objects)
    }
    
    /// Get project bundleid
    ///
    /// - Returns: return bundleid. (If has error, will return empty string.)
    public func getBundleId() -> String {
        assert(!self._cacheProjet.isEmpty, "Uninitialized!")
        
        let objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        assert(!objects.isEmpty, "Objects parsed error!")
        for (_, value) in objects {
            if let isa = value["isa"].string {
                if (isa == "XCBuildConfiguration") {
                    let buildSettings = value["buildSettings"].dictionary ?? Dictionary<String, JSON>()
                    let productBundleIdentifier = buildSettings["PRODUCT_BUNDLE_IDENTIFIER"]?.string ?? String()
                    if (!productBundleIdentifier.isEmpty) {
                        return productBundleIdentifier
                    }
                }
            }
        }
        return String()
    }
    
    /// Get product name
    ///
    /// - Returns: current product name.(If has error, will return empty string)
    public func getProductName() -> String {
        assert(!self._cacheProjet.isEmpty, "Uninitialized!")
        
        let objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        assert(!objects.isEmpty, "Objects parsed error!")
        for (_, value) in objects {
            if let isa = value["isa"].string {
                if (isa == "XCBuildConfiguration") {
                    let buildSettings = value["buildSettings"].dictionary ?? Dictionary<String, JSON>()
                    let productName = buildSettings["PRODUCT_NAME"]?.string ?? String()
                    if (!productName.isEmpty) {
                        return productName
                    }
                }
            }
        }
        return String()
    }
    
    /// Save the project to file
    ///
    /// - Returns: Saved the result
    public func save() throws -> Bool {
        assert(!self._cacheProjet.isEmpty, "Uninitialized!")
        
        let dict = _cacheProjet.dictionaryObject ?? Dictionary()
        if (dict.isEmpty) {
            _logger.xcodeManagerPrintLog("Save failed!", type: .error)
            throw XcodeManagerError.saveFailed(code: .parsedError, reason: "dictionaryObject is empty!")
        }
        
        var fileUrl = URL(fileURLWithPath: _filePath)
        if fileUrl.pathExtension == "xcodeproj" {
            fileUrl.appendPathComponent("project.pbxproj")
        }
        
        return self.saveProject(fileURL: fileUrl, withPropertyList: dict)
    }
    
}

extension Dictionary {
    fileprivate func isEqualTo(dict:[String: Any]) -> Bool {
        return NSDictionary(dictionary: self).isEqual(to: dict)
    }
}
