//
//  ProcedureKit
//
//  Copyright © 2016 ProcedureKit. All rights reserved.
//

import XCTest
import TestingProcedureKit
@testable import ProcedureKit

class GroupTests: GroupTestCase {

    // MARK: - Basic Group Tests

    func test__group_has_user_intent_set_from_input_operations() {
        let child = TestProcedure()
        child.userIntent = .initiated
        group = TestGroupProcedure(operations: [child, TestProcedure(), BlockOperation { }])
        XCTAssertEqual(group.userIntent, .initiated)
    }

    func test__group_sets_user_intent_on_children() {
        let child1 = TestProcedure()
        child1.userIntent = .initiated
        let child2 = TestProcedure()
        let child3 = BlockOperation { }
        group = TestGroupProcedure(operations: [child1, child2, child3])
        group.userIntent = .sideEffect

        XCTAssertEqual(child1.userIntent, .sideEffect)
        XCTAssertEqual(child2.userIntent, .sideEffect)
        XCTAssertEqual(child3.qualityOfService, .userInitiated)
    }

    // MARK: - Execution

    func test__group_children_are_executed() {
        wait(for: group)

        XCTAssertTrue(group.isFinished)
        for child in group.children {
            XCTAssertTrue(child.isFinished)
        }
        for testProcedures in group.children.flatMap({ $0 as? TestProcedure }) {
            XCTAssertTrue(testProcedures.didExecute)
        }
    }

    func test__group_adding_operation_to_running_group() {
        let extra = TestProcedure(name: "Extra child")

        check(procedure: group) { $0.add(child: extra) }

        XCTAssertTrue(group.isFinished)
        XCTAssertTrue(extra.didExecute)
    }

    func test__group_only_adds_initial_operations_to_children_property_once() {
        wait(for: group)
        XCTAssertEqual(group.children, children)
    }

    func test_group_will_add_child_observer_is_called() {
        var blockCalledWith: (GroupProcedure, Operation)? = nil
        group = TestGroupProcedure(operations: [children[0]])
        group.addWillAddChildBlockObserver { group, child in
            blockCalledWith = (group, child)
        }
        wait(for: group)
        guard let (observedGroup, observedChild) = blockCalledWith else { XCTFail("Observer not called"); return }
        XCTAssertEqual(observedGroup, group)
        XCTAssertEqual(observedChild, children[0])
    }

    func test_group_did_add_child_observer_is_called() {
        var blockCalledWith: (GroupProcedure, Operation)? = nil
        group = TestGroupProcedure(operations: [children[0]])
        group.addDidAddChildBlockObserver { group, child in
            blockCalledWith = (group, child)
        }
        wait(for: group)
        guard let (observedGroup, observedChild) = blockCalledWith else { XCTFail("Observer not called"); return }
        XCTAssertEqual(observedGroup, group)
        XCTAssertEqual(observedChild, children[0])
    }

    func test__group_is_not_suspended_at_start() {
        XCTAssertFalse(group.isSuspended)
    }

    func test__group_suspended_before_execute() {
        let child = children[0]
        group = TestGroupProcedure(operations: [child])
        group.isSuspended = true

        let childWillExecuteDispatchGroup = DispatchGroup()
        childWillExecuteDispatchGroup.enter()
        child.addWillExecuteBlockObserver { _ in
            childWillExecuteDispatchGroup.leave()
        }

        let groupWillExecuteDispatchGroup = DispatchGroup()
        groupWillExecuteDispatchGroup.enter()
        group.addWillExecuteBlockObserver { _ in
            groupWillExecuteDispatchGroup.leave()
        }

        check(procedure: group) { group in

            XCTAssertEqual(groupWillExecuteDispatchGroup.wait(timeout: DispatchTime.now() + 0.01), .success, "Group has not yet executed")

            XCTAssertNotEqual(childWillExecuteDispatchGroup.wait(timeout: DispatchTime.now() + 0.005), .success, "Child executed when group was suspended")

            XCTAssertFalse(child.isFinished)
            XCTAssertFalse(group.isFinished)

            group.isSuspended = false
        }

        XCTAssertTrue(child.isFinished)
        XCTAssertTrue(group.isFinished)
    }

    // MARK: - Error Tests

    func test__group_exits_correctly_when_child_errors() {
        children = createTestProcedures(shouldError: true)
        group = TestGroupProcedure(operations: children)

        wait(for: group)

        XCTAssertEqual(group.errors.count, children.count)
    }

    func test__group_exits_correctly_when_child_group_finishes_with_errors() {
        children = createTestProcedures(shouldError: true)
        let child = TestGroupProcedure(operations: children); child.name = "Child Group"
        group = TestGroupProcedure(operations: child)

        wait(for: group)
        XCTAssertEqual(child.errors.count, children.count)
        XCTAssertEqual(group.errors.count, 5)
    }

    // MARK: - Cancellation Tests

    func test__group_cancels_children() {
        group.cancel()
        for child in group.children {
            XCTAssertTrue(child.isCancelled)
        }
    }

    func test__group_cancels_children_when_running() {
        check(procedure: group) { $0.cancel() }
        XCTAssertTrue(group.isCancelled)
    }

    func test__group_execute_is_called_when_cancelled_before_running() {
        group.cancel()
        XCTAssertFalse(group.didExecute)

        wait(for: group)

        XCTAssertTrue(group.isCancelled)
        XCTAssertTrue(group.didExecute)
        XCTAssertTrue(group.isFinished)
    }

    func test__group_cancel_with_errors_does_not_collect_errors_sent_to_children() {
        check(procedure: group) { $0.cancel(withError: TestError()) }
        XCTAssertProcedureCancelledWithErrors(group, count: 1)
    }

    // MARK: - Finishing Tests

    func test__group_does_not_finish_before_all_children_finish() {
        var didFinishBlockObserverWasCalled = false
        group.addWillFinishBlockObserver { group, _ in
            didFinishBlockObserverWasCalled = true
            for child in group.children {
                XCTAssertTrue(child.isFinished)
            }
        }
        wait(for: group)
        XCTAssertTrue(group.isFinished)
        XCTAssertTrue(didFinishBlockObserverWasCalled)
    }

    // MARK: - Condition Tests
}

class GroupConcurrencyTests: GroupConcurrencyTestCase {

    // MARK: - MaxConcurrentOperationCount Tests

    func test__group_maxConcurrentOperationCount_1() {
        let children: Int = 3
        let delayMicroseconds: useconds_t = 500000 // 0.5 seconds
        let timeout: TimeInterval = 4
        concurrencyTestGroup(children: children, withDelayMicroseconds: delayMicroseconds, withTimeout: timeout,
            withConfigureBlock: { (group) in
                group.maxConcurrentOperationCount = 1
            },
            withExpectations: Expectations(
                checkMinimumDetected: 1,
                checkMaximumDetected: 1,
                checkAllProceduresFinished: true,
                checkMinimumDuration: TimeInterval(useconds_t(children) * delayMicroseconds) / 1000000.0
            )
        )
    }

    func test__group_operation_maxConcurrentOperationCount_2() {
        let children: Int = 3
        let delayMicroseconds: useconds_t = 500000 // 0.5 seconds
        let timeout: TimeInterval = 3
        concurrencyTestGroup(children: children, withDelayMicroseconds: delayMicroseconds, withTimeout: timeout,
            withConfigureBlock: { (group) in
                group.maxConcurrentOperationCount = 2
            },
            withExpectations: Expectations(
                checkMinimumDetected: 1,
                checkMaximumDetected: 2,
                checkAllProceduresFinished: true
            )
        )
    }
}

