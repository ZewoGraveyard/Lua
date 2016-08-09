import CLua
import Foundation

internal let RegistryIndex = Int(CLUA_REGISTRYINDEX)
private let GlobalsTable = Int(LUA_RIDX_GLOBALS)

public enum MaybeFunction {
    case value(Function)
    case error(String)
}

public typealias ErrorHandler = (String) -> Void

public enum Type {
    case string
    case number
    case boolean
    case function
    case table
    case userdata
    case lightUserdata
    case thread
    case `nil`
    case none

    internal var luaType: Int32 {
        switch self {
        case .string: return LUA_TSTRING
        case .number: return LUA_TNUMBER
        case .boolean: return LUA_TBOOLEAN
        case .function: return LUA_TFUNCTION
        case .table: return LUA_TTABLE
        case .userdata: return LUA_TUSERDATA
        case .lightUserdata: return LUA_TLIGHTUSERDATA
        case .thread: return LUA_TTHREAD
        case .nil: return LUA_TNIL
        case .none: return LUA_TNONE
        }
    }
}

public class Lua {
    internal let state: OpaquePointer!

    public init(loadStandardLibraries: Bool = true) {
        self.state = luaL_newstate()

        if loadStandardLibraries {
            self.loadStandardLibraries()
        }
    }

    public func loadStandardLibraries() {
        luaL_openlibs(state)
    }

    deinit {
        lua_close(state)
    }

    internal func type(at index: Int) -> Type {
        switch lua_type(state, Int32(index)) {
        case LUA_TSTRING: return .string
        case LUA_TNUMBER: return .number
        case LUA_TBOOLEAN: return .boolean
        case LUA_TFUNCTION: return .function
        case LUA_TTABLE: return .table
        case LUA_TUSERDATA: return .userdata
        case LUA_TLIGHTUSERDATA: return .lightUserdata
        case LUA_TTHREAD: return .thread
        case LUA_TNIL: return .nil
        default: return .none
        }
    }

    public var errorHandler: ErrorHandler? = {
        print("error: \($0)")
    }

    internal func pop(at index: Int) -> Value? {
        moveToTopValue(at: index)
        var value: Value?
        switch type(at: -1) {
        case .string:
            var len: Int = 0
            let str = lua_tolstring(state, -1, &len)
            let data = Data(bytes: str!, count: Int(len))
            value = String(data: data, encoding: String.Encoding.utf8)
        case .number: value = Number(self)
        case .boolean: value = lua_toboolean(state, -1) == 1 ? true : false
        case .function: value = Function(self)
        case .table: value = Table(self)
        case .userdata: value = Userdata(self)
        case .lightUserdata: value = LightUserdata(self)
        case .thread: value = Thread(self)
        case .nil: value = Nil()
        default: break
        }
        pop()
        return value
    }

    public var globals: Table {
        rawGet(at: RegistryIndex, n: GlobalsTable)
        return pop(at: -1) as! Table
    }

    public var registry: Table {
        pushValue(at: RegistryIndex)
        return pop(at: -1) as! Table
    }

    public func createFunction(_ body: String) throws -> Function {
        guard luaL_loadstring(state, (body as NSString).utf8String) == LUA_OK else {
            throw FunctionError(description: popError())
        }
        return pop(at: -1) as! Function
    }

    public func createTable(_ sequenceCapacity: Int = 0, keyCapacity: Int = 0) -> Table {
        lua_createtable(state, Int32(sequenceCapacity), Int32(keyCapacity))
        return pop(at: -1) as! Table
    }

    internal func popError() -> String {
        let err = pop(at: -1) as! String
        if let fn = errorHandler { fn(err) }
        return err
    }

    public func createUserdataMaybe<T: CustomTypeInstance>(_ o: T?) -> Userdata? {
        if let u = o {
            return createUserdata(u)
        }
        return nil
    }

    public func createUserdata<T: CustomTypeInstance>(_ o: T) -> Userdata {
        let shit = lua_newuserdata(state, MemoryLayout<T>.size)
        let ptr = shit?.assumingMemoryBound(to: T.self) // this both pushes ptr onto stack and returns it
        ptr!.initialize(to: o) // creates a new legit reference to o

        luaL_setmetatable(state, (T.luaTypeName as NSString).utf8String) // this requires ptr to be on the stack
        return pop(at: -1) as! Userdata // this pops ptr off stack
    }

    @discardableResult
    public func eval(_ string: String, arguments: Value...) throws -> [Value] {
        return try eval(string, arguments: arguments)
    }

    @discardableResult
    public func eval(_ string: String, arguments: [Value]) throws -> [Value] {
        let function = try createFunction(string)
        return try function.call(arguments)
    }

    func getParameter<T : TypeCheckable>() throws -> T {
        guard let value = pop(at: 1) else {
            throw FunctionError(description: "No value.")
        }

        if !T.typecheck(value: value, lua: self) {
            throw FunctionError(description: "Wrong type.")
        }

        if let a = value as? T {
            return a
        } else if let userdataA = value as? Userdata, T.self is CustomTypeInstance.Type {
            return userdataA.forceToCustomType()
        } else {
            throw FunctionError(description: "Value not convertible to \(String(reflecting: T.self))")
        }
    }

    func push(values: [Value]) -> Int32  {
        for value in values {
            value.push(self)
        }

        return Int32(values.count)
    }

