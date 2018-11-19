//  XcodeManagerFile.swift
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

internal struct XcodeManagerFile {
    /// detection file type
    public func detectionType(path: String) -> String {
        if (path.isEmpty) {
            return "unknown"
        }
        
        let fileURL = URL(fileURLWithPath: path)
        
        let filePathExtension = fileURL.pathExtension
        if (!fileURL.isFileURL || filePathExtension.isEmpty) {
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
    
}
