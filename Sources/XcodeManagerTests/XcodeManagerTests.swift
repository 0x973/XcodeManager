//  XcodeManagerTests.swift
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

import XCTest
import XcodeManager

class XcodeManagerTests: XCTestCase {
    
    private var _project: XcodeManager? = nil
    
    override func setUp() {
        super.setUp()
        if let file = Bundle(for: XcodeManagerTests.self).path(forResource: "project", ofType: "pbxproj") {
            do {
                _project = try XcodeManager(projectFile: file, printLog: true)
            }catch {
                XCTFail("Initialization failed!")
            }
        } else {
            XCTFail("Can't find the xcode test project file!")
        }
        
        if (_project == nil) {
          XCTFail("Initialization failed!")
        }
    }
    
    // test ProductName get and set. finally, will reset
    func testProductName() {
        let productName = _project!.getProductName()
        XCTAssertEqual(productName, "$(TARGET_NAME)")
        
        _project!.setProductName("ProductNameTest")
        XCTAssertEqual(_project!.getProductName(), "ProductNameTest")
        
        _project!.setProductName(productName)
    }
    
    // test BundleId get and set. finally, will reset
    func testBundleId() {
        let bundleId = _project!.getBundleId()
        XCTAssertEqual(bundleId, "cn.zhengshoudong.iOSTestProject")
        
        _project!.setBundleId("cn.zhengshoudong.xxxx")
        XCTAssertEqual(_project!.getBundleId(), "cn.zhengshoudong.xxxx")
        
        _project!.setBundleId(bundleId)
    }
    
    override func tearDown() {
        _project = nil
    }
    
    //    func testPerformanceExample() {
    //        // This is an example of a performance test case.
    //        self.measure {
    //            // Put the code you want to measure the time of here.
    //        }
    //    }
    
}
