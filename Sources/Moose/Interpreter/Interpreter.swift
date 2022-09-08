//
// Created by flofriday on 31.05.22.
//

import Foundation

class Interpreter: Visitor {
    static let shared = Interpreter()

    var errors: [RuntimeError] = []
    var environment: Environment

    private init() {
        environment = BaseEnvironment(enclosing: nil)
        addBuiltIns()
    }

    /// Reset the internal state of the interpreter.
    func reset() {
        errors = []
        environment = BaseEnvironment(enclosing: nil)
        addBuiltIns()
    }

    func run(program: Program) throws {
        let explorer = GlobalEnvironmentExplorer(program: program, environment: environment)
        environment = try explorer.populate()

        let dependencyResolver = ClassDependencyResolverPass(program: program, environment: environment)
        environment = try dependencyResolver.populate()

        _ = try visit(program)
    }

    private func addBuiltIns() {
        for op in BuiltIns.builtInOperators {
            environment.set(op: op.name, value: op)
        }

        for fn in BuiltIns.builtInFunctions {
            environment.set(function: fn.name, value: fn)
        }
    }

    func pushEnvironment() {
        environment = BaseEnvironment(enclosing: environment)
    }

    func popEnvironment() {
        environment = environment.enclosing!
    }

    func visit(_ node: Program) throws -> MooseObject {
        for stmt in node.statements {
            _ = try stmt.accept(self)
        }
        return VoidObj()
    }

    private func assign(valueType: MooseType, dst: Assignable, value: MooseObject) throws {
        switch dst {
        case let id as Identifier:
            var newValue = value
            if let nilObj = value as? NilObj {
                newValue = try nilObj.toObject(type: valueType)
            }
            _ = environment.update(variable: id.value, value: newValue, allowDefine: true)

        case let tuple as Tuple:
            // TODO: many things can be unwrapped into tuples, like classes
            // and lists.
            switch valueType {
            case let t as TupleType:
                let types = t.entries
                let valueTuple = value as! TupleObj
                for (n, assignable) in tuple.assignables.enumerated() {
                    try assign(valueType: types[n], dst: assignable, value: valueTuple.value![n])
                }
            default:
                throw RuntimeError(message: "NOT IMPLEMENTED: can only parse identifiers and tuples for assign")
            }

        case let indexExpr as IndexExpression:
            let index = (try indexExpr.index.accept(self) as! IntegerObj).value
            guard var index = index else {
                throw NilUsagePanic(node: indexExpr.index)
            }

            let target = try indexExpr.indexable.accept(self) as! IndexWriteableObject

            // Negative index start counting form the back, just like Python
            if index < 0 {
                // this really is a substraction cause the index is negative
                index = target.length() + index
            }

            guard index >= 0, index < target.length() else {
                throw OutOfBoundsPanic(length: target.length(), attemptedIndex: index, node: indexExpr)
            }

            target.setAt(index: index, value: value)

        case let dereferExpr as Dereferer:
            let obj = try dereferExpr.obj.accept(self)

            let prevEnv = environment
            environment = obj.env
            let wasClosed = environment.closed
            environment.closed = true

            let val = try dereferExpr.referer.accept(self)
            try assign(valueType: val.type, dst: dereferExpr.referer as! Assignable, value: value)

            environment.closed = wasClosed
            environment = prevEnv

        default:
            throw RuntimeError(message: "NOT IMPLEMENTED: can only parse identifiers and tuples for assign")
        }
    }

    func visit(_ node: AssignStatement) throws -> MooseObject {
        let value = try node.value.accept(self)
        try assign(valueType: node.declaredType ?? node.value.mooseType!, dst: node.assignable, value: value)

        return VoidObj()
    }

    func visit(_ node: ReturnStatement) throws -> MooseObject {
        var value: MooseObject = VoidObj()
        if let returnValue = node.returnValue {
            value = try returnValue.accept(self)
        }
        throw ReturnSignal(value: value)
    }

    func visit(_ node: ExpressionStatement) throws -> MooseObject {
        _ = try node.expression.accept(self)
        return VoidObj()
    }

    func visit(_ node: BlockStatement) throws -> MooseObject {
        pushEnvironment()
        defer { popEnvironment() }

        for statement in node.statements {
            _ = try statement.accept(self)
        }

        return VoidObj()
    }

