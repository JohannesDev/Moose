//
//  File.swift
//
//
//  Created by Johannes Zottele on 17.08.22.
//

import Foundation

/// Integer Environment Creation
extension BuiltIns {
    static let builtIn_Integer_Env: BaseEnvironment = createIntegerEnv()

    private static func createIntegerEnv() -> BaseEnvironment {
        let env = BaseEnvironment(enclosing: nil)
        env.set(function: "toBool", value: BuiltInFunctionObj(name: "toBool", params: [], returnType: BoolType(), function: intToBoolBuiltIn))
        env.set(function: "toFloat", value: BuiltInFunctionObj(name: "toFloat", params: [], returnType: FloatType(), function: intToFloatBuiltIn))
        env.set(function: "toString", value: BuiltInFunctionObj(name: "toString", params: [], returnType: StringType(), function: intToStrBuiltIn))
        return env
    }

    private static func intToBoolBuiltIn(params _: [MooseObject], _ env: Environment) throws -> BoolObj {
        let int: IntegerObj = try env
            .cast(to: BuiltInClassEnvironment.self)
            .value.cast()

        guard let value = int.value else {
            return BoolObj(value: nil)
        }

        return BoolObj(value: value == 0 ? false : true)
    }

    private static func intToFloatBuiltIn(params _: [MooseObject], _ env: Environment) throws -> FloatObj {
        let int: IntegerObj = try env
            .cast(to: BuiltInClassEnvironment.self)
            .value.cast()

        guard let value = int.value else {
            return FloatObj(value: nil)
        }

        return FloatObj(value: Float64(value))
    }

    private static func intToStrBuiltIn(params _: [MooseObject], _ env: Environment) throws -> StringObj {
        let int: IntegerObj = try env
            .cast(to: BuiltInClassEnvironment.self)
            .value.cast()

        guard let value = int.value else {
            return StringObj(value: nil)
        }

        return StringObj(value: String(value))
    }
}

/// Float Environment Creation
extension BuiltIns {
    static let builtIn_Float_Env: BaseEnvironment = createFloatEnv()

    private static func createFloatEnv() -> BaseEnvironment {
        let env = BaseEnvironment(enclosing: nil)
        env.set(function: "toInt", value: BuiltInFunctionObj(name: "toInt", params: [], returnType: IntType(), function: floatToIntBuiltIn))
        env.set(function: "toString", value: BuiltInFunctionObj(name: "toString", params: [], returnType: StringType(), function: floatToStrBuiltIn))
        return env
    }

    private static func floatToIntBuiltIn(params _: [MooseObject], _ env: Environment) throws -> IntegerObj {
        let float: FloatObj = try env
            .cast(to: BuiltInClassEnvironment.self)
            .value.cast()

        guard let value = float.value else {
            return IntegerObj(value: nil)
        }

        return IntegerObj(value: Int64(value))
    }

    private static func floatToStrBuiltIn(params _: [MooseObject], _ env: Environment) throws -> StringObj {
        let float: FloatObj = try env
            .cast(to: BuiltInClassEnvironment.self)
            .value.cast()

        guard let value = float.value else {
            return StringObj(value: nil)
        }

        return StringObj(value: String(value))
    }
}

/// Bool Environment Creation
extension BuiltIns {
    static let builtIn_Bool_Env: BaseEnvironment = createBoolEnv()

    private static func createBoolEnv() -> BaseEnvironment {
        let env = BaseEnvironment(enclosing: nil)
        env.set(function: "toInt", value: BuiltInFunctionObj(name: "toInt", params: [], returnType: IntType(), function: boolToIntBuiltIn))
        env.set(function: "toFloat", value: BuiltInFunctionObj(name: "toFloat", params: [], returnType: FloatType(), function: boolToFloatBuiltIn))
        env.set(function: "toString", value: BuiltInFunctionObj(name: "toString", params: [], returnType: StringType(), function: boolToStrBuiltIn))
        return env
    }

    private static func boolToIntBuiltIn(params _: [MooseObject], _ env: Environment) throws -> IntegerObj {
        let bool: BoolObj = try env
            .cast(to: BuiltInClassEnvironment.self)
            .value.cast()

        guard let value = bool.value else {
            return IntegerObj(value: nil)
        }

        return IntegerObj(value: value ? 1 : 0)
    }

