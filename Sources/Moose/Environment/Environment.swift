//
//  Created by flofriday on 08.08.2022
//

// This is the implementation of the environments that manage the life of
// variables, functions, classes etc.
//
// Note about this implementation: This implementation is very liberal, and
// doesn't check many errors. For example we don't validate types here.
// We can do this because the typechecker will always be run before this so we
// can assume here that the programs we see are well typed. And even if they
// weren't it wouldn't be our concern but a bug in the typechecker.
class Environment {
    let enclosing: Environment?
    private var variables: [String: MooseObject] = [:]
    private var funcs: [String: [MooseObject]] = [:]
    private var ops: [String: [MooseObject]] = [:]

    private var classDefinitions: [String: ClassEnvironment] = [:]

    init(enclosing: Environment?) {
        self.enclosing = enclosing
    }

    init(copy: Environment) {
        variables = copy.variables
        funcs = copy.funcs
        ops = copy.ops
        classDefinitions = copy.classDefinitions
        enclosing = copy.enclosing
    }
}

// The variable handling
extension Environment {
    /// Update a variable, if it is not found in this Evironment or any
    /// enclosing one, a new variable will be created.
    /// Returns true if the variable was found or defined.
    func update(variable: String, value: MooseObject, allowDefine: Bool = true) -> Bool {
        // Update if in current env
        if variables[variable] != nil {
            variables.updateValue(value, forKey: variable)
            return true
        }

        // Scan in enclosing envs
        if let enclosing = enclosing {
            let found = enclosing.update(variable: variable, value: value, allowDefine: false)
            if found {
                return true
            }
        }

        // Update if we are allowed to define new variables
        guard allowDefine else {
            return false
        }
        variables.updateValue(value, forKey: variable)
        return true
    }

    func updateInCurrentEnv(variable: String, value: MooseObject, allowDefine: Bool = true) -> Bool {
        // Update if in current env
        if variables[variable] != nil {
            variables.updateValue(value, forKey: variable)
            return true
        }
        // Update if we are allowed to define new variables
        guard allowDefine else {
            return false
        }
        variables.updateValue(value, forKey: variable)
        return true
    }

    /// Return the Mooseobject a variable is referencing to
    func get(variable: String) throws -> MooseObject {
        if let obj = variables[variable] {
            return obj
        }

        if let enclosing = enclosing {
            return try enclosing.get(variable: variable)
        } else {
            throw EnvironmentError(message: "Variable '\(variable)' not found.")
        }
    }

    // Return all variables.
    func getAllVariables() -> [String: MooseObject] {
        return variables
    }
}

// Define all function operations
extension Environment {
    private func isFuncBy(params: [MooseType], other: MooseType) -> Bool {
        guard
            case let .Function(paras, _) = other,
            paras.count == params.count
        else {
            return false
        }

        return zip(params, paras)
            .reduce(true) { acc, zip in
                let (param, para) = zip
                guard param == .Nil || param == para else { return false }
                return acc
            }
    }

    func set(function: String, value: MooseObject) {
        if funcs[function] == nil {
            funcs[function] = []
        }

        funcs[function]!.append(value)
    }

    func get(function: String, params: [MooseType]) throws -> MooseObject {
        if let objs = funcs[function]?
            .filter({ isFuncBy(params: params, other: $0.type) })
        {
            if objs.count > 1 {
                throw ScopeError(message: "Multiple possible functions of `\(function)` with params (\(params.map { $0.description }.joined(separator: ","))). You have to give more context to the function call.")
            }
            if objs.count == 1 {
                return objs.first!
            }
        }

        guard let enclosing = enclosing else {
            throw EnvironmentError(message: "Function '\(function)' not found.")
        }
        return try enclosing.get(function: function, params: params)
    }
}

// Define all function operations
extension Environment {
    private func isOpBy(pos: OpPos, params: [MooseType], other: MooseObject) -> Bool {
        if let obj = other as? BuiltInOperatorObj {
            return obj.opPos == pos && obj.params == params
        }
        if let obj = other as? OperatorObj, obj.opPos == pos, case .Function(params, _) = other.type {
            return true
        }
        return false
    }

    func set(op: String, value: MooseObject) {
        if ops[op] == nil {
            ops[op] = []
        }

        ops[op]!.append(value)
    }

    func get(op: String, pos: OpPos, params: [MooseType]) throws -> MooseObject {
        if let obj = ops[op]?.first(where: { isOpBy(pos: pos, params: params, other: $0) }) {
            return obj
        }
        guard let enclosing = enclosing else {
            throw EnvironmentError(message: "Operation '\(op)' not found.")
        }
        return try enclosing.get(op: op, pos: pos, params: params)
    }
}

// Define all function for classes
extension Environment {
    func set(clas: String, env: ClassEnvironment) {
        classDefinitions[clas] = env
    }

    func get(clas: String) throws -> ClassEnvironment {
        guard let env = classDefinitions[clas] else {
            throw EnvironmentError(message: "Class `\(clas)` not found.")
        }

        return env
    }

    func nearestClass() throws -> ClassEnvironment {
        guard let env = self as? ClassEnvironment else {
            guard let enclosing = enclosing else {
                throw EnvironmentError(message: "Not inside a class object.")
            }
            return try enclosing.nearestClass()
        }
        return env
    }
}

// Some helper functions
extension Environment {
    func isGlobal() -> Bool {
        return enclosing == nil
    }
}

// Debug functions to get a better look into what the current environment is
// doing
extension Environment {
    func printDebug(header: Bool = true) {
        if header {
            print("=== Environment Debug Output (most inner scope last) ===")
        }

        if let enclosing = enclosing {
            enclosing.printDebug(header: false)
        }

        if isGlobal() {
            print("--- Environment (global) ---")
        } else {
            print("--- Environment ---")
        }
        print("Variables: ")
        for (variable, value) in variables {
            print("\t\(variable): \(value.type.description) = \(value.description)")
        }
        if variables.isEmpty {
            print("\t<empty>")
        }

        print("Functions: ")
        for (function, values) in funcs {
            for value in values {
                print("\t\(function) = \(value.description)")
            }
        }
        if funcs.isEmpty {
            print("\t<empty>")
        }

        print("Operators: ")
        for (op, values) in ops {
            for value in values {
                print("\t\(op) = \(value.description)")
            }
        }
        if ops.isEmpty {
            print("\t<empty>")
        }
        print()
    }
}

class ClassEnvironment: Environment {
    let propertyNames: [String]
    let className: String

    init(enclosing: Environment?, className: String, propertyNames: [String]) {
        self.propertyNames = propertyNames
        self.className = className
        super.init(enclosing: enclosing)
    }

    init(copy: ClassEnvironment) {
        propertyNames = copy.propertyNames
        className = copy.className
        super.init(copy: copy)
    }
}