    func visit(_ node: FunctionStatement) throws -> MooseObject {
        // The global scope was already added by GlobalEnvironmentExplorer
        guard !environment.isGlobal() else {
            return VoidObj()
        }

        let paramNames = node.params.map { $0.name.value }
        let type = FunctionType(params: node.params.map { $0.declaredType }, returnType: node.returnType)
        let obj = FunctionObj(name: node.name.value, type: type, paramNames: paramNames, value: node.body, closure: environment)
        environment.set(function: obj.name, value: obj)
        return VoidObj()
    }

    func visit(_ node: OperationStatement) throws -> MooseObject {
        // The global scope was already added by GlobalEnvironmentExplorer
        guard !environment.isGlobal() else {
            return VoidObj()
        }

        let paramNames = node.params.map { $0.name.value }
        let params = node.params.map { $0.declaredType }
        let type = FunctionType(params: params, returnType: node.returnType)
        let obj = OperatorObj(name: node.name, opPos: node.position, type: type, paramNames: paramNames, value: node.body, closure: environment)
        environment.set(op: obj.name, value: obj)
        return VoidObj()
    }

    func visit(_: ClassStatement) throws -> MooseObject {
        // The global scope was already added by GlobalEnvironmentExplorer
        guard !environment.isGlobal() else {
            return VoidObj()
        }

        return VoidObj()
    }

    func visit(_ node: IfStatement) throws -> MooseObject {
        let conditionResult = try node.condition.accept(self) as! BoolObj

        guard let value = conditionResult.value else {
            throw NilUsagePanic(node: node.condition)
        }

        if value {
            _ = try node.consequence.accept(self)
        } else if let alternative = node.alternative {
            _ = try alternative.accept(self)
        }

        return VoidObj()
    }

    func visit(_ node: Identifier) throws -> MooseObject {
        return try environment.get(variable: node.value)
    }

    func visit(_ node: IntegerLiteral) throws -> MooseObject {
        return IntegerObj(value: node.value)
    }

    func visit(_ node: FloatLiteral) throws -> MooseObject {
        return FloatObj(value: node.value)
    }

    func visit(_ node: Boolean) throws -> MooseObject {
        return BoolObj(value: node.value)
    }

    func visit(_ node: StringLiteral) throws -> MooseObject {
        return StringObj(value: node.value)
    }

    func visit(_ node: Tuple) throws -> MooseObject {
        let args = try node.expressions.map { try $0.accept(self) }
        return TupleObj(type: node.mooseType!, value: args)
    }

    func visit(_ node: List) throws -> MooseObject {
        let args = try node.expressions.map { try $0.accept(self) }
        return ListObj(type: node.mooseType!, value: args)
    }

    func visit(_: Dict) throws -> MooseObject {
        fatalError("Not implemented")
    }

    func visit(_ node: Is) throws -> MooseObject {
        let obj = try node.expression.accept(self)
        if let obj = obj as? ClassObject {
            return BoolObj(value: obj.classEnv?.extends(clas: node.type.value).extends ?? false)
        }
        return BoolObj(value: obj.type.description == node.type.value)
    }

    func callFunctionOrOperator(callee: MooseObject, args: [MooseObject]) throws -> MooseObject {
        if let callee = callee as? BuiltInFunctionObj {
            // If the environment is already the class environment we do noting,
            // however, if it is not we set the current environment to the
            // global.
            let oldEnv = environment
            if !(environment is BuiltInClassEnvironment) {
                environment = environment.global()
            }

            // If the environment was previously closed we need to reopen it,
            // since functions can access variables in the enclosing scopes
            let wasClosed = environment.closed
            environment.closed = false

            // Restore the environments when at the end
            defer {
                environment.closed = wasClosed
                environment = oldEnv
            }

            // Execute the function
            return try callee.function(args, environment)

        } else if let callee = callee as? FunctionObj {
            // Activate the  environment in which the function was defined
            let oldEnv = environment
            environment = callee.closure

            // Open the environment, because it needs to access variables in the
            // enclosing scopes
            let wasClosed = environment.closed
            environment.closed = false
            pushEnvironment()

            // Reactivate the original environment at the end
            defer {
                popEnvironment()
                environment.closed = wasClosed
                environment = oldEnv
            }

            // Set all arguments
            let argPairs = Array(zip(callee.paramNames, args))
            for (name, value) in argPairs {
                _ = environment.updateInCurrentEnv(variable: name, value: value, allowDefine: true)
            }

            // Execute the body
            do {
                _ = try callee.value.accept(self)
            } catch let error as ReturnSignal {
                return error.value
            }

            return VoidObj()

        } else {
            throw RuntimeError(message: "I cannot call \(callee)!")
        }
    }

