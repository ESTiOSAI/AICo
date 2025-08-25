//
//  RedditResponseDTO.swift
//  AIProject
//
//  Created by 강대훈 on 7/30/25.
//

import Foundation

/// Reddit 응답 DTO
struct RedditDTO: Codable {
    let data: RedditResponseDTO

    struct RedditResponseDTO: Codable {
        let children: [RedditPostDTO]

        struct RedditPostDTO: Codable {
            let data: RedditPostDetailDTO

            struct RedditPostDetailDTO: Codable {
                let title: String
                let content: String

                enum CodingKeys: String, CodingKey {
                    case title
                    case content = "selftext"
                }
            }
        }

        typealias Posts = [RedditPostDTO]
    }
}


extension RedditDTO.RedditResponseDTO.Posts {
    /// Reddit 게시글 데이터 배열을 제목과 내용으로 정리한 문자열입니다.
    ///
    /// 각 게시글의 제목과 본문을 순서대로 결합하여, AI 요약 요청에 전달할 수 있는 하나의 문자열로 만듭니다.
    ///
    /// - Returns: 게시글 제목과 내용을 포함한 요약 문자열
    var communitySummary: String {
        self.enumerated().reduce(into: "") { result, element in
            let (index, item) = element
            result += "제목\(index): \(item.data.title)"
            if !item.data.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result += "\n내용\(index): \(item.data.content)"
            }
            result += "\n"
        }
        .trimmingCharacters(in: .newlines)
    }
}
