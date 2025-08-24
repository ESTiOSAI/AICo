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
///
/// - Properties:
///   - overview: 코인 개요 상태(`FetchState<AttributedString>`)
///   - weekly: 주간 동향 상태(`FetchState<String>`)
///   - today: 오늘의 시장 요약 상태(`FetchState<String>`)
///   - news: 오늘의 뉴스 기사 목록
final class ReportViewModel: ObservableObject {
    @Published var overview: FetchState<AttributedString> = .loading
    @Published var weekly: FetchState<AttributedString> = .loading
    @Published var today: FetchState<AttributedString> = .loading
    @Published var news: [CoinArticle] = [CoinArticle(title: "", summary: "AI가 정보를 준비하고 있어요", newsSourceURL: "https://example.com/")]
    
    let coin: Coin
    let koreanName: String
    
    private let alanAPIService = AlanAPIService()
    
    private var overviewTask: Task<CoinOverviewDTO, Error>?
    private var weeklyTask: Task<CoinWeeklyDTO, Error>?
    private var todayTask: Task<CoinTodayNewsDTO, Error>?
    
    init(coin: Coin) {
        self.coin = coin
        self.koreanName = coin.koreanName
        
        load()
    }
    
    // 코인 개요, 주간 동향, 오늘 시장 요약/뉴스를 동시에 로드
    private func load() {
        cancelAll()
        
        Task { @MainActor in
            overview = .loading
            weekly = .loading
            today = .loading
        }
        
        overviewTask = Task { try await alanAPIService.fetchOverview(for: coin) }
        
        weeklyTask = Task { [weak self] in
            try await withTaskCancellationHandler(
                operation: {
                    guard let self else { throw CancellationError() }
                    return try await self.alanAPIService.fetchWeeklyTrends(for: self.coin)
                },
                onCancel: { [weak self] in
                    self?.weekly = .cancel(.taskCancelled)
                },
                isolation: MainActor.shared
            )
        }
        
        todayTask = Task { [weak self] in
            try await withTaskCancellationHandler(
                operation: {
                    guard let self else { throw CancellationError() }
                    return try await self.alanAPIService.fetchTodayNews(for: self.coin)
                },
                onCancel: { [weak self] in
                    self?.today = .cancel(.taskCancelled)
                },
                isolation: MainActor.shared
            )
        }
        
        Task {
            await assignResult(
                overviewTask,
                assignOnMain: { [weak self] state in
                    self?.overview = state
                },
                transform: { data in
                    // TODO: 받아온 데이터 가공을 extension으로 빼는 것이 좋을지 고민해보기
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
                    overview.append(AttributedString("- 소개: \(data.description.byCharWrapping)"))
                    
                    return overview
                }
            )
            
            try? await Task.sleep(for: .milliseconds(350))
            
            await assignResult(
                weeklyTask,
                assignOnMain: { [weak self] state in
                    self?.weekly = state
                },
                transform: { data in
                    let weekly = """
                    - 가격 추이: \(data.priceTrend)
                    - 거래량 변화: \(data.volumeChange)
                    - 원인: \(data.reason)
                    """
                    return weekly
                }
            )
            
            try? await Task.sleep(for: .milliseconds(350))
            
            await assignResult(
                todayTask,
                assignOnMain: { [weak self] state in
                    self?.today = state
                },
                transform: { data in
                    return data.summaryOfTodaysMarketSentiment
                },
                sideEffectOnMain: { [weak self] data in
                    self?.news = data.articles.map { CoinArticle(from: $0) }
                }
            )
        }
    }
    