    private static func boolToFloatBuiltIn(params _: [MooseObject], _ env: Environment) throws -> FloatObj {
        let bool: BoolObj = try env
            .cast(to: BuiltInClassEnvironment.self)
            .value.cast()

        guard let value = bool.value else {
            return FloatObj(value: nil)
        }

        return FloatObj(value: value ? 1.0 : 0.0)
    }

    private static func boolToStrBuiltIn(params _: [MooseObject], _ env: Environment) throws -> StringObj {
        let bool: BoolObj = try env
            .cast(to: BuiltInClassEnvironment.self)
            .value.cast()

        guard let value = bool.value else {
            return StringObj(value: nil)
        }

        return StringObj(value: value ? "true" : "false")
    }
}

/// String Environment Creation
extension BuiltIns {
    static let builtIn_String_Env: BaseEnvironment = createStringEnv()

    private static func createStringEnv() -> BaseEnvironment {
        let env = BaseEnvironment(enclosing: nil)
        env.set(function: "parseInt", value: BuiltInFunctionObj(name: "parseInt", params: [], returnType: TupleType([IntType(), StringType()]), function: strToIntBuiltIn))
        env.set(function: "parseFloat", value: BuiltInFunctionObj(name: "parseFloat", params: [], returnType: TupleType([FloatType(), StringType()]), function: strToFloatBuiltIn))
        env.set(function: "parseBool", value: BuiltInFunctionObj(name: "parseBool", params: [], returnType: TupleType([BoolType(), StringType()]), function: strToBoolBuiltIn))
        return env
    }

    private static func strToIntBuiltIn(params _: [MooseObject], _ env: Environment) throws -> TupleObj {
        let bool: StringObj = try env
            .cast(to: BuiltInClassEnvironment.self)
            .value.cast()

        let type = TupleType([FloatType(), StringType()])

        guard let input = bool.value else {
            return TupleObj(type: type, value: [IntegerObj(value: nil), StringObj(value: nil)])
        }

        var errMsg: String?
        let value = Int64(input)
        if value == nil {
            errMsg = "Cannot parse '\(input)' to an Int."
        }

        return TupleObj(type: type, value: [IntegerObj(value: value), StringObj(value: errMsg)])
    }

    private static func strToFloatBuiltIn(params _: [MooseObject], _ env: Environment) throws -> TupleObj {
        let bool: StringObj = try env
            .cast(to: BuiltInClassEnvironment.self)
            .value.cast()

        let type = TupleType([FloatType(), StringType()])

        guard let input = bool.value else {
            return TupleObj(type: type, value: [FloatObj(value: nil), StringObj(value: nil)])
        }

        var errMsg: String?
        let value = Float64(input)
        if value == nil {
            errMsg = "Cannot parse '\(input)' to an Float."
        }

        return TupleObj(type: type, value: [FloatObj(value: value), StringObj(value: errMsg)])
    }

    private static func strToBoolBuiltIn(params _: [MooseObject], _ env: Environment) throws -> TupleObj {
        let bool: StringObj = try env
            .cast(to: BuiltInClassEnvironment.self)
            .value.cast()

        let type = TupleType([BoolType(), StringType()])

        guard let input = bool.value else {
            return TupleObj(type: type, value: [BoolObj(value: nil), StringObj(value: nil)])
        }

        var errMsg: String?
        let value = Bool(input)
        if value == nil {
            errMsg = "Cannot parse '\(input)' to an Bool."
        }

        return TupleObj(type: type, value: [BoolObj(value: value), StringObj(value: errMsg)])
    }
}

/// Function Environment Creation
extension BuiltIns {
    static let builtIn_Function_Env: BaseEnvironment = createFunctionEnv()

    private static func createFunctionEnv() -> BaseEnvironment {
        let env = BaseEnvironment(enclosing: nil)
        return env
    }
}

/// BuiltInFunction Environment Creation
extension BuiltIns {
    static let builtIn_BuiltInFunction_Env: BaseEnvironment = createBuiltInFunctionEnv()

    private static func createBuiltInFunctionEnv() -> BaseEnvironment {
        let env = BaseEnvironment(enclosing: nil)
        return env
    }
}

