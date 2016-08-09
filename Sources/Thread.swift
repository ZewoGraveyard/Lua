public class Thread : StoredValue {
    override public var type: Type {
        return .thread
    }

    override public class func typecheck(value: Value, lua: Lua) -> Bool {
        return value.type != .thread
    }
}
