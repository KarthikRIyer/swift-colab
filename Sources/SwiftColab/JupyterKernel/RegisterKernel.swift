import PythonKit
import SwiftPythonBridge
import Foundation

fileprivate let json = Python.import("json")
fileprivate let os = Python.import("os")
fileprivate let sys = Python.import("sys")

fileprivate let KernelSpecManager = Python.import("jupyter_client").kernelspec.KernelSpecManager
fileprivate let TemporaryDirectory = Python.import("IPython").utils.tempdir.TemporaryDirectory
fileprivate let glob = Python.import("glob").glob

fileprivate let ipykernel_launcher = Python.import("ipykernel_launcher")

@_cdecl("JKRegisterKernel")
public func JKRegisterKernel() -> Void {
    print("=== Registering Swift Jupyter kernel ===")
    
    let kernel_env = make_kernel_env()
    try! validate_kernel_env(kernel_env)
    
    let kernel_name: PythonObject = "Swift"
    let kernel_json: PythonObject = [
        "argv": [
            sys.executable,
            "/env/python/Swift/Swift/swift_kernel.py",
            "-f",
            "{connection_file}",
        ],
        "display_name": kernel_name,
        "language": "swift",
        "env": kernel_env,
    ]
    
    //print("kernel.json:\n\(json.dumps(kernel_json, indent: 2))\n")
    
    let kernel_code_name: PythonObject = "swift"
    
    do { 
        let td = TemporaryDirectory()
        os.chmod(td.name, 0o755)
        
        do { 
            let f = Python.open(os.path.join(td.name, "kernel.json"), "w")
            json.dump(kernel_json, f, indent: 2)
            f.close()
        }
        
        KernelSpecManager().install_kernel_spec(td.name, kernel_code_name)
        td.cleanup()
    }
    
    //print("Registered kernel '\(kernel_name)' as '\(kernel_code_name)'!")
    
    // Addition from Philip Turner: 
    // If contents of the kernel initializers do not already match, overwrite Python and force the notebook to restart.
    let swiftKernelPath = "/env/python/Swift/Swift/swift_kernel.py"
    let pythonKernelPath = String(ipykernel_launcher.__file__)!
    
    let fm = FileManager.default
    
    if !fm.contentsEqual(atPath: swiftKernelPath, andPath: pythonKernelPath) {
        try! fm.copyItem(atPath: swiftKernelPath, toPath: pythonKernelPath)
        
        print("""
        |
        ===----------------------------------------------------------------------------------------===
        === Swift-Colab overwrote the Python kernel with Swift, but Colab is still in Python mode. ===
        === To enter Swift mode, go to Runtime > Restart runtime (NOT Factory reset runtime).      ===
        ===----------------------------------------------------------------------------------------===
        |
        """)
    } else {
        print("=== Swift Jupyter kernel was already registered ===")
    }
    
}

/// Returns environment variables that tell the kernel where things are.
fileprivate func make_kernel_env() -> PythonObject {
    let swift_toolchain = "/opt/swift/toolchain"
    
    let kernel_env: PythonObject = [:]
    kernel_env["PYTHONPATH"] = .init("\(swift_toolchain)/usr/lib/python3/dist-packages")
    kernel_env["LD_LIBRARY_PATH"] = .init("\(swift_toolchain)/usr/lib/swift/linux")
    kernel_env["REPL_SWIFT_PATH"] = .init("\(swift_toolchain)/usr/bin/repl_swift")
    kernel_env["SWIFT_BUILD_PATH"] = .init("\(swift_toolchain)/usr/bin/swift-build")
    kernel_env["SWIFT_PACKAGE_PATH"] = .init("\(swift_toolchain)/usr/bin/swift-package")
    
    return kernel_env
}

fileprivate struct Exception: LocalizedError {
    let errorDescription: String?

    init(_ errorDescription: String) { 
        self.errorDescription = errorDescription 
    }
}

/// Validates that the env vars refer to things that actually exist.
fileprivate func validate_kernel_env(_ kernel_env: PythonObject) throws {
    guard Bool(os.path.isfile(kernel_env["PYTHONPATH"] + "/lldb/_lldb.so"))! else {
        throw Exception("lldb python libs not found at \(kernel_env["PYTHONPATH"])")
    }
    
    guard Bool(os.path.isfile(kernel_env["REPL_SWIFT_PATH"]))! else {
        throw Exception("repl_swift binary not found at \(kernel_env["REPL_SWIFT_PATH"])")
    }
    
    if let filePath = kernel_env.checking["SWIFT_BUILD_PATH"], !Bool(os.path.isfile(filePath))! {
        throw Exception("swift-build binary not found at \(filePath)")
    }
    
    if let filePath = kernel_env.checking["SWIFT_PACKAGE_PATH"], !Bool(os.path.isfile(filePath))! {
        throw Exception("swift-package binary not found at \(filePath)")
    }
    
    if let filePath = kernel_env.checking["PYTHON_LIBRARY"], !Bool(os.path.isfile(filePath))! {
        throw Exception("python library not found at \(filePath)")
    }
    
    guard Bool(os.path.isdir(kernel_env["LD_LIBRARY_PATH"]))! else {
        throw Exception("swift libs not found at \(kernel_env["LD_LIBRARY_PATH"])")
    }
}