    // FIXME: 공통 로직으로 묶는 것을 다시 고려해보기
    /// 주어진 네트워크 `Task`의 결과를 변환하고 상태로 반영하는 유틸리티 메서드입니다.
    ///
    /// - Parameters:
    ///   - task: 실행할 네트워크 Task
    ///   - assignOnMain: 변환된 결과 상태(`FetchState`)를 메인 스레드에서 속성에 반영하는 클로저
    ///   - transform: Task 성공 결과(`Success`)를 출력 타입(`Output`)으로 변환하는 비동기 클로저
    ///   - sideEffectOnMain: 선택적으로, 성공 시 원본 결과(`Success`)를 활용해 메인 스레드에서 UI를 갱신하는 클로저
    func assignResult<Success, Output>(
        _ task: Task<Success, Error>?,
        assignOnMain: @escaping (FetchState<Output>) -> Void,
        transform: @Sendable (Success) async throws -> Output,
        sideEffectOnMain: ((Success) -> Void)? = nil
    ) async {
        do {
            let value = try await task?.value
            if let value {
                let output = try await transform(value)
                if let sideEffectOnMain {
                    await MainActor.run { sideEffectOnMain(value) }
                }
                await MainActor.run { assignOnMain(.success(output)) }
            }
        } catch {
            if error.isTaskCancellation {
                await MainActor.run { assignOnMain(.cancel(.taskCancelled)) }
                return
            }
            if let ne = error as? NetworkError {
                print(ne.log())
                await MainActor.run { assignOnMain(.failure(ne)) }
            } else {
                print(error)
            }
        }
    }
    
    // overview만 다시 시도
    func retryOverview() {
        if overview.isLoading { return }
        overviewTask?.cancel()
        
        Task { @MainActor in
            overview = .loading
        }
        
        overviewTask = Task { try await alanAPIService.fetchOverview(for: coin) }
        
        Task {
            await assignResult(
                overviewTask,
                assignOnMain: { [weak self] state in
                    self?.overview = state
                },
                transform: { data in
                    // TODO: 받아온 데이터 가공을 extension으로 빼는 것이 좋을지 고민해보기
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
                    
                    return overview
                }
            )
        }
    }
    
    // weekly만 다시 시도
    func retryWeekly() {
        if weekly.isLoading { return }
        weeklyTask?.cancel()
        
        Task { @MainActor in
            weekly = .loading
        }
        
        weeklyTask = Task { try await alanAPIService.fetchWeeklyTrends(for: coin) }
        
        Task {
            await assignResult(
                weeklyTask,
                assignOnMain: { [weak self] state in
                    self?.weekly = state
                },
                transform: { data in
                    let weekly = """
                    - 가격 추이: \(data.priceTrend)
                    - 거래량 변화: \(data.volumeChange)
                    - 원인: \(data.reason)
                    """
                    return weekly
                }
            )
        }
    }
    
    // retry만 다시 시도
    func retryToday() {
        if today.isLoading { return }
        todayTask?.cancel()
        
        Task { @MainActor in
            today = .loading
        }
        
        todayTask = Task { try await alanAPIService.fetchTodayNews(for: coin) }
        
        Task {
            await assignResult(
                todayTask,
                assignOnMain: { [weak self] state in
                    self?.today = state
                },
                transform: { data in
                    return data.summaryOfTodaysMarketSentiment
                },
                sideEffectOnMain: { [weak self] data in
                    self?.news = data.articles.map { CoinArticle(from: $0) }
                }
            )
        }
    }
    
    func cancelOverview() { overviewTask?.cancel() }
    func cancelWeekly() { weeklyTask?.cancel() }
    func cancelToday() { todayTask?.cancel() }
    
    // 전체 Task 취소
    func cancelAll() {
        overviewTask?.cancel()
        weeklyTask?.cancel()
        todayTask?.cancel()
    }
    
    deinit {
        cancelAll()
    }
}
extension ReportViewModel {
    var sectionDataSource: [ReportSectionData<AttributedString>] {
        [
            ReportSectionData(
                id: "overview",
                icon: "text.page.badge.magnifyingglass",
                title: "한눈에 보는 \(koreanName)",
                state: overview,
                onCancel: { self.cancelOverview() },
                onRetry: { self.retryOverview() }
            ),
            ReportSectionData(
                id: "weekly",
                icon: "calendar",
                title: "주간 동향",
                state: weekly,
                onCancel: { self.cancelWeekly() },
                onRetry: { self.retryWeekly() }
            ),
            ReportSectionData(
                id: "today",
                icon: "shareplay",
                title: "오늘 시장의 분위기",
                state: today,
                onCancel: { self.cancelToday() },
                onRetry: { self.retryToday() }
            ),
        ]
    }
}
