import CLua

public class Table : StoredValue {
    override public var type: Type {
        return .table
    }

    override public class func typecheck(value: Value, lua: Lua) -> Bool {
        return value.type == .table
    }

    public subscript(key: Value) -> Value {
        get {
            push(lua)

            key.push(lua)
            lua_gettable(lua.state, -2)
            let v = lua.pop(at: -1)

            lua.pop()
            return v!
        }

        set {
            push(lua)

            key.push(lua)
            newValue.push(lua)
            lua_settable(lua.state, -3)

            lua.pop()
        }
    }

    public func create(function: String, _ body: @escaping (Void) -> [Value]) {
        self[function] = lua.createFunction(body: body)
    }

    public func create<A : Value>(function: String, _ body: @escaping (A) -> [Value]) {
        self[function] = lua.createFunction(body: body)
    }

    public func create<A : Value, B : Value>(function: String, _ body: @escaping (A, B) -> [Value]) {
        self[function] = lua.createFunction(body: body)
    }

    public func keys() -> [Value] {
        var k = [Value]()
        push(lua) // table
        lua_pushnil(lua.state)
        while lua_next(lua.state, -2) != 0 {
            lua.pop() // val
            let key = lua.pop(at: -1)!
            k.append(key)
            key.push(lua)
        }
        lua.pop() // table
        return k
    }

    public func becomeMetatableFor(_ value: Value) {
        value.push(lua)
        self.push(lua)
        lua_setmetatable(lua.state, -2)
        lua.pop()
    }

    public func asTupleArray<K1: Value, V1: Value, K2: Value, V2: Value>(_ kfn: (K1) -> K2 = {$0 as! K2}, _ vfn: (V1) -> V2 = {$0 as! V2}) -> [(K2, V2)] {
        var v = [(K2, V2)]()
        for key in keys() {
            let val = self[key]
            if key is K1 && val is V1 {
                v.append((kfn(key as! K1), vfn(val as! V1)))
            }
        }
        return v
    }

    public func asDictionary<K1: Value, V1: Value, K2: Value, V2: Value>(_ kfn: (K1) -> K2 = {$0 as! K2}, _ vfn: (V1) -> V2 = {$0 as! V2}) -> [K2: V2] where K2: Hashable {
        var v = [K2: V2]()
        for (key, val) in asTupleArray(kfn, vfn) {
            v[key] = val
        }
        return v
    }

    public func asSequence<T: Value>() -> [T] {
        var sequence = [T]()

        let dict: [Int64 : T] = asDictionary({ (k: Number) in k.toInteger() }, { $0 as T })

        // if it has no numeric keys, then it's empty; job well done, team, job well done.
        if dict.count == 0 { return sequence }

        // ensure table has no holes and keys start at 1
        let sortedKeys = dict.keys.sorted()
        if [Int64](1...sortedKeys.last!) != sortedKeys { return sequence }

        // append values to the array, in order
        for i in sortedKeys {
            sequence.append(dict[i]!)
        }

        return sequence
    }

    func storeReference(_ v: Value) -> Int {
        v.push(lua)
        return lua.ref(RegistryIndex)
    }

    func removeReference(_ ref: Int) {
        lua.unref(RegistryIndex, ref)
    }
}
