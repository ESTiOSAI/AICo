//
//  InsightViewModel.swift
//  AIProject
//
//  Created by 장지현 on 8/6/25.
//

import Foundation

/// 오늘의 코인 시장/커뮤니티 분위기를 제공하는 뷰 모델입니다.
///
/// AI 또는 커뮤니티 기반의 분위기를 비동기적으로 불러오고,
/// 감정(`Sentiment`)과 요약(`summary`)을 제공합니다.
///
/// - Properties:
///   - overall: 오늘의 전체 시장 분위기(`FetchState<Insight>`)
///   - community: 커뮤니티 기반 분위기(`FetchState<Insight>`)
final class InsightViewModel: ObservableObject {
    @Published var overall: FetchState<Insight> = .loading
    @Published var community: FetchState<Insight> = .loading
    
    private let alanAPIService = AlanAPIService()
    private let redditAPIService = RedditAPIService()
    
    private var overallTask: Task<InsightDTO, Error>?
    private var communityTask: Task<InsightDTO, Error>?
    
    init() {
        load()
    }
    
    private func load() {
        cancelAll()
        
        Task { @MainActor in
            overall = .loading
            community = .loading
        }
        
        overallTask = Task {
            try await alanAPIService.fetchTodayInsight()
        }
        
        communityTask = Task {
            try await fetchCommunityFlow()
        }
        
        communityTask = Task { [weak self] in
            try await withTaskCancellationHandler(
                operation: {
                    guard let self else { throw CancellationError() }
                    return try await self.fetchCommunityFlow()
                },
                onCancel: { [weak self] in
                    self?.community = .cancel(.taskCancelled)
                },
                isolation: MainActor.shared
            )
        }
        
        Task {
            await updateOverallUI()
            try? await Task.sleep(for: .milliseconds(350))
            await updateCommunityUI()
        }
    }
    
    // Reddit 데이터를 가져와 요약 후 인사이트 생성
    private func fetchCommunityFlow() async throws -> InsightDTO {
        let communityData = try await redditAPIService.fetchData()
        
        return try await alanAPIService.fetchCommunityInsight(from: communityData.communitySummary)
    }
    
    // overall만 다시 시도
    func retryOverall() {
        if overall.isLoading { return }
        overallTask?.cancel()
        
        Task { @MainActor in
            overall = .loading
        }
        
        overallTask = Task { try await alanAPIService.fetchTodayInsight() }
        
        Task {
            await updateOverallUI()
        }
    }
    
    // community만 다시 시도
    func retryCommunity() {
        if community.isLoading { return }
        communityTask?.cancel()
        
        Task { @MainActor in
            community = .loading
        }
        
        communityTask = Task { try await fetchCommunityFlow() }
        
        Task {
            await updateCommunityUI()
        }
    }
    
    func cancelOverall() {
        overallTask?.cancel()
    }
    
    func cancelCommunity() {
        communityTask?.cancel()
    }
    
    func cancelAll() {
        overallTask?.cancel()
        communityTask?.cancel()
    }
    
    deinit {
        cancelAll()
    }
}

extension InsightViewModel {
    private func updateOverallUI() async {
        await TaskResultHandler.applyResult(
            of: overallTask,
            using: { data in
                Insight(
                    sentiment: Sentiment(rawValue: data.todaysSentiment) ?? .neutral,
                    summary: data.summary
                )
            },
            update: { [weak self] state in
                self?.overall = state
            }
        )
    }
    
    private func updateCommunityUI() async {
        await TaskResultHandler.applyResult(
            of: communityTask,
            using: { data in
                Insight(
                    sentiment: Sentiment(rawValue: data.todaysSentiment) ?? .neutral,
                    summary: data.summary
                )
            },
            update: { [weak self] state in
                self?.community = state
            }
        )
    }
}

extension InsightViewModel {
    var sectionDataSource: [ReportSectionData<Insight>] {
        [
            ReportSectionData(
                id: "overall",
                icon: "bitcoinsign.bank.building",
                title: "전반적인 시장의 분위기",
                state: overall,
                onCancel: { self.cancelOverall() },
                onRetry: { self.retryOverall() }
            ),
            ReportSectionData(
                id: "community",
                icon: "shareplay",
                title: "주요 커뮤니티의 분위기",
                state: community,
                onCancel: { self.cancelCommunity() },
                onRetry: { self.retryCommunity() }
            ),
        ]
    }
}
