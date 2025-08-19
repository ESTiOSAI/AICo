//
//  RecommendViewModelTests.swift
//  AIProjectTests
//
//  Created by 강대훈 on 8/18/25.
//

import XCTest
@testable import AIProject

struct AlanServiceStub: AlanRecommendServiceProtocol {
    enum Fixtures {
        static let recommendDTOs: [RecommendCoinDTO] = [
            .init(name: "메이플 파이낸스", symbol: "KRW-SYRUP", comment: "A"),
            .init(name: "비트코인", symbol: "KRW-BTC",   comment: "B"),
            .init(name: "이더리움", symbol: "KRW-ETH",   comment: "C"),
            .init(name: "리플", symbol: "KRW-XRP",   comment: "D"),
            .init(name: "아발란체", symbol: "KRW-AVAX",  comment: "E"),
            .init(name: "테스트1", symbol: "KRW-TEST1",  comment: "T1"),
            .init(name: "테스트2", symbol: "KRW-TEST2",  comment: "T2"),
        ]
    }

    var result: Result<[RecommendCoinDTO], Error> = .success(Fixtures.recommendDTOs)
    var delay: Duration = .zero
    var isError: Bool = false

    func fetchRecommendCoins(preference: String, bookmarkCoins: String) async throws -> [RecommendCoinDTO] {
        if delay > .zero {
            try await Task.sleep(for: delay)
        }

        if isError {
            throw NetworkError.invalidAPIKey
        }

        return try result.get()
    }
}

final class RecommendCoinViewModelTests: XCTestCase {
    var sut: RecommendCoinViewModel!
    var sutWithError: RecommendCoinViewModel!

    var alanStub: AlanServiceStub!
    var alanStubWithError: AlanServiceStub!

    override func setUp() {
        super.setUp()
        alanStub = AlanServiceStub(result: .success(AlanServiceStub.Fixtures.recommendDTOs), delay: .seconds(2))
        sut = RecommendCoinViewModel(alanService: alanStub)
        alanStubWithError = AlanServiceStub(result: .success(AlanServiceStub.Fixtures.recommendDTOs), delay: .seconds(2), isError: true)
        sutWithError = RecommendCoinViewModel(alanService: alanStubWithError)
    }

    override func tearDown() {
        super.tearDown()
        sut = nil
        sutWithError = nil

        alanStub = nil
        alanStubWithError = nil
    }

    func test_taskCancelsProperly() async {
        await sut.cancelTask()

        await MainActor.run {
            XCTAssertTrue(sut.recommendCoins.isEmpty)

            guard case .cancel(.taskCancelled) = sut.status else {
                XCTFail("Expected .cancel(.taskCancelled), But got \(sut.status)")
                return
            }
        }
    }

    func test_taskCompletesSuccessfully() async {
        await sut.task?.value

        await MainActor.run {
            XCTAssertTrue(sut.recommendCoins.count == 5)

            guard case .success = sut.status else {
                XCTFail("Expected .success, But got \(sut.status)")
                return
            }
        }
    }

    func test_whenErrorOccurs_errorIsHandled() async {
        await sutWithError.task?.value

        await MainActor.run {
            XCTAssertTrue(sut.recommendCoins.isEmpty)

            guard case .failure(.invalidAPIKey) = sutWithError.status else {
                XCTFail("Expected .failure, But got \(sut.status)")
                return
            }
        }
    }
}