    func evaluateArgs(exprs: [Expression]) throws -> ([MooseObject], [MooseType]) {
        let wasClosed = environment.closed
        environment.closed = false
        let args = try exprs.map { try $0.accept(self) }
        let argTypes = exprs.map { $0.mooseType! }
        environment.closed = wasClosed
        return (args, argTypes)
    }

    func visit(_ node: PrefixExpression) throws -> MooseObject {
        let (args, argTypes) = try evaluateArgs(exprs: [node.right])

        let handler = try environment.get(op: node.op, pos: .Prefix, params: argTypes)
        do {
            return try callFunctionOrOperator(callee: handler, args: args)
        } catch let panic as Panic {
            panic.stacktrace.push(node: node)
            throw panic
        }
    }

    func visit(_ node: InfixExpression) throws -> MooseObject {
        let (args, argTypes) = try evaluateArgs(exprs: [node.left, node.right])

        let handler = try environment.get(op: node.op, pos: .Infix, params: argTypes)
        do {
            return try callFunctionOrOperator(callee: handler, args: args)
        } catch let panic as Panic {
            panic.stacktrace.push(node: node)
            throw panic
        }
    }

    func visit(_ node: PostfixExpression) throws -> MooseObject {
        let (args, argTypes) = try evaluateArgs(exprs: [node.left])

        let handler = try environment.get(op: node.op, pos: .Postfix, params: argTypes)
        do {
            return try callFunctionOrOperator(callee: handler, args: args)
        } catch let panic as Panic {
            panic.stacktrace.push(node: node)
            throw panic
        }
    }

    func visit(_: VariableDefinition) throws -> MooseObject {
        // The interpreter doesn't ever need to read this so it is ok to just
        // crash here.
        fatalError("Unreachable VariableDefinition in Interpreter")
    }

    func visit(_: Nil) throws -> MooseObject {
        return NilObj()
    }

    func visit(_ node: CallExpression) throws -> MooseObject {
        let (args, argTypes) = try evaluateArgs(exprs: node.arguments)

        if node.isConstructorCall {
            return try callConstructor(className: node.function.value, args: args)
        }

        let callee = try environment.get(function: node.function.value, params: argTypes)

        do {
            return try callFunctionOrOperator(callee: callee, args: args)
        } catch let panic as Panic {
            panic.stacktrace.push(node: node)
            throw panic
        }
    }

    private func callConstructor(className: String, args: [MooseObject]) throws -> MooseObject {
        let classDefinition = try environment.get(clas: className)
        // flat class definition to eliminate class hirachie
        classDefinition.flat()
        // create new object from definition
        let classObject = ClassEnvironment(copy: classDefinition)

        guard classObject.propertyNames.count == args.count else {
            throw EnvironmentError(message: "Args and property names have not same number of elements")
        }

        for (name, arg) in zip(classObject.propertyNames, args) {
            _ = classObject.updateInCurrentEnv(variable: name, value: arg)
        }

        // Bind all methods to this excat object
        classObject.bindMethods()

        return ClassObject(env: classObject, name: classObject.className)
    }

    func visit(_ node: Dereferer) throws -> MooseObject {
        let obj = try node.obj.accept(self)

        guard !obj.isNil else {
            throw RuntimeError(message: "Nullpointer Exception.")
        }

        let prevEnv = environment
        environment = obj.env
        let wasClosed = environment.closed
        environment.closed = true

        let val = try node.referer.accept(self)
        environment.closed = wasClosed
        environment = prevEnv
        return val
    }

    func visit(_ node: IndexExpression) throws -> MooseObject {
        let index = (try node.index.accept(self) as! IntegerObj).value
        guard var index = index else {
            throw NilUsagePanic(node: node.index)
        }

        let indexable = (try node.indexable.accept(self)) as! IndexableObject

        guard !indexable.isNil else {
            throw NilUsagePanic(node: node)
        }

        // Negative index start counting form the back, just like Python
        if index < 0 {
            // this really is a substraction cause the index is negative
            index = indexable.length() + index
        }

        guard index >= 0, index < indexable.length() else {
            throw OutOfBoundsPanic(length: indexable.length(), attemptedIndex: index, node: node)
        }
        return indexable.getAt(index: index)
    }

    func visit(_: Me) throws -> MooseObject {
        let env = try environment.nearestClass()
        return ClassObject(env: env, name: env.className)
    }
}
