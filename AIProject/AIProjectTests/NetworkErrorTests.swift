//
//  NetworkErrorTests.swift
//  AIProjectTests
//
//  Created by 장지현 on 8/14/25.
//

import XCTest
@testable import AIProject

final class NetworkErrorTests: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testErrorDescription_returnsCorrectMessages() {
        let cancelled = NetworkError.taskCancelled
        let expectedCancelledMessage = "작업이 취소됐어요"

        let expectedDefaultMessage = "데이터를 불러오지 못했어요\n잠시 후 다시 시도해 주세요"
        let errors: [NetworkError] = [
            .invalidURL,
            .invalidResponse,
            .encodingError,
            .decodingError(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "테스트"))),
            .invalidAPIKey,
            .quotaExceeded(429),
            .notFound(404),
            .uriTooLong(414),
            .serviceUnavilable(503),
            .serverError(500),
            .remoteError(400, "에러"),
            .unknown(999),
            .webSocketError,
            .networkError(NSError(domain: "Test", code: 1))
        ]

        let cancelledMessage = cancelled.errorDescription

        XCTAssertEqual(cancelledMessage, expectedCancelledMessage)
        for error in errors {
            XCTAssertEqual(error.errorDescription, expectedDefaultMessage)
        }
    }
    
    func testLog_whenDecodingError_containsDebugDescriptionAndFileFunction() {
        let debugDescription = "Expected String but found Int"
        let decodingError = DecodingError.typeMismatch(String.self, .init(codingPath: [], debugDescription: debugDescription))
        let error = NetworkError.decodingError(decodingError)

        let logOutput = error.log(file: "FakeFile.swift", function: "fakeFunction()")

        XCTAssertTrue(logOutput.contains(debugDescription))
        XCTAssertTrue(logOutput.contains("FakeFile.swift#fakeFunction()"))
    }
}
