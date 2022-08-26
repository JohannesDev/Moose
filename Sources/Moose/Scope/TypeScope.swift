//
//  File.swift
//
//
//  Created by Johannes Zottele on 23.06.22.
//

import Foundation

class TypeScope: Scope {
    internal var variables: [String: (type: MooseType, mut: Bool)] = [:]
    internal var funcs: [String: [MooseType]] = [:]
    private var ops: [String: [(MooseType, OpPos)]] = [:]

    private var classes: [String: ClassTypeScope] = [:]

    let enclosing: TypeScope?
    var closed: Bool = false

    init(enclosing: TypeScope? = nil) {
        self.enclosing = enclosing
    }
}

// Define all variable specific operations
extension TypeScope {
    func typeOf(variable: String) throws -> MooseType {
        if let type = variables[variable] {
            return type.0
        }
        guard let enclosing = enclosing, !closed else {
            // TODO: We could find similarly named variables here and suggest
            // them
            throw ScopeError(message: "Couldn't find variable '\(variable)' in the current scope.")
        }
        return try enclosing.typeOf(variable: variable)
    }

    func has(variable: String, includeEnclosing: Bool = true) -> Bool {
        if variables.keys.contains(variable) {
            return true
        }
        guard includeEnclosing, let enclosing = enclosing, !closed else {
            return false
        }
        return enclosing.has(variable: variable, includeEnclosing: includeEnclosing)
    }

    func isMut(variable: String) throws -> Bool {
        if let type = variables[variable] {
            return type.1
        }
        guard let enclosing = enclosing, !closed else {
            // TODO: We could find similarly named variables here and suggest
            // them
            throw ScopeError(message: "Couldn't find variable '\(variable)' in the current scope.")
        }
        return try enclosing.isMut(variable: variable)
    }

    func add(variable: String, type: MooseType, mutable: Bool) throws {
        guard !variables.contains(where: { name, store in
            name == variable && store.0 == type
        })
        else {
            throw ScopeError(message: "'\(variable)' with type '\(type)' is already in scope.")
        }
        variables[variable] = (type, mutable)
    }
}

// Define all op specific function
extension TypeScope {
    private func isOpBy(pos: OpPos, params: [MooseType], other: (MooseType, OpPos)) -> Bool {
        let storedParams = (other.0 as? FunctionType)?.params
        guard let storedParams = storedParams else { return false }

        return TypeScope.leftSuperOfRight(supers: storedParams, subtypes: params)
            && pos == other.1
    }

    private func currentContains(op: String, opPos: OpPos, params: [MooseType]) -> Bool {
        guard let hits = ops[op] else {
            return false
        }
        return hits.contains {
            isOpBy(pos: opPos, params: params, other: $0)
        }
    }

    func typeOf(op: String, opPos: OpPos, params: [MooseType]) throws -> (MooseType, OpPos) {
        if let type = ops[op]?
            .first(where: { isOpBy(pos: opPos, params: params, other: $0) })
        {
            return type
        }
        guard let enclosing = enclosing, !closed else {
            throw ScopeError(message: "Operator '\(op)' with params (\(params.map { $0.description }.joined(separator: ","))) isn't defined.")
        }
        return try enclosing.typeOf(op: op, opPos: opPos, params: params)
    }

    func returnType(op: String, opPos: OpPos, params: [MooseType]) throws -> MooseType {
        guard let retType = (try typeOf(op: op, opPos: opPos, params: params).0 as? FunctionType)?.returnType else {
            fatalError("INTERNAL ERROR: MooseType is not of type .Function")
        }
        return retType
    }

    func has(op: String, opPos: OpPos, params: [MooseType], includeEnclosing: Bool = true) -> Bool {
        if currentContains(op: op, opPos: opPos, params: params) {
            return true
        }
        guard includeEnclosing, let enclosing = enclosing, !closed else {
            return false
        }
        return enclosing.has(op: op, opPos: opPos, params: params, includeEnclosing: includeEnclosing)
    }

    func add(op: String, opPos: OpPos, params: [ParamType], returnType: MooseType) throws {
        let inCurrent = currentContains(op: op, opPos: opPos, params: params)
        guard !inCurrent else {
            throw ScopeError(message: "Operator '\(op)' with params (\(params.map { $0.description }.joined(separator: ","))) is alraedy defined.")
        }

        var list = (ops[op] ?? [])
        list.append((FunctionType(params: params, returnType: returnType), opPos))
        ops.updateValue(list, forKey: op)
    }
}

extension TypeScope {
    /// A function has to have same params OR the given params to check is .Nil
    ///
    ///  @params Parameter to check against (could contain .Nil params)
    ///  @other Function to check aganst
    private func isFuncBy(params: [MooseType], other: MooseType) -> Bool {
        guard
            let storedParams = (other as? FunctionType)?.params
        else {
            return false
        }

        return TypeScope.leftSuperOfRight(supers: storedParams, subtypes: params)
    }

    private func currentContains(function: String, params: [MooseType]) -> Bool {
        guard let hits = funcs[function] else {
            return false
        }
        return hits.contains {
            isFuncBy(params: params, other: $0)
        }
    }

