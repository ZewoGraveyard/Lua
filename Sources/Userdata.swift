import CLua

public class Userdata : StoredValue {
    func userdataPointer<T>() -> UnsafeMutablePointer<T> {
        push(lua)
        let ptr = lua_touserdata(lua.state, -1)
        lua.pop()
        return ptr!.assumingMemoryBound(to: T.self)
    }

    func toCustomType<T: CustomTypeInstance>() -> T {
        return userdataPointer().pointee
    }

    func forceToCustomType<T>() -> T {
        return userdataPointer().pointee
    }

    func toAny() -> Any {
        return userdataPointer().pointee
    }

    override public var type: Type {
        return .userdata
    }
}

public class LightUserdata : StoredValue {
    override public var type: Type {
        return .lightUserdata
    }

    override public class func typecheck(value: Value, lua: Lua) -> Bool {
        return value.type == .lightUserdata
    }
}

public protocol CustomTypeInstance : TypeCheckable {
    static var luaTypeName: String { get }
}

public extension CustomTypeInstance {
    static var luaTypeName: String {
        return String(reflecting: self)
    }

    static func typecheck(value: Value, lua: Lua) -> Bool {
        value.push(lua)
        let isLegit = luaL_testudata(lua.state, -1, (Self.luaTypeName as String)) != nil
        lua.pop()
        return isLegit
    }
}

public class CustomType<T: CustomTypeInstance> : Table {
    var deinitialize: @escaping (T) -> Void = { _ in }

    public func deinitialize(_ closure: @escaping (T) -> Void) {
        deinitialize = closure
    }

    public func create(method: String, _ body: @escaping (T) -> [Value]) {
        self[method] = lua.createFunction(body: body)
    }

    public func create<A : Value>(method: String, _ body: @escaping (T, A) -> [Value]) {
        self[method] = lua.createFunction(body: body)
    }

    public func create<A : Value, B : Value>(method: String, _ body: @escaping (T, A, B) -> [Value]) {
        self[method] = lua.createFunction(body: body)
    }
}
