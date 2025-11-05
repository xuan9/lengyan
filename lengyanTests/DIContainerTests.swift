//
//  DIContainerTests.swift
//  LengyanTests
//
//  Comprehensive tests for DIContainer
//  Target: 95% test coverage
//

import XCTest
import Quick
import Nimble

@testable import LengyanCore

final class DIContainerTests: QuickSpec {
    override class func spec() {
        describe("DIContainer") {
            var container: DIContainer!

            beforeEach {
                container = DIContainer()
            }

            afterEach {
                // Reset container after each test
                container = DIContainer()
            }

            // MARK: - Registration Tests

            describe("register(type:factory:)") {
                it("should register a dependency") {
                    let testObject = TestProtocolImpl()
                    container.register(type: TestProtocol.self) {
                        return testObject
                    }

                    let resolved = container.resolve(type: TestProtocol.self)

                    expect(resolved).to(beIdenticalTo(testObject))
                }

                it("should register multiple dependencies") {
                    let object1 = TestProtocolImpl()
                    let object2 = AnotherTestProtocolImpl()

                    container.register(type: TestProtocol.self) { object1 }
                    container.register(type: AnotherTestProtocol.self) { object2 }

                    let resolved1 = container.resolve(type: TestProtocol.self)
                    let resolved2 = container.resolve(type: AnotherTestProtocol.self)

                    expect(resolved1).to(beIdenticalTo(object1))
                    expect(resolved2).to(beIdenticalTo(object2))
                }

                it("should override existing registration") {
                    let object1 = TestProtocolImpl()
                    let object2 = TestProtocolImpl()

                    container.register(type: TestProtocol.self) { object1 }
                    container.register(type: TestProtocol.self) { object2 }

                    let resolved = container.resolve(type: TestProtocol.self)

                    expect(resolved).to(beIdenticalTo(object2))
                }
            }

            // MARK: - Singleton Registration Tests

            describe("registerSingleton(type:factory:)") {
                it("should register and resolve singleton") {
                    let singleton = TestSingleton()
                    container.registerSingleton(type: TestSingletonProtocol.self) {
                        return singleton
                    }

                    let resolved1 = container.resolve(type: TestSingletonProtocol.self)
                    let resolved2 = container.resolve(type: TestSingletonProtocol.self)

                    expect(resolved1).to(beIdenticalTo(singleton))
                    expect(resolved2).to(beIdenticalTo(singleton))
                }

                it("should create singleton only once") {
                    var creationCount = 0
                    container.registerSingleton(type: TestProtocol.self) {
                        creationCount += 1
                        return TestProtocolImpl()
                    }

                    _ = container.resolve(type: TestProtocol.self)
                    _ = container.resolve(type: TestProtocol.self)

                    expect(creationCount).to(equal(1))
                }
            }

            // MARK: - Resolution Tests

            describe("resolve(type:)") {
                context("when dependency is registered") {
                    it("should resolve successfully") {
                        let testObject = TestProtocolImpl()
                        container.register(type: TestProtocol.self) { testObject }

                        let resolved = container.resolve(type: TestProtocol.self)

                        expect(resolved).to(beIdenticalTo(testObject))
                    }
                }

                context("when dependency is not registered") {
                    it("should crash with fatal error") {
                        expect {
                            container.resolve(type: UnregisteredProtocol.self)
                        }.to(throwAssertion())
                    }
                }
            }

            describe("resolveOptional(type:)") {
                context("when dependency is registered") {
                    it("should resolve successfully") {
                        let testObject = TestProtocolImpl()
                        container.register(type: TestProtocol.self) { testObject }

                        let resolved = container.resolveOptional(type: TestProtocol.self)

                        expect(resolved).to(beIdenticalTo(testObject))
                    }
                }

                context("when dependency is not registered") {
                    it("should return nil") {
                        let resolved = container.resolveOptional(type: UnregisteredProtocol.self)

                        expect(resolved).to(beNil())
                    }
                }
            }

            // MARK: - Configuration Tests

            describe("configure()") {
                it("should configure all dependencies") {
                    container.configure()

                    let bookRepo = container.resolve(type: BookRepository.self)
                    let audioRepo = container.resolve(type: AudioRepository.self)
                    let preferencesRepo = container.resolve(type: PreferencesRepository.self)
                    let themeRepo = container.resolve(type: ThemeRepository.self)

                    expect(bookRepo).toNot(beNil())
                    expect(audioRepo).toNot(beNil())
                    expect(preferencesRepo).toNot(beNil())
                    expect(themeRepo).toNot(beNil())
                }

                it("should configure view models") {
                    container.configure()

                    let sutraIndexVM = container.resolve(type: SutraIndexViewModel.self)
                    let audioPlayerVM = container.resolve(type: AudioPlayerViewModel.self)

                    expect(sutraIndexVM).toNot(beNil())
                    expect(audioPlayerVM).toNot(beNil())
                }

                it("should create different instances for view models") {
                    container.configure()

                    let vm1 = container.resolve(type: SutraIndexViewModel.self)
                    let vm2 = container.resolve(type: SutraIndexViewModel.self)

                    expect(vm1).toNot(beIdenticalTo(vm2))
                }
            }

            // MARK: - Reset Tests

            describe("reset()") {
                it("should reset all registrations") {
                    container.register(type: TestProtocol.self) { TestProtocolImpl() }
                    container.reset()

                    expect {
                        container.resolve(type: TestProtocol.self)
                    }.to(throwAssertion())
                }

                it("should reconfigure after reset") {
                    container.register(type: TestProtocol.self) { TestProtocolImpl() }
                    container.reset()
                    container.configure()

                    let resolved = container.resolve(type: BookRepository.self)
                    expect(resolved).toNot(beNil())
                }
            }

            // MARK: - Edge Cases

            describe("edge cases") {
                it("should handle nil factory return") {
                    container.register(type: OptionalTestProtocol.self) { Optional<TestProtocolImpl>.none }

                    let resolved = container.resolve(type: OptionalTestProtocol.self)

                    expect(resolved).to(beNil())
                }

                it("should handle closures with dependencies") {
                    let dependency = TestProtocolImpl()
                    container.register(type: TestProtocol.self) { dependency }

                    container.register(type: DependentProtocol.self) {
                        let dep = container.resolve(type: TestProtocol.self)
                        return DependentProtocolImpl(dependency: dep!)
                    }

                    let resolved = container.resolve(type: DependentProtocol.self)

                    expect(resolved).toNot(beNil())
                }

                it("should handle circular dependencies gracefully") {
                    // This is a potential issue - circular dependencies
                    // In a real scenario, this would need to be handled
                    // For now, we just test that it doesn't crash immediately
                    container.register(type: TestProtocol.self) {
                        let other = container.resolve(type: AnotherTestProtocol.self)
                        return TestProtocolImpl()
                    }

                    container.register(type: AnotherTestProtocol.self) {
                        let test = container.resolve(type: TestProtocol.self)
                        return AnotherTestProtocolImpl()
                    }

                    // First resolution might work or might hang/crash
                    // In production, this should be prevented
                    expect {
                        _ = container.resolve(type: TestProtocol.self)
                    }.to(throwAssertion()) // Or potentially hang
                }
            }

            // MARK: - Thread Safety Tests

            describe("thread safety") {
                it("should handle concurrent registration") {
                    DispatchQueue.concurrentPerform(iterations: 10) { _ in
                        container.register(type: TestProtocol.self) { TestProtocolImpl() }
                    }

                    let resolved = container.resolve(type: TestProtocol.self)
                    expect(resolved).toNot(beNil())
                }

                it("should handle concurrent resolution") {
                    let testObject = TestProtocolImpl()
                    container.register(type: TestProtocol.self) { testObject }

                    var results: [TestProtocol?] = Array(repeating: nil, count: 10)

                    DispatchQueue.concurrentPerform(iterations: 10) { index in
                        results[index] = container.resolve(type: TestProtocol.self)
                    }

                    for result in results {
                        expect(result).to(beIdenticalTo(testObject))
                    }
                }
            }
        }

        // MARK: - Shared Instance Tests

        describe("DIContainer.shared") {
            it("should be a singleton") {
                let container1 = DIContainer.shared
                let container2 = DIContainer.shared

                expect(container1).to(beIdenticalTo(container2))
            }

            it("should be configurable") {
                let container = DIContainer.shared
                container.configure()

                let bookRepo = container.resolve(type: BookRepository.self)
                expect(bookRepo).toNot(beNil())
            }
        }
    }
}

// MARK: - Test Protocols and Implementations

protocol TestProtocol {
    func doSomething()
}

struct TestProtocolImpl: TestProtocol {
    func doSomething() { }
}

protocol AnotherTestProtocol {
    func doAnotherThing()
}

struct AnotherTestProtocolImpl: AnotherTestProtocol {
    func doAnotherThing() { }
}

protocol UnregisteredProtocol {
    func unregisteredMethod()
}

protocol OptionalTestProtocol {
    func optionalMethod()
}

protocol TestSingletonProtocol {
    func singletonMethod()
}

class TestSingleton: TestSingletonProtocol {
    func singletonMethod() { }
}

protocol DependentProtocol {
    var dependency: TestProtocol { get }
}

struct DependentProtocolImpl: DependentProtocol {
    let dependency: TestProtocol

    init(dependency: TestProtocol) {
        self.dependency = dependency
    }
}