    func typeOf(function: String, params: [MooseType]) throws -> MooseType {
        if let types = funcs[function]?
            .filter({ isFuncBy(params: params, other: $0) })
        {
            if types.count > 1 {
                throw ScopeError(message: "Multiple possible functions of `\(function)` with params (\(params.map { $0.description }.joined(separator: ","))). You have to give more context to the function call.")
            }
            if types.count == 1 {
                return types.first!
            }
        }
        guard let enclosing = enclosing, !closed else {
            throw ScopeError(message: "Function '\(function)' with params (\(params.map { $0.description }.joined(separator: ","))) isn't defined.")
        }
        return try enclosing.typeOf(function: function, params: params)
    }

    func returnType(function: String, params: [MooseType]) throws -> MooseType {
        guard let retType = (try typeOf(function: function, params: params) as? FunctionType)?.returnType else {
            fatalError("INTERNAL ERROR: MooseType is not of type .Function")
        }
        return retType
    }

    func has(function: String, params: [MooseType], includeEnclosing: Bool = true) -> Bool {
        if currentContains(function: function, params: params) {
            return true
        }
        guard includeEnclosing, let enclosing = enclosing, !closed else {
            return false
        }
        return enclosing.has(function: function, params: params, includeEnclosing: includeEnclosing)
    }

    func add(function: String, params: [ParamType], returnType: MooseType) throws {
        let inCurrent = currentContains(function: function, params: params)
        guard !inCurrent else {
            throw ScopeError(message: "Function '\(function)' with params (\(params.map { $0.description }.joined(separator: ","))) is already defined.")
        }
        var list = (funcs[function] ?? [])
        list.append(FunctionType(params: params, returnType: returnType))
        funcs.updateValue(list, forKey: function)
    }
}

extension TypeScope {
    func isGlobal() -> Bool {
        return enclosing == nil && !closed
    }
}

extension TypeScope {
    func add(clas: String, scope: ClassTypeScope) throws {
        guard !has(clas: clas) else {
            throw ScopeError(message: "Class with name '\(clas)' does already exist. Class names must be unique.")
        }

        classes[clas] = scope
    }

    func has(clas: String) -> Bool {
        return classes.contains(where: { $0.key == clas })
    }

    func getScope(clas: String) -> ClassTypeScope? {
        if let clasScope = classes[clas] {
            return clasScope
        }

        return closed ? nil : enclosing?.getScope(clas: clas)
    }

    /// returns next enclosing class type scope and nil if there is no class type scope
    func nearestClassScope() -> ClassTypeScope? {
        guard let scope = self as? ClassTypeScope else {
            return closed ? nil : enclosing?.nearestClassScope()
        }
        return scope
    }

    var variableCount: Int {
        return variables.count
    }

    /// Determines if left types are all super types of right types
    ///
    /// This is used e.g. to find functions with generic params
    static func leftSuperOfRight(supers: [MooseType], subtypes: [MooseType]) -> Bool {
        return subtypes.count == supers.count &&
            zip(subtypes, supers)
            .reduce(true) { acc, zip in
                let (subtype, supr) = zip
                guard subtype is NilType || supr.superOf(type: subtype) else { return false }
                return acc
            }
    }
}

/// Class Scope specific methods
/// Also holds the corresponding ast class node
class ClassTypeScope: TypeScope {
    typealias propType = (name: String, type: MooseType, mutable: Bool)

    let className: String
    var classProperties: [propType]
    var superClass: ClassTypeScope?
    var visited = false

    init(enclosing: TypeScope? = nil, name: String, properties: [propType]) {
        className = name
        classProperties = properties
        super.init(enclosing: enclosing)
    }

    /// Here we are flatting the class, so we are creating one class that is build-up from all
    /// respecting all inherited properties
    ///
    /// This function is called by the typechecker, so after all classes are checked, they all have nil as superclass and all have their respective functions and variables
    func flat() throws {
        guard let superClass = superClass else { return }
        try superClass.flat()

        // Check if class holds property that is also defined in super class
        try classProperties.forEach { name, _, _ in
            guard !superClass.classProperties.contains(where: { name == $0.name }) else {
                throw ScopeError(message: "Property `\(name)` cannot be overwritten by `\(className)`.")
            }
        }
        classProperties += superClass.classProperties
        var vars = superClass.variables
        variables.forEach { vars[$0.key] = $0.value }
        variables = vars

        var fns = superClass.funcs
        for (name, fns) in funcs {
            for fn in fns {
                if let fn = fn as? FunctionType {
                    if superClass.has(function: name, params: fn.params, includeEnclosing: false) {
                        let superRettype = try superClass.returnType(function: name, params: fn.params)
                        guard fn.returnType == superRettype else {
                            throw ScopeError(message: "Function `\(name)(\(fn.params.map { $0.description }.joined(separator: ","))) > \(fn.returnType)` of class \(className) does not match return type \(fn.returnType) of superclass.")
                        }
                    }
                }
            }
        }
        fns.forEach { fns[$0.key] = $0.value }
        funcs = fns
    }

    var propertyCount: Int {
        return super.variableCount
    }
}
