//
//  CoinTodayNewsDTO.swift
//  AIProject
//
//  Created by 장지현 on 8/4/25.
//

import Foundation

struct CoinTodayNewsDTO: Codable {
    /// 오늘 시장 분위기 요약
    let summaryOfTodaysMarketSentiment: String
    
    /// 뉴스 배열, 3개
    let articles: [CoinArticleDTO]
}

extension CoinTodayNewsDTO {
    var today: AttributedString {
        AttributedString(summaryOfTodaysMarketSentiment.byCharWrapping)
    }
}
