import Foundation
import PythonKit
fileprivate let SwiftModule = Python.import("Swift")

// Takes a Python string object as input, then compiles and runs it.
@_cdecl("runSwiftAsString")
public func runSwiftAsString(_ pythonStringRef: OwnedPyObjectPointer) -> OwnedPyObjectPointer {
    @inline(never)
    func getPythonError(message: String) -> PyObjectPointer {
        print(message)
        let errorObject = SwiftModule.SwiftError(message)
        return SwiftModule.SwiftReturnValue(Python.None, errorObject).ownedPyObject
    }
    
    guard let scriptString = String(PythonObject(pythonStringRef)) else {
        return getPythonError(message: "Could not decode the Python string passed into `runSwiftAsString(_:)`")
    }
    
    guard let scriptData = scriptString.data(using: .utf8) else {
        return getPythonError(message: "Python string was not decoded as UTF-8 when compiling a Swift script")
    }
    
    let targetPath = "/opt/swift/tmp/string_script.swift"
    FileManager.default.createFile(atPath: targetPath, contents: scriptData)
    
    let executeScript = Process()
    executeScript.executableURL = .init(fileURLWithPath: "/usr/bin/env")
    executeScript.arguments = ["swift", targetPath]
    executeScript.currentDirectoryURL = .init(fileURLWithPath: "/content")
    
    var environment = ProcessInfo.processInfo.environment
    let path = environment["PATH"]!
    environment["PATH"] = "/opt/swift/toolchain/usr/bin:\(path)"
    executeScript.environment = environment
    
    do {
        try executeScript.run()
    } catch {
        return getPythonError(message: error.localizedDescription)
    }
    
    executeScript.waitUntilExit()
    
    let noneObject = Python.None
    return SwiftModule.SwiftReturnValue(noneObject, noneObject).ownedPyObject
}
