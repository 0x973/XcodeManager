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
    
    /// cache in memory
    fileprivate var _cacheProjet: JSON = JSON()
    fileprivate var _hashTag: Int = Int()
    fileprivate var _filePath: String = String()
    
    /// main group UUID
    fileprivate var _mainGroupUUID: String = String()
    /// root object uuid in root node
    fileprivate var _rootObjectUUID: String = String()
    /// current project name
    fileprivate var _currentProjectName: String = String()
    
    fileprivate var _isPrintLog = true
    
    public enum CodeSignStyleType: String{
        public typealias RawValue = String
        case automatic = "Automatic"
        case manual = "Manual"
    }
    
    fileprivate enum XcodeManagerLogType: String {
        case debug = "XcodeManagerDebug"
        case info = "XcodeManagerInfo"
        case error = "XcodeManagerError"
    }
    
    fileprivate enum XcodeManagerError: Error {
        case invalidParameter(code: Int, reason: String)
        case failedInitialized(code :Int, reason: String)
    }
    
    public init(projectFile: String, printLog: Bool = true) throws {
        self._filePath = projectFile
        self._isPrintLog = printLog
        do {
            _ = try self.parseProject(self._filePath)
        }catch {
            throw error
        }
    }
    
    /// parseProjectFile
    fileprivate mutating func parseProject(_ filePath: String) throws -> JSON {
        if (!FileManager.default.fileExists(atPath: filePath)) {
            xcodeManagerPrintLog("Please check the parameters!", type: .error)
            throw XcodeManagerError.invalidParameter(code: 600, reason: "the file not found!")
        }
        
        var fileUrl = URL(fileURLWithPath: filePath)
        if fileUrl.pathExtension == "xcodeproj" {
            fileUrl.appendPathComponent("project.pbxproj")
        }
        
        do {
            let fileData = try Data(contentsOf: fileUrl)
            
            let hashValue = fileData.hashValue
            if (self._hashTag == hashValue && !self._cacheProjet.isEmpty) {
                return self._cacheProjet
            }
            
            self._filePath = filePath
            self._hashTag = hashValue
            
            let data = try PropertyListSerialization.propertyList(from: fileData, options: .mutableContainersAndLeaves, format: nil)
            self._cacheProjet = JSON(data)
            self._rootObjectUUID = self._cacheProjet["rootObject"].stringValue
            let obj = self._cacheProjet["objects"]
            self._mainGroupUUID = obj[self._rootObjectUUID]["mainGroup"].stringValue
            for ele in obj {
                let valueObj = ele.1
                if (!valueObj.isEmpty) {
                    if (valueObj["isa"].stringValue == "PBXNativeTarget" &&
                        valueObj["productType"].stringValue == "com.apple.product-type.application") {
                        let name = valueObj["name"].stringValue
                        _currentProjectName = name
                        break
                    }
                }
            }
            return self._cacheProjet
        } catch {
            xcodeManagerPrintLog("read project file failed. error: \(error.localizedDescription)", type: .error)
            throw XcodeManagerError.failedInitialized(code: 601, reason: "read project file failed")
        }
    }
    
    
    /// 将数据内容生成为工程文件,反存储
    fileprivate func saveProject(fileURL: URL, withPropertyList list: Any) -> Bool{
        let url = fileURL
        
        func handleEncode(fileURL: URL) -> Bool {
            func encodeString(_ str: String) -> String {
                var result = String()
                for scalar in str.unicodeScalars {
                    if scalar.value > 0x4e00 && scalar.value < 0x9fff {
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
                xcodeManagerPrintLog("translate chinese characters to mathematical symbols error: \(error.localizedDescription)", type: .error)
                return false
            }
        }
        
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: list, format: .xml, options: 0)
            try data.write(to: url, options: .atomic)
            return handleEncode(fileURL: url)
        } catch {
            xcodeManagerPrintLog("save project file failed: \(error.localizedDescription)", type: .error)
            return false
        }
    }
    
    
    /// get all objects uuids
    fileprivate func allUuids(_ projectDict: JSON) -> Array<String> {
        let objects = projectDict["objects"].dictionaryObject ?? Dictionary()
        
        var uuids = Array<String>()
        
        for obj in objects {
            uuids.append(obj.key)
        }
        
        uuids = uuids.filter({
            $0.lengthOfBytes(using: .utf8) == 24
        })
        
        return uuids
    }
    
    
    /// generate new uuid (not repeat)
    fileprivate func generateUuid() -> String {
        if (self._cacheProjet.isEmpty) {
            // cache empty!
            xcodeManagerPrintLog("Please use the 'init()' initialize!", type: .error)
            return String()
        }
        
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "").suffix(24).uppercased()
        let array = self.allUuids(self._cacheProjet)
        if (array.index(of: uuid) ?? -1 >= 0) {
            return generateUuid()
        }
        return uuid
    }
    
    
    /// in project root node generate the 'PBX' group, mount and write in memory cache
    ///
    /// - Parameter name: needed generate the 'PBX' group
    /// - Returns: return a new uuid with added 'PBX' group
    fileprivate mutating func generatePBXGroup(name: String) -> String {
        if (name.isEmpty) {
            xcodeManagerPrintLog("Please check the parameters!", type: .error)
            return String()
        }
        let newUUID = self.generateUuid()
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
        if (mainGroupObjChildren.isEmpty) {
            xcodeManagerPrintLog("Parsed mainGroup object wrong!", type: .error)
            return String()
        }
        
        mainGroupObjChildren.append(newUUID)
        mainGroupObj["children"] = JSON(mainGroupObjChildren)
        self._cacheProjet["objects"][self._mainGroupUUID] = mainGroupObj
        
        return newUUID
    }
    
    /// detection file type
    fileprivate mutating func detectLastType(path: String) -> String {
        if (path.isEmpty) {
            return "unknown"
        }
        
        let fileURL = URL(fileURLWithPath: path)
        if (!fileURL.isFileURL) {
            return "unknown"
        }
        
        let filePathExtension = fileURL.pathExtension
        if (filePathExtension.isEmpty) {
            return "unknown"
        }
        
        switch filePathExtension {
        case "a" :
            return "archive.ar"
        case "framework" :
            return "wrapper.framework"
        case "xib" :
            return "file.xib"
        case "plist" :
            return "text.plist.xml"
        case "bundle" :
            return "wrapper.plug-in"
        case "js" :
            return "sourcecode.javascript"
        case "html" :
            return "sourcecode.html"
        case "json" :
            return "sourcecode.json"
        case "xml" :
            return "sourcecode.xml"
        case "png" :
            return "image.png"
        case "txt" :
            return "text"
        case "xcconfig" :
            return "text.xcconfig"
        case "markdown" :
            return "text"
        case "tbd" :
            return "sourcecode.text-based-dylib-definition"
        case "sh" :
            return "text.script.sh"
        case "pch" :
            return "sourcecode.c.h"
        case "xcdatamodel" :
            return "wrapper.xcdatamodel"
        case "m" :
            return "sourcecode.c.objc"
        case "h" :
            return "sourcecode.c.h"
        case "swift" :
            return "sourcecode.swift"
        case "storyboard" :
            return "file.storyboard"
        case "dylib" :
            return "compiled.mach-o.dylib"
        case "jpg", "jpeg" :
            return "image.jpg"
        case "mp4" :
            return "video.mp4"
        case "app" :
            return "wrapper.application"
        case "xcassets" :
            return "folder.assetcatalog"
        default :
            return "unknown"
        }
    }
    
    
    /// Add static library to project
    ///
    /// - Parameter staticLibraryFilePath: static lib file path
    public mutating func addStaticLibraryToProject(_ staticLibraryFilePath: String) {
        if (self._cacheProjet.isEmpty) {
            xcodeManagerPrintLog("Please use the 'init()' initialize!", type: .error)
            return
        }
        
        if (staticLibraryFilePath.isEmpty || !FileManager.default.fileExists(atPath: staticLibraryFilePath)) {
            xcodeManagerPrintLog("Please check the parameters!", type: .error)
            return
        }
        
        let PBXFileReferenceUUID = generateUuid()
        var dict = Dictionary<String, Any>()
        dict["isa"] = "PBXFileReference"
        dict["lastKnownFileType"] = "archive.ar"
        dict["sourceTree"] = "<group>"
        dict["name"] = staticLibraryFilePath.split(separator: "/").last ?? staticLibraryFilePath
        dict["path"] = staticLibraryFilePath
        
        var objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        if (objects.isEmpty) {
            xcodeManagerPrintLog("Parsed objects wrong!", type: .error)
            return
        }
        
        /// 比较是否和当前工程中的obj一致
        for object in objects {
            if (object.value.dictionaryValue.isEqualTo(dict: dict)) {
                xcodeManagerPrintLog("current object is existing")
                return
            }
        }
        
        // 单个.a文件单元添加
        objects[PBXFileReferenceUUID] = JSON(dict)
        
        // 作为库引用的指针树
        let PBXBuildFileUUID = generateUuid()
        var dict2 = Dictionary<String, Any>()
        dict2["fileRef"] = PBXFileReferenceUUID
        dict2["isa"] = "PBXBuildFile"
        dict["settings"] = ["ATTRIBUTES": ["Required"]]  // Required OR Weak
        /// 写入缓存BuildFile的缓存
        objects[PBXBuildFileUUID] = JSON(dict2)
        
        /// 检索"PBXFrameworksBuildPhase"
        for object in objects {
            var obj = object.value.dictionaryObject ?? Dictionary()
            
            if (!obj.isEmpty) {
                if obj["isa"] as? String == "PBXFrameworksBuildPhase" {
                    var files = obj["files"] as? Array<String> ?? Array()
                    files.append(PBXBuildFileUUID)
                    obj["files"] = files
                    /// 写入缓存PBXFrameworksBuildPhase的缓存
                    objects[object.key] = JSON(obj)
                }
            }
        }
        // 回写缓存
        self._cacheProjet["objects"] = JSON(objects)
        
        // 写入当前的路径到LibrarySearchPath
        let newPath = staticLibraryFilePath.replacingOccurrences(of: staticLibraryFilePath.split(separator: "/").last ?? "", with: "")
        self.addNewLibrarySearchPathValue(newPath)
    }
    
    
    /// Add framework to project
    ///
    /// - Parameter frameworkFilePath: framework path
    public mutating func addFrameworkToProject(_ frameworkFilePath: String) {
        if (self._cacheProjet.isEmpty) {
            xcodeManagerPrintLog("Please use the 'init()' initialize!", type: .error)
            return
        }
        
        if (frameworkFilePath.isEmpty || !FileManager.default.fileExists(atPath: frameworkFilePath)) {
            xcodeManagerPrintLog("Please check the parameters!", type: .error)
            return
        }
        
        let PBXFileReferenceUUID = generateUuid()
        var dict = Dictionary<String, Any>()
        dict["isa"] = "PBXFileReference"
        dict["lastKnownFileType"] = "wrapper.framework"
        dict["sourceTree"] = "<group>"
        dict["name"] = frameworkFilePath.split(separator: "/").last ?? frameworkFilePath
        dict["path"] = frameworkFilePath
        
        var objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        if (objects.isEmpty) {
            xcodeManagerPrintLog("Parsed objects wrong!", type: .error)
            return
        }
        
        for object in objects {
            if (object.value.dictionaryValue.isEqualTo(dict: dict)) {
                xcodeManagerPrintLog("current object is existing")
                return
            }
        }
        
        // 单个单元添加
        objects[PBXFileReferenceUUID] = JSON(dict)
        
        // 作为库引用的指针树
        let PBXBuildFileUUID = generateUuid()
        var dict2 = Dictionary<String, Any>()
        dict2["fileRef"] = PBXFileReferenceUUID
        dict2["isa"] = "PBXBuildFile"
        dict["settings"] = ["ATTRIBUTES": ["Required"]] // Required OR Weak
        /// 写入缓存BuildFile的缓存
        objects[PBXBuildFileUUID] = JSON(dict2)
        
        /// 检索"PBXFrameworksBuildPhase"
        for object in objects {
            var obj = object.value.dictionaryObject ?? Dictionary()
            
            if (!obj.isEmpty) {
                if obj["isa"] as? String == "PBXFrameworksBuildPhase" {
                    var files = obj["files"] as? Array<String> ?? Array()
                    files.append(PBXBuildFileUUID)
                    obj["files"] = files
                    /// 写入缓存PBXFrameworksBuildPhase的缓存
                    objects[object.key] = JSON(obj)
                }
                
            }
        }
        // 回写缓存
        self._cacheProjet["objects"] = JSON(objects)
        
        // 写入当前的路径到FrameworkSearchPath
        let newPath = frameworkFilePath.replacingOccurrences(of: frameworkFilePath.split(separator: "/").last ?? "", with: "")
        self.addNewFrameworkSearchPathValue(newPath)
    }
    
    /// Add folder to project
    ///
    /// - Parameter folderPath: folder path
    public mutating func addFolderToProject(_ folderPath: String) {
        if (self._cacheProjet.isEmpty) {
            xcodeManagerPrintLog("Please use the 'init()' initialize!", type: .error)
            return
        }
        
        if (folderPath.isEmpty || !FileManager.default.fileExists(atPath: folderPath)) {
            xcodeManagerPrintLog("Please check the parameters!", type: .error)
            return
        }
        
        let PBXFileReferenceUUID = generateUuid()
        var dict = Dictionary<String, Any>()
        dict["isa"] = "PBXFileReference"
        dict["lastKnownFileType"] = "folder"
        dict["sourceTree"] = "<group>"
        dict["name"] = folderPath.split(separator: "/").last ?? folderPath
        dict["path"] = folderPath
        
        var objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        if (objects.isEmpty) {
            xcodeManagerPrintLog("Parsed objects wrong!", type: .error)
            return
        }
        
        /// 比较是否和当前工程中的obj一致
        for object in objects {
            if (object.value.dictionaryValue.isEqualTo(dict: dict)) {
                xcodeManagerPrintLog("current object is existing")
                return
            }
        }
        
        // 添加引用单元
        objects[PBXFileReferenceUUID] = JSON(dict)
        
        // 作为库引用的指针树
        let PBXBuildFileUUID = generateUuid()
        var dict2 = Dictionary<String, Any>()
        dict2["fileRef"] = PBXFileReferenceUUID
        dict2["isa"] = "PBXBuildFile"
        /// 写入缓存BuildFile的缓存
        objects[PBXBuildFileUUID] = JSON(dict2)
        
        /// 检索"PBXResourcesBuildPhase"
        for object in objects {
            var obj = object.value.dictionaryObject ?? Dictionary()
            
            if (!obj.isEmpty) {
                if obj["isa"] as? String == "PBXResourcesBuildPhase" {
                    var files = obj["files"] as? Array<String> ?? Array()
                    files.append(PBXBuildFileUUID)
                    obj["files"] = files
                    /// 写入缓存PBXFrameworksBuildPhase的缓存
                    objects[object.key] = JSON(obj)
                }
            }
        }
        // 回写缓存
        self._cacheProjet["objects"] = JSON(objects)
    }
    
    
    /// Add resources file to Project (Copy Bundle Rsources)
    ///
    /// - Parameter filePath: resources file
    public mutating func addFileToProject(_ filePath: String) {
        if (self._cacheProjet.isEmpty) {
            xcodeManagerPrintLog("Please use the 'init()' initialize!", type: .error)
            return
        }
        
        if (filePath.isEmpty || !FileManager.default.fileExists(atPath: filePath)) {
            xcodeManagerPrintLog("Please check the parameters!", type: .error)
            return
        }
        
        let PBXFileReferenceUUID = generateUuid()
        var dict = Dictionary<String, Any>()
        dict["isa"] = "PBXFileReference"
        dict["lastKnownFileType"] = self.detectLastType(path: filePath)
        dict["sourceTree"] = "<group>"
        dict["name"] = filePath.split(separator: "/").last ?? filePath
        dict["path"] = filePath
        
        var objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        if (objects.isEmpty) {
            xcodeManagerPrintLog("Parsed objects wrong!", type: .error)
            return
        }
        
        /// 比较是否和当前工程中的obj一致
        for object in objects {
            if (object.value.dictionaryValue.isEqualTo(dict: dict)) {
                xcodeManagerPrintLog("current object is existing")
                return
            }
        }
        
        // 单个文件单元添加
        objects[PBXFileReferenceUUID] = JSON(dict)
        
        // 作为库引用的指针树
        let PBXBuildFileUUID = generateUuid()
        var dict2 = Dictionary<String, Any>()
        dict2["fileRef"] = PBXFileReferenceUUID
        dict2["isa"] = "PBXBuildFile"
        /// 写入缓存BuildFile的缓存
        objects[PBXBuildFileUUID] = JSON(dict2)
        
        /// 检索"PBXResourcesBuildPhase"
        for object in objects {
            var obj = object.value.dictionaryObject ?? Dictionary()
            
            if (!obj.isEmpty) {
                if obj["isa"] as? String == "PBXResourcesBuildPhase" {
                    var files = obj["files"] as? Array<String> ?? Array()
                    files.append(PBXBuildFileUUID)
                    obj["files"] = files
                    /// 写入缓存PBXFrameworksBuildPhase的缓存
                    objects[object.key] = JSON(obj)
                }
            }
        }
        // 回写缓存
        self._cacheProjet["objects"] = JSON(objects)
    }
    
    
    /// Add FrameworkSearchPath Value
    ///
    /// - Parameter newPath: path
    public mutating func addNewFrameworkSearchPathValue(_ newPath: String) {
        
        if (self._cacheProjet.isEmpty) {
            xcodeManagerPrintLog("Please use the 'init()' initialize!", type: .error)
            return
        }
        
        if (newPath.isEmpty) {
            xcodeManagerPrintLog("Please check the parameters!", type: .error)
            return
        }
        
        let objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        if (objects.isEmpty) {
            xcodeManagerPrintLog("Parsed objects wrong!", type: .error)
            return
        }
        
        for element in objects {
            var dict = element.value
            let isa = dict["isa"].string ?? String()
            if (isa == "XCBuildConfiguration") {
                var buildSettings = dict["buildSettings"].dictionary ?? Dictionary<String, JSON>()
                if (buildSettings.isEmpty) {
                    continue
                }
                
                let PRODUCT_NAME = buildSettings["PRODUCT_NAME"]?.string ?? String()
                let PRODUCT_BUNDLE_IDENTIFIER = buildSettings["PRODUCT_BUNDLE_IDENTIFIER"]?.string ?? String()
                if (PRODUCT_NAME.isEmpty && PRODUCT_BUNDLE_IDENTIFIER.isEmpty) {
                    continue
                }
                
                // 一下即可确认就是需要的那个object!
                let FRAMEWORK_SEARCH_PATHS = buildSettings["FRAMEWORK_SEARCH_PATHS"]
                let varType = FRAMEWORK_SEARCH_PATHS?.type ?? Type.unknown
                switch varType {
                case .string:
                    // 如果为字符串类型,说明当前有且只有一个value!
                    // 添加时候需要取出来然后变成数组放回去
                    let string = FRAMEWORK_SEARCH_PATHS?.string ?? String()
                    if (newPath == string) {
                        // 要添加的和已经存在的一致
                        xcodeManagerPrintLog("current object is existing", type: .info)
                        continue
                    }
                    var newArray = Array<String>()
                    newArray.append(string)
                    newArray.append(newPath)
                    
                    // 回写
                    buildSettings["FRAMEWORK_SEARCH_PATHS"] = JSON(newArray)
                    dict["buildSettings"] = JSON(buildSettings)
                    self._cacheProjet["objects"][element.key] = dict
                    
                    break
                case .array:
                    // 当前如果本身就是个数组,说明当前已经有多个值了,追加进去新的数值
                    var newArray = FRAMEWORK_SEARCH_PATHS?.array ?? Array()
                    
                    // 判断是否已经有相同value存在
                    var isExist = false
                    for ele in newArray {
                        let str = ele.string ?? String()
                        if (str == newPath) {
                            isExist = true
                        }
                    }
                    
                    if (isExist) {
                        continue
                    }
                    
                    newArray.append(JSON(newPath))
                    
                    // 回写
                    buildSettings["FRAMEWORK_SEARCH_PATHS"] = JSON(newArray)
                    dict["buildSettings"] = JSON(buildSettings)
                    self._cacheProjet["objects"][element.key] = dict
                    
                    break
                default:
                    // 不存在,创建并追加
                    var newArray = Array<String>()
                    newArray.append("$(inherited)")
                    newArray.append(newPath)
                    
                    // 回写
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
    public mutating func addNewLibrarySearchPathValue(_ newPath: String) {
        
        if (self._cacheProjet.isEmpty) {
            xcodeManagerPrintLog("Please use the 'init()' initialize!", type: .error)
            return
        }
        
        if (newPath.isEmpty) {
            xcodeManagerPrintLog("Please check the parameters!", type: .error)
            return
        }
        
        let objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        if (objects.isEmpty) {
            xcodeManagerPrintLog("Parsed objects wrong!", type: .error)
            return
        }
        
        for element in objects {
            var dict = element.value
            let isa = dict["isa"].string ?? String()
            if (isa == "XCBuildConfiguration") {
                var buildSettings = dict["buildSettings"].dictionary ?? Dictionary<String, JSON>()
                if (buildSettings.isEmpty) {
                    continue
                }
                
                let PRODUCT_NAME = buildSettings["PRODUCT_NAME"]?.string ?? String()
                let PRODUCT_BUNDLE_IDENTIFIER = buildSettings["PRODUCT_BUNDLE_IDENTIFIER"]?.string ?? String()
                if (PRODUCT_NAME.isEmpty && PRODUCT_BUNDLE_IDENTIFIER.isEmpty) {
                    continue
                }
                
                // 以下即可确认就是需要的那个object!
                let LIBRARY_SEARCH_PATHS = buildSettings["LIBRARY_SEARCH_PATHS"]
                let varType = LIBRARY_SEARCH_PATHS?.type ?? Type.unknown
                switch varType {
                case .string:
                    // 如果为字符串类型,说明当前有且只有一个value!
                    // 添加时候需要取出来然后变成数组放回去
                    let string = LIBRARY_SEARCH_PATHS?.string ?? String()
                    if (newPath == string) {
                        // 要添加的和已经存在的一致
                        xcodeManagerPrintLog("current object is existing", type: .info)
                        continue
                    }
                    var newArray = Array<String>()
                    newArray.append(string)
                    newArray.append(newPath)
                    
                    // 回写
                    buildSettings["LIBRARY_SEARCH_PATHS"] = JSON(newArray)
                    dict["buildSettings"] = JSON(buildSettings)
                    self._cacheProjet["objects"][element.key] = dict
                    break
                case .array:
                    // 当前如果本身就是个数组,说明当前已经有多个值了,追加进去新的数值
                    var newArray = LIBRARY_SEARCH_PATHS?.array ?? Array()
                    
                    // 判断是否已经有相同value存在
                    var isExist = false
                    for ele in newArray {
                        let str = ele.string ?? String()
                        if (str == newPath) {
                            isExist = true
                        }
                    }
                    
                    if (isExist) {
                        continue
                    }
                    
                    newArray.append(JSON(newPath))
                    
                    // 回写
                    buildSettings["LIBRARY_SEARCH_PATHS"] = JSON(newArray)
                    dict["buildSettings"] = JSON(buildSettings)
                    self._cacheProjet["objects"][element.key] = dict
                    break
                default:
                    // 不存在,创建并追加
                    var newArray = Array<String>()
                    newArray.append("$(inherited)")
                    newArray.append(newPath)
                    
                    // 回写
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
    public mutating func updateProductName(_ productName: String) {
        if (self._cacheProjet.isEmpty) {
            xcodeManagerPrintLog("Please use the 'init()' initialize!", type: .error)
            return
        }
        
        if (productName.isEmpty) {
            xcodeManagerPrintLog("Please check the parameters!", type: .error)
            return
        }
        let objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        for element in objects {
            var dict = element.value
            let isa = dict["isa"].string ?? String()
            if (isa == "XCBuildConfiguration") {
                var buildSettings = dict["buildSettings"].dictionary ?? Dictionary<String, JSON>()
                let PRODUCT_NAME = buildSettings["PRODUCT_NAME"]?.string ?? String()
                if (!PRODUCT_NAME.isEmpty) {
                    // 回写
                    buildSettings["PRODUCT_NAME"] = JSON(productName)
                    dict["buildSettings"] = JSON(buildSettings)
                    let uuidKey = element.key
                    
                    self._cacheProjet["objects"][uuidKey] = JSON(dict)
                }
            }
        }
    }
    
    /// Update project's bundleid
    ///
    /// - Parameter bundleid: bundleid, eg: com.zhengshoudong.xxx
    public mutating func updateBundleId(_ bundleid: String) {
        if (self._cacheProjet.isEmpty) {
            xcodeManagerPrintLog("Please use the 'init()' initialize!", type: .error)
            return
        }
        
        if (bundleid.isEmpty) {
            xcodeManagerPrintLog("Please check the parameters!", type: .error)
            return
        }
        let objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        for element in objects {
            var dict = element.value
            let isa = dict["isa"].string ?? String()
            if (isa == "XCBuildConfiguration") {
                var buildSettings = dict["buildSettings"].dictionary ?? Dictionary<String, JSON>()
                let PRODUCT_BUNDLE_IDENTIFIER = buildSettings["PRODUCT_BUNDLE_IDENTIFIER"]?.string ?? String()
                if (!PRODUCT_BUNDLE_IDENTIFIER.isEmpty) {
                    // 回写
                    buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] = JSON(bundleid)
                    dict["buildSettings"] = JSON(buildSettings)
                    let uuidKey = element.key
                    
                    self._cacheProjet["objects"][uuidKey] = JSON(dict)
                }
            }
        }
    }
    
    
    /// Update project's codeSign style
    ///
    /// - Parameter type: enum CodeSignStyleType
    public mutating func updateCodeSignStyle(type: CodeSignStyleType) {
        
        if (self._cacheProjet.isEmpty) {
            xcodeManagerPrintLog("Please use the 'init()' initialize!", type: .error)
            return
        }
        
        var objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        for element in objects {
            var dict = element.value
            let isa = dict["isa"].string ?? String()
            if (isa == "XCBuildConfiguration") {
                var buildSettings = dict["buildSettings"].dictionary ?? Dictionary<String, JSON>()
                let CODE_SIGN_STYLE = buildSettings["CODE_SIGN_STYLE"]?.string ?? String()
                if (!CODE_SIGN_STYLE.isEmpty) {
                    // 回写
                    buildSettings["CODE_SIGN_STYLE"] = JSON(type.rawValue)
                    dict["buildSettings"] = JSON(buildSettings)
                    let uuidKey = element.key
                    objects[uuidKey] = JSON(dict)
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
            // 回写
            objects[self._rootObjectUUID]!["attributes"]["TargetAttributes"] = JSON(newTargetAttributes)
        }
        
        self._cacheProjet["objects"] = JSON(objects)
    }
    
    
    /// Save the project to file
    ///
    /// - Returns: Saved the result
    public mutating func save() -> Bool {
        if (self._cacheProjet.isEmpty) {
            xcodeManagerPrintLog("Please use the 'init()' initialize!", type: .error)
            return false
        }
        
        let dict = _cacheProjet.dictionaryObject ?? Dictionary()
        if (dict.isEmpty) {
            xcodeManagerPrintLog("Save failed!", type: .error)
            return false
        }
        
        var fileUrl = URL(fileURLWithPath: _filePath)
        if fileUrl.pathExtension == "xcodeproj" {
            fileUrl.appendPathComponent("project.pbxproj")
        }
        
        return self.saveProject(fileURL: fileUrl, withPropertyList: dict)
    }
    
    
    fileprivate func xcodeManagerPrintLog<T>(_ message: T, type: XcodeManagerLogType = .info) {
        if (self._isPrintLog) {
            let msg = message as? String ?? String()
            if (!msg.isEmpty) {
                print("[\(type.rawValue)] \(msg)")
            }
        }
    }
    
}


extension Dictionary {
    fileprivate func isEqualTo(dict:[String: Any]) -> Bool {
        return NSDictionary(dictionary: self).isEqual(to: dict)
    }
}
