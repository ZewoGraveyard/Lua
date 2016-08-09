import CLua

public protocol TypeCheckable {
    static func typecheck(value: Value, lua: Lua) -> Bool
}

public protocol Value : TypeCheckable {
    func push(_ lua: Lua)
    var type: Type { get }
}

public class StoredValue : Value, Equatable {
    private let registryLocation: Int
    internal unowned var lua: Lua

    internal init(_ lua: Lua) {
        self.lua = lua
        lua.pushValue(at: -1)
        registryLocation = lua.ref(RegistryIndex)
    }

    deinit {
        lua.unref(RegistryIndex, registryLocation)
    }

    public func push(_ lua: Lua) {
        lua.rawGet(at: RegistryIndex, n: registryLocation)
    }

    public var type: Type {
        fatalError("Override type")
    }

    public class func typecheck(value: Value, lua: Lua) -> Bool {
        fatalError("Override arg()")
    }
}

public func ==(lhs: StoredValue, rhs: StoredValue) -> Bool {
    if lhs.lua.state != rhs.lua.state {
        return false
    }

    lhs.push(lhs.lua)
    lhs.push(rhs.lua)
    let result = lua_compare(lhs.lua.state, -2, -1, LUA_OPEQ) == 1
    lhs.lua.pop(n: 2)

    return result
}
