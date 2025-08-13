//
//  ReportViewModel.swift
//  AIProject
//
//  Created by 장지현 on 8/1/25.
//

import Foundation

/// AI를 활용한 코인 리포트를 생성하는 뷰 모델입니다.
///
/// 코인 개요, 주간 동향, 오늘의 시장 요약, 주요 뉴스 목록을 비동기적으로 가져옵니다.
/// `AlanAPIService`를 통해 데이터를 요청하고, UI에 표시할 형식으로 가공합니다.
///
/// - Parameters:
///   - coin: 보고서 생성의 대상이 되는 코인입니다.
final class ReportViewModel: ObservableObject {
    @Published var overviewState: ResponseStatus = .loading
    @Published var weeklyState: ResponseStatus = .loading
    @Published var todayState: ResponseStatus = .loading
    
    @Published var coinOverView: AttributedString = AttributedString("AI가 정보를 준비하고 있어요")
    @Published var coinTodayTrends: String = "AI가 정보를 준비하고 있어요"
    @Published var coinWeeklyTrends: String = "AI가 정보를 준비하고 있어요"
    @Published var coinTodayTopNews: [CoinArticle] = [CoinArticle(title: "", summary: "AI가 정보를 준비하고 있어요", newsSourceURL: "https://example.com/")]
    
    let coin: Coin
    let koreanName: String
    
    private let alanAPIService = AlanAPIService()
    
    init(coin: Coin) {
        self.coin = coin
        self.koreanName = coin.koreanName
        
        Task.detached(priority: .background) {
            await self.fetchOverViewAsync()
            await self.fetchWeeklyTrendsAsync()
            await self.fetchTodayTopNewsAsync()
        }
    }
    
    private func fetchOverViewAsync() async {
        do {
            let data = try await alanAPIService.fetchOverview(for: coin)
            await MainActor.run {
                var overview = AttributedString()
                overview.append(AttributedString("- 심볼: \(data.symbol)\n"))

                if let urlString = data.websiteURL, let url = URL(string: urlString) {
                    let prefix = AttributedString("- 웹사이트: ")
                    var link = AttributedString(URL(string: urlString)?.host ?? urlString)
                    link.link = url
                    link.foregroundColor = .aiCoAccent
                    link.underlineStyle = .single
                    overview.append(prefix)
                    overview.append(link)
                    overview.append(AttributedString("\n"))
                } else {
                    overview.append(AttributedString("- 웹사이트: 없음\n"))
                }
                
                overview.append(AttributedString("- 최초발행: \(data.launchDate)\n"))
                overview.append(AttributedString("- 소개: \(data.description)"))

                self.coinOverView = overview
                self.overviewState = .success
            }
        } catch {
            guard let ne = error as? NetworkError else { return print(error) }
            
            print(ne.log())
            await MainActor.run {
                self.overviewState = .failure(ne)
            }
        }
    }
    
    private func fetchWeeklyTrendsAsync() async {
        do {
            let data = try await alanAPIService.fetchWeeklyTrends(for: coin)
            await MainActor.run {
                self.coinWeeklyTrends = """
                    - 가격 추이: \(data.priceTrend)
                    - 거래량 변화: \(data.volumeChange)
                    - 원인: \(data.reason)
                    """
                self.weeklyState = .success
            }
        } catch {
            guard let ne = error as? NetworkError else { return print(error) }
            
            print(ne.log())
            await MainActor.run {
                self.weeklyState = .failure(ne)
            }
        }
    }
    
    private func fetchTodayTopNewsAsync() async {
        do {
            let data = try await alanAPIService.fetchTodayNews(for: coin)
            await MainActor.run {
                self.coinTodayTrends = data.summaryOfTodaysMarketSentiment
                self.coinTodayTopNews = data.articles.map { CoinArticle(from: $0) }
                self.todayState = .success
            }
        } catch {
            guard let ne = error as? NetworkError else { return print(error) }
            
            print(ne.log())
            await MainActor.run {
                self.todayState = .failure(ne)
            }
        }
    }
}
