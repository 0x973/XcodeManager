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

public class XcodeManager {
    /// 缓存用
    fileprivate var _cacheProjet: JSON = JSON()
    fileprivate var _hashTag: Int = Int()
    fileprivate var _filePath: String = String()
    
    /// 主要分组的UUID
    fileprivate var _mainGroupUUID: String = String()
    /// Node根路径的rootObject UUID
    fileprivate var _rootObjectUUID: String = String()
    /// 初始化就获取到的工程名称
    fileprivate var _currentProjectName: String = String()
    
    /// 解析工程文件,初始化入口
    public func initProject(_ filePath: String) -> XcodeManager {
        self._cacheProjet = JSON()
        self._hashTag = Int()
        self._filePath = String()
        self._mainGroupUUID = String()
        self._rootObjectUUID = String()
        self._currentProjectName = String()
        _ = self.parseProject(filePath)
        return self
    }
    
    
    fileprivate func parseProject(_ filePath: String) -> JSON {
        if (!FileManager.default.fileExists(atPath: filePath)) {
            print("指定项目文件不存在!")
            return JSON()
        }
        
        var fileUrl = URL(fileURLWithPath: filePath)
        if fileUrl.pathExtension == "xcodeproj" {
            fileUrl.appendPathComponent("project.pbxproj")
        }
        
        do {
            let fileData = try Data(contentsOf: fileUrl)
            
            if (self._hashTag == fileData.hashValue && !_cacheProjet.isEmpty) {
                // 数据一致,直接返回缓存
                return _cacheProjet
            }
            
            self._filePath = filePath
            self._hashTag = fileData.hashValue
            
            let data = try PropertyListSerialization.propertyList(from: fileData, options: .mutableContainersAndLeaves, format: nil)
            self._cacheProjet = JSON(data)
            self._rootObjectUUID = self._cacheProjet["rootObject"].stringValue
            self._mainGroupUUID = self._cacheProjet["objects"][self._rootObjectUUID]["mainGroup"].stringValue
            for ele in _cacheProjet["objects"] {
                let valueObj = ele.1
                if (!valueObj.isEmpty) {
                    if (valueObj["isa"].stringValue == "PBXNativeTarget" && valueObj["productType"].stringValue == "com.apple.product-type.application") {
                        let name = valueObj["name"].stringValue
                        _currentProjectName = name
                    }
                }
            }
            return self._cacheProjet
        } catch {
            print("read project file failed. error: \(error.localizedDescription)")
            return JSON()
        }
    }
    
    
    /// 将数据内容生成为工程文件
    ///
    /// - Parameters:
    ///   - fileURL: 工程文件路径
    ///   - list: 数据对象
    fileprivate func saveProject(fileURL: URL, withPropertyList list: Any) -> Bool{
        var url = fileURL
        func handleEncode(fileURL: URL) -> Bool {
            func encodeString(_ str: String) -> String {
                var result = ""
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
                print("translate chinese characters to mathematical symbols error: \(error.localizedDescription)")
                return false
            }
        }
        
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: list, format: .xml, options: 0)
            try data.write(to: url, options: .atomic)
            return handleEncode(fileURL: url)
        } catch {
            print("save project file failed: \(error.localizedDescription)")
            return false
        }
    }
    
    
    /// 获取objects所有的uuid(key)
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
    
    
    /// 生成不会和现有工程重复存在的uuid
    fileprivate func generateUuid() -> String {
        if (_cacheProjet.isEmpty) {
            // 缓存为空!!
            print("请使用'initProject'初始化工程后再调用!")
            return String()
        }
        
        // 缓存不为空!
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "").suffix(24).uppercased()
        let array = self.allUuids(_cacheProjet)
        if (array.index(of: uuid) ?? -1 >= 0) {
            return generateUuid()
        }
        return uuid
    }
    
    
    /// 在项目根节点生成pbx分组并挂载写入缓存
    ///  - 返回最终挂载在mainGroup的uuid
    fileprivate func generatePBXGroup(name: String) -> (String) {
        if (name.isEmpty) {
            print("请检查传入的name!")
            return ""
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
        
        
        // 挂载根节点
        var mainGroupObj = self._cacheProjet["objects"][self._mainGroupUUID]
        var mainGroupObjChildren = mainGroupObj["children"].arrayObject ?? Array()
        if (mainGroupObjChildren.isEmpty) {
            /// 一般工程不会为空,最起码有两个childrens
            print("解析mainGroupObj错误!")
            return ""
        }
        
        /// 回写
        mainGroupObjChildren.append(newUUID)
        mainGroupObj["children"] = JSON(mainGroupObjChildren)
        self._cacheProjet["objects"][self._mainGroupUUID] = mainGroupObj
        
        return newUUID
    }
    
    /// 检测文件类型,只返回Xcode支持的类型,其他为unknown
    fileprivate func detectLastType(path: String) -> String {
        if (path.isEmpty) {
            return "unknown"
        }
        
        let fileName = path.split(separator: "/").last ?? ""
        if (fileName.isEmpty) {
            return "unknown"
        }
        
        // 按照平时使用频率排序过了,提高遍历效率
        let regexsKeyValue = [
            ".xib": "file.xib",
            ".plist": "text.plist.xml",
            ".bundle": "wrapper.plug-in",
            ".a": "archive.ar",
            ".framework": "wrapper.framework",
            ".js": "sourcecode.javascript",
            ".html": "sourcecode.html",
            ".json": "sourcecode.json",
            ".xml": "sourcecode.xml",
            ".png": "image.png",
            ".txt": "text",
            ".xcconfig": "text.xcconfig",
            ".markdown": "text",
            ".tbd": "sourcecode.text-based-dylib-definition",
            ".sh": "text.script.sh",
            ".pch": "sourcecode.c.h",
            ".xcdatamodel": "wrapper.xcdatamodel",
            ".m": "sourcecode.c.objc",
            ".h": "sourcecode.c.h",
            ".swift": "sourcecode.swift",
            ".storyboard": "file.storyboard",
            ".dylib": "compiled.mach-o.dylib",
            ".jpg": "image.jpg",
            ".jpeg": "image.jpg",
            ".mp4": "video.mp4",
            ".app": "wrapper.application",
            ".xcassets": "folder.assetcatalog"
        ]
        
        for element in regexsKeyValue {
            let fileSuffix = element.key
            if (fileName.hasSuffix(fileSuffix)) {
                return element.value
            }
        }
        return "unknown"
    }
    
    
    /// 添加静态库,传入绝对路径
    public func addStaticLibrary(staticLibraryFilePath: String) {
        if (self._cacheProjet.isEmpty) {
            print("请使用'initProject'初始化工程后再调用!")
            return
        }
        
        if (staticLibraryFilePath.isEmpty || !FileManager.default.fileExists(atPath: staticLibraryFilePath)) {
            print("请检查传入的静态库路径是否正确!")
            return
        }
        
        let PBXFileReferenceUUID = generateUuid()
        var dict = Dictionary<String, Any>()
        dict["isa"] = "PBXFileReference"
        dict["lastKnownFileType"] = "archive.ar"
        dict["sourceTree"] = "<group>"
        dict["name"] = staticLibraryFilePath.split(separator: "/").last ?? staticLibraryFilePath
        dict["path"] = staticLibraryFilePath
        
        var objects = _cacheProjet["objects"].dictionary ?? Dictionary()
        if (objects.isEmpty) {
            return
        }
        
        /// 比较是否和当前工程中的obj一致
        for object in objects {
            if (object.value.dictionaryValue.isEqualTo(dict: dict)) {
                print("当前选择的已经添加过了!")
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
        self.addNewLibrarySearchPathValue(newPath: newPath)
        
        /* 添加到Xcode做左边显示的区域
         /// 在_mainGroup中创建的
         let newPbxObjUUID = generatePBXGroup(name: "Modules")
         
         /// 更新当前变量
         objects = _cacheProjet["objects"].dictionary ?? Dictionary()
         
         var newPbxObj = objects[newPbxObjUUID]?.dictionary ?? Dictionary()
         if (newPbxObj.isEmpty) {
         print("解析新建obj错误!")
         return
         }
         
         var newPbxObjChild = newPbxObj["children"]?.array ?? Array()
         newPbxObjChild.append(JSON(PBXBuildFileUUID))
         newPbxObj["children"] = JSON(newPbxObjChild)
         
         objects[newPbxObjUUID] = JSON(newPbxObj)
         
         // 回写缓存
         self._cacheProjet["objects"] = JSON(objects)
         */
    }
    
    
    /// 添加framework,传入绝对路径
    public func addFramework(frameworkFilePath: String) {
        if (self._cacheProjet.isEmpty) {
            print("请使用'initProject'初始化工程后再调用!")
            return
        }
        
        if (frameworkFilePath.isEmpty || !FileManager.default.fileExists(atPath: frameworkFilePath)) {
            print("请检查传入的静态库路径是否正确!")
            return
        }
        
        let PBXFileReferenceUUID = generateUuid()
        var dict = Dictionary<String, Any>()
        dict["isa"] = "PBXFileReference"
        dict["lastKnownFileType"] = "wrapper.framework"
        dict["sourceTree"] = "<group>"
        dict["name"] = frameworkFilePath.split(separator: "/").last ?? frameworkFilePath
        dict["path"] = frameworkFilePath
        
        var objects = _cacheProjet["objects"].dictionary ?? Dictionary()
        if (objects.isEmpty) {
            return
        }
        
        /// 比较是否和当前工程中的obj一致
        for object in objects {
            if (object.value.dictionaryValue.isEqualTo(dict: dict)) {
                print("当前选择的已经添加过了!")
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
        self.addNewFrameworkSearchPathValue(newPath: newPath)
    }
    
    
    /// 添加资源引用文件夹,传入参数为文件夹路径
    public func addFolder(folderFilePath: String) {
        if (self._cacheProjet.isEmpty) {
            print("请使用'initProject'初始化工程后再调用!")
            return
        }
        
        if (folderFilePath.isEmpty || !FileManager.default.fileExists(atPath: folderFilePath)) {
            print("请检查传入的静态库路径是否正确!")
            return
        }
        
        let PBXFileReferenceUUID = generateUuid()
        var dict = Dictionary<String, Any>()
        dict["isa"] = "PBXFileReference"
        dict["lastKnownFileType"] = "folder"
        dict["sourceTree"] = "<group>"
        dict["name"] = folderFilePath.split(separator: "/").last ?? folderFilePath
        dict["path"] = folderFilePath
        
        var objects = _cacheProjet["objects"].dictionary ?? Dictionary()
        if (objects.isEmpty) {
            return
        }
        
        /// 比较是否和当前工程中的obj一致
        for object in objects {
            if (object.value.dictionaryValue.isEqualTo(dict: dict)) {
                print("当前选择的已经添加过了!")
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
    
    
    /// 添加资源引用文件(bundle,js,xml,html,.png) (Copy Bundle Rsources),传入参数为文件路径
    public func addFileToProject(filePath: String) {
        if (self._cacheProjet.isEmpty) {
            print("请使用'initProject'初始化工程后再调用!")
            return
        }
        
        if (filePath.isEmpty || !FileManager.default.fileExists(atPath: filePath)) {
            print("请检查传入的路径是否正确!")
            return
        }
        
        let PBXFileReferenceUUID = generateUuid()
        var dict = Dictionary<String, Any>()
        dict["isa"] = "PBXFileReference"
        dict["lastKnownFileType"] = self.detectLastType(path: filePath)
        dict["sourceTree"] = "<group>"
        dict["name"] = filePath.split(separator: "/").last ?? filePath
        dict["path"] = filePath
        
        var objects = _cacheProjet["objects"].dictionary ?? Dictionary()
        if (objects.isEmpty) {
            return
        }
        
        /// 比较是否和当前工程中的obj一致
        for object in objects {
            if (object.value.dictionaryValue.isEqualTo(dict: dict)) {
                print("当前选择的已经添加过了!")
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
    
    
    /// 添加新的值到项目的Framework Search Paths 所有scheme都添加
    public func addNewFrameworkSearchPathValue(newPath: String) {
        if (newPath.isEmpty) {
            print("参数不可为空!")
            return
        }
        
        let objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        if (objects.isEmpty) {
            print("解析objects失败!")
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
                
                if (FRAMEWORK_SEARCH_PATHS?.type == .string) {
                    // 如果为字符串类型,说明当前有且只有一个value!
                    // 添加时候需要取出来然后变成数组放回去
                    let string = FRAMEWORK_SEARCH_PATHS?.string ?? String()
                    if (newPath == string) {
                        // 要添加的和已经存在的一致
                        print("要添加的和已经存在的一致!忽略添加!")
                        continue
                    }
                    var newArray = Array<String>()
                    newArray.append(string)
                    newArray.append(newPath)
                    
                    // 回写
                    buildSettings["FRAMEWORK_SEARCH_PATHS"] = JSON(newArray)
                    dict["buildSettings"] = JSON(buildSettings)
                    self._cacheProjet["objects"][element.key] = dict
                    
                } else if (FRAMEWORK_SEARCH_PATHS?.type == .array) {
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
                    
                }else {
                    // 不存在,创建并追加
                    var newArray = Array<String>()
                    newArray.append("$(inherited)")
                    newArray.append(newPath)
                    
                    // 回写
                    buildSettings["FRAMEWORK_SEARCH_PATHS"] = JSON(newArray)
                    dict["buildSettings"] = JSON(buildSettings)
                    self._cacheProjet["objects"][element.key] = dict
                    
                }
            }
        }
    }
    
    
    /// 添加新的值到项目的Library Search Paths 所有scheme都添加
    public func addNewLibrarySearchPathValue(newPath: String) {
        if (newPath.isEmpty) {
            print("参数不可为空!")
            return
        }
        
        let objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        if (objects.isEmpty) {
            print("解析objects失败!")
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
                let LIBRARY_SEARCH_PATHS = buildSettings["LIBRARY_SEARCH_PATHS"]
                
                if (LIBRARY_SEARCH_PATHS?.type == .string) {
                    // 如果为字符串类型,说明当前有且只有一个value!
                    // 添加时候需要取出来然后变成数组放回去
                    let string = LIBRARY_SEARCH_PATHS?.string ?? String()
                    if (newPath == string) {
                        // 要添加的和已经存在的一致
                        print("要添加的和已经存在的一致!忽略添加!")
                        continue
                    }
                    var newArray = Array<String>()
                    newArray.append(string)
                    newArray.append(newPath)
                    
                    // 回写
                    buildSettings["LIBRARY_SEARCH_PATHS"] = JSON(newArray)
                    dict["buildSettings"] = JSON(buildSettings)
                    self._cacheProjet["objects"][element.key] = dict
                    
                } else if (LIBRARY_SEARCH_PATHS?.type == .array) {
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
                    
                }else {
                    // 不存在,创建并追加
                    var newArray = Array<String>()
                    newArray.append("$(inherited)")
                    newArray.append(newPath)
                    
                    // 回写
                    buildSettings["LIBRARY_SEARCH_PATHS"] = JSON(newArray)
                    dict["buildSettings"] = JSON(buildSettings)
                    self._cacheProjet["objects"][element.key] = dict
                    
                }
            }
        }
    }
    
    
    /// 更改项目名
    public func updateProductName(productName: String) {
        if (productName.isEmpty) {
            print("参数不可为空!productName更改失败!")
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
    
    /// 更改项目bundleid
    public func updateBundleId(bundleid: String) {
        if (bundleid.isEmpty) {
            print("参数不可为空!bundleid更改失败!")
            return
        }
        let objects = self._cacheProjet["objects"].dictionary ?? Dictionary()
        for element in objects {
            var dict = element.value
            let isa = dict["isa"].string ?? String()
            if (isa == "XCBuildConfiguration") {
                var buildSettings = dict["buildSettings"].dictionary ?? Dictionary<String, JSON>()
                let PRODUCT_NAME = buildSettings["PRODUCT_BUNDLE_IDENTIFIER"]?.string ?? String()
                if (!PRODUCT_NAME.isEmpty) {
                    // 回写
                    buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] = JSON(bundleid)
                    dict["buildSettings"] = JSON(buildSettings)
                    let uuidKey = element.key
                    
                    self._cacheProjet["objects"][uuidKey] = JSON(dict)
                }
            }
        }
    }
    
    
    /// 全部操作完毕,保存至文件
    public func save() -> Bool {
        let dict = _cacheProjet.dictionaryObject ?? Dictionary()
        if (dict.isEmpty) {
            print("保存失败!")
            return false
        }
        
        var fileUrl = URL(fileURLWithPath: _filePath)
        if fileUrl.pathExtension == "xcodeproj" {
            fileUrl.appendPathComponent("project.pbxproj")
        }
        
        return self.saveProject(fileURL: fileUrl, withPropertyList: dict)
    }
    
}


extension Dictionary {
    /// 判断两个字典是否一致
    func isEqualTo(dict:[String: Any]) -> Bool {
        return NSDictionary(dictionary: self).isEqual(to: dict)
    }
}
