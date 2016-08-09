import CLua

extension Bool : Value {
    public func push(_ lua: Lua) {
        lua_pushboolean(lua.state, self ? 1 : 0)
    }

    public var type: Type {
        return .boolean
    }

    public static func typecheck(value: Value, lua: Lua) -> Bool {
        return value.type == .boolean
    }
}

public class Nil : Value, Equatable {
    public func push(_ lua: Lua) {
        lua_pushnil(lua.state)
    }

    public var type: Type {
        return .nil
    }

    public class func typecheck(value: Value, lua: Lua) -> Bool {
        return value.type == .nil
    }
}

public func ==(lhs: Nil, rhs: Nil) -> Bool {
    return true
}

public class Number : StoredValue, CustomDebugStringConvertible {
    override public var type: Type {
        return .number
    }

    public func toDouble() -> Double {
        push(lua)
        let v = lua_tonumberx(lua.state, -1, nil)
        lua.pop()
        return v
    }

    public func toInteger() -> Int64 {
        push(lua)
        let v = lua_tointegerx(lua.state, -1, nil)
        lua.pop()
        return v
    }

    public var debugDescription: String {
        push(lua)
        let isInteger = lua_isinteger(lua.state, -1) != 0
        lua.pop()

        if isInteger { return toInteger().description }
        else { return toDouble().description }
    }

    override public class func typecheck(value: Value, lua: Lua) -> Bool {
        return value.type == .number
    }
}

extension Double : Value {
    public func push(_ lua: Lua) {
        lua_pushnumber(lua.state, self)
    }

    public var type: Type {
        return .number
    }

    public static func typecheck(value: Value, lua: Lua) -> Bool {
        value.push(lua)
        let isDouble = lua_isinteger(lua.state, -1) != 0
        lua.pop()
        return isDouble
    }
}

extension Int64 : Value {
    public func push(_ lua: Lua) {
        lua_pushinteger(lua.state, self)
    }

    public var type: Type {
        return .number
    }

    public static func typecheck(value: Value, lua: Lua) -> Bool {
        value.push(lua)
        let isDouble = lua_isinteger(lua.state, -1) != 0
        lua.pop()
        return isDouble
    }
}

extension Int : Value {
    public func push(_ lua: Lua) {
        lua_pushinteger(lua.state, Int64(self))
    }

    public var type: Type {
        return .number
    }

    public static func typecheck(value: Value, lua: Lua) -> Bool {
        return Int64.typecheck(value: value, lua: lua)
    }
}

extension String : Value {
    public func push(_ lua: Lua) {
        lua_pushstring(lua.state, (self as String))
    }

    public var type: Type {
        return .string
    }

    public static func typecheck(value: Value, lua: Lua) -> Bool {
        return value.type == .string
    }
}
