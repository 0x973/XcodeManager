# XcodeManager

![Build Status](https://github.com/X-0x01/XcodeManager/actions/workflows/swift.yml/badge.svg?branch=master)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-00D835.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Platform](https://img.shields.io/badge/Platform-OSX-green.svg)](https://github.com/X-0x01/XcodeManager)

The better way to manage the Xcode project file (project.pbxproj) in swift.
This swift module lets you automate the modification process.

## Requirements

- macOS 10.12+
- Xcode 8+

## Integration

#### Swift Package Manager
```swift
.package(url: "https://github.com/X-0x01/XcodeManager.git", from: "0.2.0")
```

#### Carthage
You can use [Carthage](https://github.com/Carthage/Carthage) to install `XcodeManager` by adding it to your Cartfile:
```
github "X-0x01/XcodeManager" ~> 0.2.0
```

## Usage
0. import module.

```swift
import XcodeManager
```

1. Initialize the Xcode project file.

```swift
var project = try? XcodeManager(projectFile: "../.../xxx.xcodeproj", printLog: true)
```

2. How to add static library in Xcode project?

```swift
project.linkStaticLibrary("../.../test.a")
```

3. How to add framework in Xcode project?

```swift
project.linkFramework("../.../test.framework")
```

4. How to add resources folder in Xcode project?

```swift
project.addFolder("../.../test/")
```

5. How to add a single resources file in Xcode project?

```swift
project.addFile("../.../test.txt")
```

6. How to modify the product name (display name)?

```swift
project.setProductName("TestProduct")
```

7. How to modify the Bundle Identifier?

```swift
project.setBundleId("cn.x0x01.TestProduct")
```

8. How to add new <Library Search Paths> value?

```swift
project.setLibrarySearchPathValue("$(PROJECT_DIR)/TestProduct/Folder")
```

9. How to add new <Framework Search Paths> value?

```swift
project.setFrameworkSearchPathValue("$(PROJECT_DIR)/TestProduct/Folder")
```

10. How to control the CodeSignStyle(manual OR automatic)?

```swift
project.setCodeSignStyle(type: .automatic)
project.setCodeSignStyle(type: .manual)
```

11. Complete modification? Write to a .pbxproj file!

```swift
let isSaveSuccess = try? project.save()
if (isSaveSuccess) {
	print("Done!")
}
```
