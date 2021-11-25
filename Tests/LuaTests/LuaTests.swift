import XCTest
@testable import Lua

class LuaTests : XCTestCase {
    func testFundamentals() {
        let lua = Lua()
        let table = lua.createTable()
        table[3] = "foo"
        XCTAssert(table[3] is String)
        XCTAssertEqual(table[3] as! String, "foo")
    }

    func testStringX() throws {
        let lua = Lua()
        let stringx = lua.createTable()

        stringx.create(function: "split") { [weak lua] (subject: String, separator: String) in
            guard let lua = lua else {
                return []
            }

            let components = subject.components(separatedBy: separator)

            let result = lua.createTable()

            for (i, component) in components.enumerated() {
                result[i + 1] = component
            }

            return [result]
        }

        lua.globals["stringx"] = stringx

        let values = try lua.eval("return stringx.split('hello world', ' ')")

        XCTAssertEqual(values.count, 1)
        XCTAssert(values[0] is Table)
        let array: [String] = (values[0] as! Table).asSequence()
        XCTAssertEqual(array, ["hello", "world"])
    }

    func testCustomType() throws {
        class Note: CustomTypeInstance {
            var name: String

            init(name: String) {
                self.name = name
            }
        }

        let lua = Lua()

        let note = lua.create(type: Note.self)

        note.create(method: "setName") { (note, name: String) in
            note.name = name
            return []
        }

        note.create(method: "getName") { note in
            return [note.name]
        }

        note.create(function: "new") { [weak lua] (name: String) in
            guard let lua = lua else {
                return []
            }

            let note = Note(name: name)
            let data = lua.createUserdata(note)
            return [data]
        }

        lua.globals["note"] = note

        try lua.eval("myNote = note.new('a custom note')")
        XCTAssert(lua.globals["myNote"] is Userdata)

        let myNote: Note = (lua.globals["myNote"] as! Userdata).toCustomType()
        XCTAssert(myNote.name == "a custom note")

        myNote.name = "now from XCTest"
        try lua.eval("print(myNote:getName())")

        try lua.eval("myNote:setName('even')")
        XCTAssert(myNote.name == "even")

        try lua.eval("myNote:setName('odd')")
        XCTAssert(myNote.name == "odd")
        print("Bye lua", lua)
    }

    func testCustomTypeStruct() throws {
        struct Note : CustomTypeInstance {
            var name: String
        }

        let lua = Lua()

        let note = lua.create(type: Note.self)

        note.create(method: "getName") { note in
            return [note.name]
        }

        note.create(function: "new") { [weak lua] (name: String) in
            guard let lua = lua else {
                return []
            }

            let note = Note(name: name)
            let data = lua.createUserdata(note)
            return [data]
        }

        lua.globals["note"] = note

        try lua.eval("myNote = note.new('a custom note')")
        XCTAssert(lua.globals["myNote"] is Userdata)

        var myNote: Note = (lua.globals["myNote"] as! Userdata).toCustomType()
        XCTAssert(myNote.name == "a custom note")

        myNote.name = "now from XCTest"
        try lua.eval("print(myNote:getName())")

        try lua.eval("myNote:setName('even')")
        XCTAssert(myNote.name == "even")

        try lua.eval("myNote:setName('odd')")
        XCTAssert(myNote.name == "odd")
        print("Bye lua", lua)
    }
}
