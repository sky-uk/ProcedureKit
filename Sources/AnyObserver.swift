//
//  ProcedureKit
//
//  Copyright © 2016 ProcedureKit. All rights reserved.
//

class AnyObserverBox_<Procedure: ProcedureProtocol>: ProcedureObserver {
    func didAttach(to procedure: Procedure) { _abstractMethod() }
    func will(execute procedure: Procedure) { _abstractMethod() }
    func did(execute procedure: Procedure) { _abstractMethod() }
    func will(cancel procedure: Procedure, withErrors: [Error]) { _abstractMethod() }
    func did(cancel procedure: Procedure, withErrors errors: [Error]) { _abstractMethod() }
    func procedure(_ procedure: Procedure, didProduce newOperation: Operation) { _abstractMethod() }
    func will(finish procedure: Procedure, withErrors errors: [Error]) { _abstractMethod() }
    func did(finish procedure: Procedure, withErrors errors: [Error]) { _abstractMethod() }
}

class AnyObserverBox<Base: ProcedureObserver>: AnyObserverBox_<Base.Procedure> {
    private var base: Base
    
    init(_ base: Base) {
        self.base = base
    }
    
    override func didAttach(to procedure: Base.Procedure) {
        base.didAttach(to: procedure)
    }
    
    override func will(execute procedure: Base.Procedure) {
        base.will(execute: procedure)
    }
    
    override func did(execute procedure: Base.Procedure) {
        base.did(execute: procedure)
    }
    
    override func will(cancel procedure: Base.Procedure, withErrors errors: [Error]) {
        base.will(cancel: procedure, withErrors: errors)
    }
    
    override func did(cancel procedure: Base.Procedure, withErrors errors: [Error]) {
        base.did(cancel: procedure, withErrors: errors)
    }
    
    override func procedure(_ procedure: Base.Procedure, didProduce newOperation: Operation) {
        base.procedure(procedure, didProduce: newOperation)
    }
    
    override func will(finish procedure: Base.Procedure, withErrors errors: [Error]) {
        base.will(finish: procedure, withErrors: errors)
    }
    
    override func did(finish procedure: Base.Procedure, withErrors errors: [Error]) {
        base.did(finish: procedure, withErrors: errors)
    }
}

internal class TransformObserver<O: ProcedureProtocol, R: ProcedureProtocol>: ProcedureObserver {
    private typealias Erased = AnyObserverBox_<O>
    public typealias Procedure = R
    
    private var wrapped: Erased
    private var procedureTransformBlock: (R) -> O?
    init<Base: ProcedureObserver>(base: Base, procedureTransformBlock: @escaping (R) -> O? = { return $0 as? O }) where O == Base.Procedure {
        wrapped = AnyObserverBox(base)
        self.procedureTransformBlock = procedureTransformBlock
    }
    
    private enum Event {
        case didAttach
        case willExecute
        case didExecute
        case didCancel
        case willAdd
        case didAdd
        case willFinish
        case didFinish
        
        var string: String {
            switch self {
            case .didAttach: return "didAttach"
            case .willExecute: return "willExecute"
            case .didExecute: return "didExecute"
            case .didCancel: return "didCancel"
            case .willAdd: return "procedureWillAdd"
            case .didAdd: return "procedureDidAdd"
            case .willFinish: return "willFinish"
            case .didFinish: return "didFinish"
            }
        }
    }
    
    private func typedProcedure(_ procedure: R, event: Event) -> O? {
        guard let typedProcedure = procedureTransformBlock(procedure) else {
            procedure.log.warning(message: ("Observer will not receive event (\(event.string)). Unable to convert \(procedure) to the expected type \"\(String(describing: O.self))\""))
            return nil
        }
        return typedProcedure
    }
    
    func didAttach(to procedure: Procedure) {
        guard let baseProcedure = typedProcedure(procedure, event: .didAttach) else { return }
        wrapped.didAttach(to: baseProcedure)
    }
    
    func will(execute procedure: Procedure) {
        guard let baseProcedure = typedProcedure(procedure, event: .willExecute) else { return }
        wrapped.will(execute: baseProcedure)
    }
    
    func did(execute procedure: Procedure) {
        guard let baseProcedure = typedProcedure(procedure, event: .didExecute) else { return }
        wrapped.did(execute: baseProcedure)
    }
    
    func did(cancel procedure: Procedure, withErrors errors: [Error]) {
        guard let baseProcedure = typedProcedure(procedure, event: .didCancel) else { return }
        wrapped.did(cancel: baseProcedure, withErrors: errors)
    }
    
    func will(finish procedure: Procedure, withErrors errors: [Error]) {
        guard let baseProcedure = typedProcedure(procedure, event: .willFinish) else { return }
        wrapped.will(finish: baseProcedure, withErrors: errors)
    }
    
    func did(finish procedure: Procedure, withErrors errors: [Error]) {
        guard let baseProcedure = typedProcedure(procedure, event: .didFinish) else { return }
        wrapped.did(finish: baseProcedure, withErrors: errors)
    }
}

public struct AnyObserver<Procedure: ProcedureProtocol>: ProcedureObserver {
    private typealias Erased = AnyObserverBox_<Procedure>
    
    private var box: Erased
    
    init<Base: ProcedureObserver>(base: Base) where Procedure == Base.Procedure {
        box = AnyObserverBox(base)
    }
    
    public func didAttach(to procedure: Procedure) {
        box.didAttach(to: procedure)
    }
    
    public func will(execute procedure: Procedure) {
        box.will(execute: procedure)
    }
    
    public func did(execute procedure: Procedure) {
        box.did(execute: procedure)
    }
    
    public func will(cancel procedure: Procedure, withErrors errors: [Error]) {
        box.will(cancel: procedure, withErrors: errors)
    }
    
    public func did(cancel procedure: Procedure, withErrors errors: [Error]) {
        box.did(cancel: procedure, withErrors: errors)
    }
    
    public func procedure(_ procedure: Procedure, didProduce newOperation: Operation) {
        box.procedure(procedure, didProduce: newOperation)
    }
    
    public func will(finish procedure: Procedure, withErrors errors: [Error]) {
        box.will(finish: procedure, withErrors: errors)
    }
    
    public func did(finish procedure: Procedure, withErrors errors: [Error]) {
        box.did(finish: procedure, withErrors: errors)
    }
}

