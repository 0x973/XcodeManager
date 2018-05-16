# XcodeManager

[![Travis CI](https://travis-ci.org/ZhengShouDong/XcodeManager.svg?branch=master)](https://travis-ci.org/ZhengShouDong/XcodeManager) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-00D835.svg?style=flat)](https://github.com/Carthage/Carthage) [![Platform](https://img.shields.io/badge/Platform-OSX-green.svg)](https://github.com/ZhengShouDong/XcodeManager)

The better way to manage the Xcode project file (project.pbxproj) in swift.
This swift module lets you automate the modification process.

## Requirements

- macOS 10.12+
- Xcode 8+

## Integration

#### Swift Package Manager
```swift
.package(url: "https://github.com/ZhengShouDong/XcodeManager.git", from: "0.1.0")
```

#### Carthage
You can use [Carthage](https://github.com/Carthage/Carthage) to install `XcodeManager` by adding it to your Cartfile:
```
github "ZhengShouDong/XcodeManager" ~> 0.1.0
```

## Usage
0. import module.

```swift
import XcodeManager
```

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

11. Complete modification? Write to a .pbxproj file!

```swift
let isSaveSuccess = project.save()
if (isSaveSuccess) {
	print("Done!")
}
```