//
//  AlanAPIServiceProtocol.swift
//  AIProject
//
//  Created by 장지현 on 8/19/25.
//

import Foundation

protocol AlanRecommendServiceProtocol: Sendable {
    func fetchRecommendCoins(preference: String, bookmarkCoins: String) async throws -> [RecommendCoinDTO]
}

protocol AlanReportServiceProtocol: Sendable {
    func fetchOverview(for coin: Coin) async throws -> CoinOverviewDTO
    func fetchWeeklyTrends(for coin: Coin) async throws -> CoinWeeklyDTO
    func fetchTodayNews(for coin: Coin) async throws -> CoinTodayNewsDTO
}

protocol AlanAPIServiceProtocol: AlanRecommendServiceProtocol, AlanReportServiceProtocol {}
