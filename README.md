# XcodeManager

[![Travis CI](https://travis-ci.org/ZhengShouDong/XcodeManager.svg?branch=master)](https://travis-ci.org/ZhengShouDong/XcodeManager) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) [![Platform](https://img.shields.io/badge/Platform-OSX-green.svg)](https://github.com/ZhengShouDong/XcodeManager)

The better way to manage the xcode project file (project.pbxproj) in Swift.

1. Initialize the Xcode project file.

```swift
var project = try? XcodeManager(projectFile: "../.../projectTest.xcodeproj", printLog: true)
```

2. How to add static library in Xcode project?

```swift
project.addStaticLibraryToProject("../.../test.a")
```

3. How to add framework in Xcode project?

```swift
project.addFrameworkToProject("../.../test.framework")
```

4. How to add resources folder in Xcode project?

```swift
project.addFolderToProject("../.../test/")
```

5. How to add a single resources file in Xcode project?

```swift
project.addFileToProject("../.../test.txt")
```

6. How to modify the product name (display name)?

```swift
project.updateProductName("TestProduct")
```

7. How to modify the bundle id?

```swift
project.updateBundleId("cn.zhengshoudong.TestProduct")
```

8. How to add new <Library Search Paths> value?

```swift
project.addNewLibrarySearchPathValue("$(PROJECT_DIR)/TestProduct/Folder")
```

9. How to add new <Framework Search Paths> value?

```swift
project.addNewFrameworkSearchPathValue("$(PROJECT_DIR)/TestProduct/Folder")
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