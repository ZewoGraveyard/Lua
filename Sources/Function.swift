import CLua

public struct FunctionError : Error, CustomStringConvertible {
    public let description: String
}

public class Function : StoredValue {
    public func call(_ args: [Value]) throws -> [Value] {
        let debugTable = lua.globals["debug"] as! Table
        let messageHandler = debugTable["traceback"]

        let originalStackTop = lua.topElementIndex

        messageHandler.push(lua)
        push(lua)
        
        for arg in args {
            arg.push(lua)
        }

        let result = lua_pcallk(lua.state, Int32(args.count), LUA_MULTRET, Int32(originalStackTop + 1), 0, nil)
        lua.remove(at: originalStackTop + 1)

        guard result == LUA_OK else {
            throw FunctionError(description: lua.popError())
        }

        var values: [Value] = []
        let numReturnValues = lua.topElementIndex - originalStackTop

        for _ in 0 ..< numReturnValues {
            let v = lua.pop(at: originalStackTop + 1)!
            values.append(v)
        }

        return values
    }

    override public var type: Type {
        return .function
    }

    override public class func typecheck(value: Value, lua: Lua) -> Bool {
        return value.type == .function
    }
}