/// Opterator Environment Creation
extension BuiltIns {
    static let builtIn_Operator_Env: BaseEnvironment = createOperatorEnv()

    private static func createOperatorEnv() -> BaseEnvironment {
        let env = BaseEnvironment(enclosing: nil)
        return env
    }
}

/// BuiltInOperator Environment Creation
extension BuiltIns {
    static let builtIn_BuiltInOperator_Env: BaseEnvironment = createBuiltInOperatorEnv()

    private static func createBuiltInOperatorEnv() -> BaseEnvironment {
        let env = BaseEnvironment(enclosing: nil)
        return env
    }
}

/// Tuple Environment Creation
extension BuiltIns {
    static let builtIn_Tuple_Env: BaseEnvironment = createTupleEnv()

    private static func createTupleEnv() -> BaseEnvironment {
        let env = BaseEnvironment(enclosing: nil)
        return env
    }
}

/// List Environment Creation
extension BuiltIns {
    static let builtIn_List_Env: BaseEnvironment = createListEnv()

    private static func createListEnv() -> BaseEnvironment {
        let env = BaseEnvironment(enclosing: nil)
        env.set(function: "length", value: BuiltInFunctionObj(name: "length", params: [], returnType: IntType(), function: listLengthImpl))
        return env
    }

    private static func listLengthImpl(params _: [MooseObject], _ env: Environment) throws -> MooseObject {
        let list: ListObj = try env
            .cast(to: BuiltInClassEnvironment.self)
            .value.cast()

        return IntegerObj(value: Int64(list.length()))
    }
}

/// Void Environment Creation
extension BuiltIns {
    static let builtIn_Void_Env: BaseEnvironment = createVoidEnv()

    private static func createVoidEnv() -> BaseEnvironment {
        let env = BaseEnvironment(enclosing: nil)
        return env
    }
}

/// Nil Environment Creation
extension BuiltIns {
    static let builtIn_Nil_Env: BaseEnvironment = createNilEnv()

    private static func createNilEnv() -> BaseEnvironment {
        let env = BaseEnvironment(enclosing: nil)
        return env
    }
}

/// This struct wraps the environment of a builtin class
/// and its own mooseObject
///
/// It is a struct so we can change the value without coping the class all the time and use a single environment for all builtin
/// class objects.
struct BuiltInClassEnvironment: Environment {
    let env: BaseEnvironment
    var value: MooseObject!

    func update(variable: String, value: MooseObject, allowDefine: Bool) -> Bool {
        env.update(variable: variable, value: value, allowDefine: allowDefine)
    }

    func updateInCurrentEnv(variable: String, value: MooseObject, allowDefine: Bool) -> Bool {
        env.updateInCurrentEnv(variable: variable, value: value, allowDefine: allowDefine)
    }

    func get(variable: String) throws -> MooseObject {
        try env.get(variable: variable)
    }

    func getAllVariables() -> [String: MooseObject] {
        env.getAllVariables()
    }

    func has(function: String, params: [MooseType]) -> Bool {
        env.has(function: function, params: params)
    }

    func set(function: String, value: MooseObject) {
        env.set(function: function, value: value)
    }

    func get(function: String, params: [MooseType]) throws -> MooseObject {
        try env.get(function: function, params: params)
    }

    func set(op: String, value: MooseObject) {
        env.set(op: op, value: value)
    }

    func get(op: String, pos: OpPos, params: [MooseType]) throws -> MooseObject {
        try env.get(op: op, pos: pos, params: params)
    }

    func set(clas: String, env: ClassEnvironment) {
        env.set(clas: clas, env: env)
    }

    func get(clas: String) throws -> ClassEnvironment {
        try env.get(clas: clas)
    }

    func nearestClass() throws -> ClassEnvironment {
        try env.nearestClass()
    }

    func isGlobal() -> Bool {
        env.isGlobal()
    }

    func global() -> Environment {
        env.global()
    }

    var closed: Bool {
        get {
            return env.closed
        }
        set(newClosed) {
            env.closed = newClosed
        }
    }

    var enclosing: Environment? {
        return env.enclosing
    }

    func printDebug(header _: Bool) {
        env.printDebug()
    }
}
