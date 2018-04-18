# XcodeManager

[![Travis CI](https://travis-ci.org/ZhengShouDong/XcodeManager.svg?branch=master)](https://travis-ci.org/ZhengShouDong/XcodeManager) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) [![Platform](https://img.shields.io/badge/Platform-OSX-green.svg)](https://github.com/ZhengShouDong/XcodeManager)

The better way to manage the xcode project file (project.pbxproj) in Swift.

1. Initialize the Xcode project file.

```swift
var project = XcodeManager(projectFile: "../.../projectTest.xcodeproj", printLog: true)
```

2. How to add static library in Xcode project?

```swift
project.addStaticLibraryToProject(staticLibraryFilePath: "../.../test.a")
```

3. How to add framework in Xcode project?

```swift
project.addFrameworkToProject(frameworkFilePath: "../.../test.framework")
```

4. How to add resources folder in Xcode project?

```swift
project.addFolderToProject(folderPath: "../.../test/")
```

5. How to add a single resources file in Xcode project?

```swift
project.addFileToProject(filePath: "../.../test.txt")
```

6. How to modify the product name (display name)?

```swift
project.updateProductName(productName: "TestProduct")
```

7. How to modify the bundle id?

```swift
project.updateBundleId(bundleid: "cn.zhengshoudong.TestProduct")
```

8. How to add new <Library Search Paths> value?

```swift
project.addNewLibrarySearchPathValue(newPath: "$(PROJECT_DIR)/TestProduct/Folder")
```

9. How to add new <Framework Search Paths> value?

```swift
project.addNewFrameworkSearchPathValue(newPath: "$(PROJECT_DIR)/TestProduct/Folder")
```

10. How to control the CodeSignStyle(manual OR automatic)?

```swift
project.updateCodeSignStyle(type: .manual)
```

11. Change is completed? You can save the project!

```swift
let isSaveSuccess = project.save()
if (isSaveSuccess) {
	print("Done!")
}
```