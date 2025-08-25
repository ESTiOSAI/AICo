//
//  CoinWeeklyDTO.swift
//  AIProject
//
//  Created by 장지현 on 8/4/25.
//

import Foundation

struct CoinWeeklyDTO: Codable {
    /// 최근 일주일 가격 추이
    let priceTrend: String
    
    /// 최근 일주일 거래량 변화
    let volumeChange: String
    
    /// 지난 일주일간 가격 추이와 거래량 변화의 주요 원인
    let reason: String
}

extension CoinWeeklyDTO {
    var weekly: AttributedString {
        AttributedString("""
        - 가격 추이: \(priceTrend)
        - 거래량 변화: \(volumeChange)
        - 원인: \(reason)
        """.byCharWrapping)
    }
}
