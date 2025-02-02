import PythonKit
fileprivate let SwiftModule = Python.import("Swift")

@_cdecl("releaseFunctionTable")
public func releaseFunctionTable(_ tableRef: OwnedPyObjectPointer) -> OwnedPyObjectPointer {
    let tableObject = PythonObject(tableRef)
    
    let keys = [PythonObject](tableObject.keys())!
    let noneObject = Python.None
    
    for key in keys {
        guard let address = Int(tableObject[key]) else {
            continue
        }
        
        FunctionHandle.release(address: address)
        tableObject[key] = noneObject
    }
    
    return SwiftModule.SwiftReturnValue(noneObject, noneObject).ownedPyObject
}