    func push(error: Error) {
        String(describing: error).push(self)
        lua_error(state)
    }

    public func createFunction(body: @escaping (Void) throws -> [Value]) -> Function {
        let cFunction: @convention(block) (OpaquePointer) -> Int32 = { [weak self] _ in
            guard let lua = self else {
                return 0
            }

            do {
                let result = try body()
                return lua.push(values: result)
            } catch {
                lua.push(error: error)
                return 0
            }
        }

        let block: AnyObject = unsafeBitCast(cFunction, to: AnyObject.self)
        let implementation = imp_implementationWithBlock(block)
        lua_pushcclosure(state, unsafeBitCast(implementation, to: lua_CFunction.self), 0)
        return pop(at: -1) as! Function
    }

    public func createFunction<A : TypeCheckable>(body: @escaping (A) throws -> [Value]) -> Function {
        let cFunction: @convention(block) (OpaquePointer) -> Int32 = { [weak self] _ in
            guard let lua = self else {
                return 0
            }

            do {
                let a: A = try lua.getParameter()
                let result = try body(a)
                return lua.push(values: result)
            } catch {
                lua.push(error: error)
                return 0
            }
        }

        let block: AnyObject = unsafeBitCast(cFunction, to: AnyObject.self)
        let implementation = imp_implementationWithBlock(block)
        lua_pushcclosure(state, unsafeBitCast(implementation, to: lua_CFunction.self), 0)
        return pop(at: -1) as! Function
    }

    public func createFunction<A : TypeCheckable, B : TypeCheckable>(body: @escaping (A, B) throws -> [Value]) -> Function {
        let cFunction: @convention(block) (OpaquePointer) -> Int32 = { [weak self] _ in
            guard let lua = self else {
                return 0
            }

            do {
                let a: A = try lua.getParameter()
                let b: B = try lua.getParameter()
                let result = try body(a, b)
                return lua.push(values: result)
            } catch {
                lua.push(error: error)
                return 0
            }
        }

        let block: AnyObject = unsafeBitCast(cFunction, to: AnyObject.self)
        let implementation = imp_implementationWithBlock(block)
        lua_pushcclosure(state, unsafeBitCast(implementation, to: lua_CFunction.self), 0)
        return pop(at: -1) as! Function
    }

    public func createFunction<A : TypeCheckable, B : TypeCheckable, C : TypeCheckable>(body: @escaping (A, B, C) throws -> [Value]) -> Function {
        let cFunction: @convention(block) (OpaquePointer) -> Int32 = { [weak self] _ in
            guard let lua = self else {
                return 0
            }

            do {
                let a: A = try lua.getParameter()
                let b: B = try lua.getParameter()
                let c: C = try lua.getParameter()
                let result = try body(a, b, c)
                return lua.push(values: result)
            } catch {
                lua.push(error: error)
                return 0
            }
        }

        let block: AnyObject = unsafeBitCast(cFunction, to: AnyObject.self)
        let implementation = imp_implementationWithBlock(block)
        lua_pushcclosure(state, unsafeBitCast(implementation, to: lua_CFunction.self), 0)
        return pop(at: -1) as! Function
    }

    public func create<T : CustomTypeInstance & Equatable>(type: T.Type) -> CustomType<T> {
        let customType = create(type: type)

        customType["__eq"] = createFunction { (lhsUserdata: Userdata, rhsUserdata: Userdata) in
            let lhs: T = lhsUserdata.toCustomType()
            let rhs: T = rhsUserdata.toCustomType()
            return [lhs == rhs]
        }

        return customType
    }

    public func create<T : CustomTypeInstance>(type: T.Type) -> CustomType<T> {
        lua_createtable(state, 0, 0)
        let customType = CustomType<T>(self)
        pop()

        registry[T.luaTypeName] = customType
        customType.becomeMetatableFor(customType)
        customType["__index"] = customType
        customType["__name"] = T.luaTypeName

        customType["__gc"] = createFunction { (userdata: Userdata) in
            (userdata.userdataPointer() as UnsafeMutablePointer<Void>).deinitialize(count: 1)
            let value: T = userdata.toCustomType()
            customType.deinitialize(value)
            return []
        }

        return customType
    }

    func moveToTopValue(at index: Int) {
        var index = index

        if index == -1 || index == topElementIndex {
            return
        }

        index = absolute(index: index)
        pushValue(at: index)
        remove(at: index)
    }

    func ref(_ position: Int) -> Int {
        return Int(luaL_ref(state, Int32(position)))
    }

    func unref(_ table: Int, _ position: Int) {
        luaL_unref(state, Int32(table), Int32(position))
    }

    func absolute(index: Int) -> Int {
        return Int(lua_absindex(state, Int32(index)))
    }

    func rawGet(at index: Int, n: Int) {
        lua_rawgeti(state, Int32(index), lua_Integer(n))
    }

    func pushValue(at index: Int) {
        lua_pushvalue(state, Int32(index))
    }

    func pop(n: Int = 1) {
        lua_settop(state, -Int32(n)-1)
    }

    func rotate(at index: Int, n: Int) {
        lua_rotate(state, Int32(index), Int32(n))
    }

    func remove(at index: Int) {
        rotate(at: index, n: -1)
        pop(n: 1)
    }

    var topElementIndex: Int {
        return Int(lua_gettop(state))
    }
}
