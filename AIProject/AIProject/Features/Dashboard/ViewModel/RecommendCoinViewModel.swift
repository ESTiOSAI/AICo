//
//  DashboardViewModel.swift
//  AIProject
//
//  Created by 강대훈 on 8/1/25.
//

import SwiftUI

final class RecommendCoinViewModel: ObservableObject {
    /// 현재 추천 코인 뷰의 UI 상태를 나타냅니다.
    ///
    /// `state`는 로딩, 성공, 실패 등의 화면 표현을 의미합니다.
    @Published var status: ResponseStatus = .loading
    @Published var recommendCoins: [RecommendCoin] = []

    private var alanService: AlanRecommendServiceProtocol
    private var upbitService: UpBitApiServiceProtocol

    var task: Task<Void, Never>?

    @Published var timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    private let userInvestmentType = UserDefaults.standard.string(forKey: AppStorageKey.investmentType) ?? "conservative"

    var isSuccess: Bool {
        switch status {
        case .success:
            return true
        default:
            return false
        }
    }

    init(
        alanService: AlanRecommendServiceProtocol = AlanAPIService(),
        upbitService: UpBitApiServiceProtocol = UpBitAPIService()
    ) {
        self.alanService = alanService
        self.upbitService = upbitService
        loadRecommendCoin()
    }

    /// 비동기로 추천 코인 목록을 가져옵니다.
    func loadRecommendCoin() {
        task = Task {
            do {
                await MainActor.run {
                    recommendCoins = []
                    status = .loading
                }

                let bookmarkCoins = try BookmarkManager.shared.fetchAll().map { $0.coinKoreanName }.joined(separator: ", ")
                let recommendCoinDTOs = try await alanService.fetchRecommendCoins(preference: userInvestmentType, bookmarkCoins: bookmarkCoins)  
                
                let results = await fetchRecommendCoins(from: recommendCoinDTOs)

                await MainActor.run {
                    recommendCoins = results
                    status = .success
                }

            } catch is CancellationError {
                await MainActor.run {
                    status = .cancel(.taskCancelled)
                    recommendCoins = []
                }
            } catch let error as NetworkError {
                print(error.log())
                await MainActor.run {
                    status = .failure(error)
                    recommendCoins = []
                }
            } catch {
                print("알 수 없는 에러 발생.")
            }
        }
    }

    /// 코인 추천 작업을 취소합니다.
    func cancelTask() async {
        task?.cancel()
        await task?.value
        task = nil
    }

    private func fetchRecommendCoins(from dtos: [RecommendCoinDTO]) async -> [RecommendCoin] {
        await withTaskGroup(of: RecommendCoin?.self) { group in
            for dto in dtos {
                group.addTask {
                    do {
                        guard let data = try await self.upbitService.fetchQuotes(id: "KRW-\(dto.symbol)").first else {
                            return nil
                        }

                        return RecommendCoin(
                            imageURL: nil,
                            comment: dto.comment,
                            coinID: data.coinID.replacingOccurrences(of: "KRW-", with: ""),
                            name: dto.name,
                            tradePrice: data.tradePrice,
                            changeRate: data.changeRate,
                            changeType: RecommendCoin.TickerChangeType(rawValue: data.change)
                        )
                    } catch {
                        return nil
                    }
                }
            }

            var results: [RecommendCoin] = []

            for await coin in group {
                if let coin = coin {
                    results.append(coin)

                    if results.count == 5 {
                        group.cancelAll()
                        break
                    }
                }
            }
            
            print(results.count)
            return results
        }
    }
    
    func stopTimer() {
        timer.upstream.connect().cancel()
    }
    
    func startTimer() {
        timer = timer.upstream.autoconnect()
    }
}
