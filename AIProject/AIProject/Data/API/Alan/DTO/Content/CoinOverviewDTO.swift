//
//  CoinOverviewDTO.swift
//  AIProject
//
//  Created by 장지현 on 8/4/25.
//

import Foundation

struct CoinOverviewDTO: Codable {
    /// 심볼
    let symbol: String
    
    /// 웹사이트
    let websiteURL: String?
    
    /// 최초발행
    let launchDate: String
    
    /// 디지털 자산 소개
    let description: String
}

extension CoinOverviewDTO {
    var overview: AttributedString {
        var overview = AttributedString()
        overview.append(AttributedString("- 심볼: \(symbol)\n"))
        
        if let urlString = self.websiteURL, let url = URL(string: urlString) {
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
        
        overview.append(AttributedString("- 최초발행: \(launchDate)\n"))
        overview.append(AttributedString("- 소개: \(description.byCharWrapping)"))
        
        return overview
    }
}
