//
//  PaginationServiceTests.swift
//  LengyanTests
//
//  Comprehensive tests for PaginationService
//  Target: 95% test coverage
//

import XCTest
import Quick
import Nimble

@testable import LengyanCore

final class PaginationServiceTests: QuickSpec {
    override class func spec() {
        describe("PaginationService") {
            var sutras: [Sutra]!
            var service: PaginationService!

            beforeEach {
                sutras = [
                    Sutra(path: "/A1/B1/C1", name: "First", type: .content),
                    Sutra(path: "/A1/B1/C2", name: "Second", type: .content),
                    Sutra(path: "/A1/B1/C3", name: "Third", type: .content),
                    Sutra(path: "/A1/B2/C1", name: "Fourth", type: .content),
                    Sutra(path: "/A2/B1/C1", name: "Fifth", type: .content),
                ]
                service = PaginationService(sutras: sutras)
            }

            // MARK: - Next Page Tests

            describe("nextPage(from:)") {
                it("should return next page for middle item") {
                    let next = service.nextPage(from: "/A1/B1/C2")
                    expect(next).to(equal("/A1/B1/C3"))
                }

                it("should return nil for last item") {
                    let next = service.nextPage(from: "/A2/B1/C1")
                    expect(next).to(beNil())
                }

                it("should return first item for first item") {
                    let next = service.nextPage(from: "/A1/B1/C1")
                    expect(next).to(equal("/A1/B1/C2"))
                }

                it("should return nil for non-existent path") {
                    let next = service.nextPage(from: "/XYZ")
                    expect(next).to(beNil())
                }
            }

            // MARK: - Previous Page Tests

            describe("previousPage(from:)") {
                it("should return previous page for middle item") {
                    let previous = service.previousPage(from: "/A1/B1/C2")
                    expect(previous).to(equal("/A1/B1/C1"))
                }

                it("should return nil for first item") {
                    let previous = service.previousPage(from: "/A1/B1/C1")
                    expect(previous).to(beNil())
                }

                it("should return second to last for last item") {
                    let previous = service.previousPage(from: "/A2/B1/C1")
                    expect(previous).to(equal("/A1/B2/C1"))
                }
            }

            // MARK: - Boundary Tests

            describe("isFirstPage(_:)") {
                it("should return true for first page") {
                    let isFirst = service.isFirstPage("/A1/B1/C1")
                    expect(isFirst).to(beTrue())
                }

                it("should return false for other pages") {
                    let isFirst = service.isFirstPage("/A1/B1/C2")
                    expect(isFirst).to(beFalse())
                }
            }

            describe("isLastPage(_:)") {
                it("should return true for last page") {
                    let isLast = service.isLastPage("/A2/B1/C1")
                    expect(isLast).to(beTrue())
                }

                it("should return false for other pages") {
                    let isLast = service.isLastPage("/A1/B1/C3")
                    expect(isLast).to(beFalse())
                }
            }

            // MARK: - Page Number Tests

            describe("pageNumber(for:)") {
                it("should return correct 1-based page number") {
                    let pageNumber = service.pageNumber(for: "/A1/B1/C1")
                    expect(pageNumber).to(equal(1))
                }

                it("should return correct page number for middle item") {
                    let pageNumber = service.pageNumber(for: "/A1/B1/C3")
                    expect(pageNumber).to(equal(3))
                }

                it("should return correct page number for last item") {
                    let pageNumber = service.pageNumber(for: "/A2/B1/C1")
                    expect(pageNumber).to(equal(5))
                }

                it("should return nil for non-existent path") {
                    let pageNumber = service.pageNumber(for: "/XYZ")
                    expect(pageNumber).to(beNil())
                }
            }

            // MARK: - Total Count Tests

            describe("totalPages") {
                it("should return correct total page count") {
                    expect(service.totalPages).to(equal(5))
                }

                it("should return 0 for empty sutras") {
                    let emptyService = PaginationService(sutras: [])
                    expect(emptyService.totalPages).to(equal(0))
                }
            }
        }

        // MARK: - Complex Path Tests

        describe("PaginationService with complex paths") {
            var service: PaginationService!

            beforeEach {
                let complexSutras = [
                    Sutra(path: "/A1", name: "Chapter 1", type: .chapter),
                    Sutra(path: "/A1/B1", name: "Section 1.1", type: .section),
                    Sutra(path: "/A1/B1/C1", name: "Content 1.1.1", type: .content),
                    Sutra(path: "/A1/B1/C2", name: "Content 1.1.2", type: .content),
                    Sutra(path: "/A1/B2", name: "Section 1.2", type: .section),
                    Sutra(path: "/A1/B2/C1", name: "Content 1.2.1", type: .content),
                    Sutra(path: "/A2", name: "Chapter 2", type: .chapter),
                    Sutra(path: "/A2/B1", name: "Section 2.1", type: .section),
                    Sutra(path: "/A2/B1/C1", name: "Content 2.1.1", type: .content),
                ]
                service = PaginationService(sutras: complexSutras)
            }

            it("should handle complex hierarchical paths") {
                expect(service.nextPage(from: "/A1/B1/C1")).to(equal("/A1/B1/C2"))
                expect(service.nextPage(from: "/A1/B1/C2")).to(equal("/A1/B2/C1"))
                expect(service.nextPage(from: "/A1/B2/C1")).to(equal("/A2"))
                expect(service.nextPage(from: "/A2/B1/C1")).to(beNil())
            }

            it("should handle backward navigation correctly") {
                expect(service.previousPage(from: "/A1/B2/C1")).to(equal("/A1/B1/C2"))
                expect(service.previousPage(from: "/A1/B1/C2")).to(equal("/A1/B1/C1"))
                expect(service.previousPage(from: "/A1/B1/C1")).to(equal("/A1/B1"))
            }
        }
    }
}
