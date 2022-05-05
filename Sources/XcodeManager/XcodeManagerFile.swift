//  XcodeManagerFile.swift
//
//  Copyright (c) 2018, Shoudong Zheng
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

internal struct XcodeManagerFile {
    let defaultFileType = "unknown"
    static let fileTypeDict = ["jpeg": "image.jpg", "mp4": "video.mp4",
                               "xib": "file.xib", "plist": "text.plist.xml",
                               "xml": "sourcecode.xml", "png": "image.png",
                               "txt": "text", "xcconfig": "text.xcconfig",
                               "sh": "text.script.sh","pch": "sourcecode.c.h",
                               "tbd": "sourcecode.text-based-dylib-definition",
                               "m": "sourcecode.c.objc", "h": "sourcecode.c.h",
                               "a": "archive.ar", "framework": "wrapper.framework",
                               "html": "sourcecode.html", "json": "sourcecode.json",
                               "dylib": "compiled.mach-o.dylib", "jpg": "image.jpg",
                               "markdown": "text", "xcdatamodel": "wrapper.xcdatamodel",
                               "bundle": "wrapper.plug-in", "js": "sourcecode.javascript",
                               "swift": "sourcecode.swift", "storyboard": "file.storyboard",
                               "app": "wrapper.application", "xcassets": "folder.assetcatalog"]
    
    public func detectionType(path: String) -> String {
        if (path.isEmpty) {
            return defaultFileType
        }
        
        let fileURL = URL(fileURLWithPath: path)
        
        let filePathExtension = fileURL.pathExtension
        if (!fileURL.isFileURL || filePathExtension.isEmpty) {
            return defaultFileType
        }
        
        let type = XcodeManagerFile.fileTypeDict[filePathExtension] ?? String()
        if !type.isEmpty {
            return type
        }
        
        return "unknown"
    }
}
