//
//  CoinGeckoService.swift
//  AIProject
//
//  Created by 백현진 on 8/8/25.
//

import Foundation

/// CoinGecko에서 코인 이미지(URL)를 조회하는 서비스를 제공합니다.
final class CoinGeckoAPIService {
    private let network: NetworkClient
    private let endpoint: String = "https://api.coingecko.com/api/v3"

    init(network: NetworkClient = .init()) {
        self.network = network
    }

    /// 지정한 심볼 집합에 해당하는 코인들의 이미지 정보를 조회합니다.
    /// - Parameters:
    ///   - symbols: 코인 심볼 배열 (ex. ["btc", "eth", "bonk"])
    ///   - vsCurrency: 표기 통화 (가격을 쓰지 않더라도 엔드포인트 특성상 필요, 기본: "krw")
    /// - Returns: 이미지 정보를 포함한 DTO 배열
    func fetchCoinImages(symbols: [String], vsCurrency: String = "krw") async throws -> [CoinGeckoImageDTO] {
        let trimmed = symbols
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard !trimmed.isEmpty else { return [] }

        var comps = URLComponents(string: "\(endpoint)/coins/markets")
        comps?.queryItems = [
            URLQueryItem(name: "vs_currency", value: vsCurrency.lowercased()),
            URLQueryItem(name: "symbols", value: trimmed.joined(separator: ","))
        ]

        guard let url = comps?.url else { throw NetworkError.invalidURL }

        let dtos: [CoinGeckoImageDTO] = try await network.request(url: url)
        return dtos
    }

    func fetchCoinImagesBatched(
        symbols: [String],
        vsCurrency: String = "krw",
        batchSize: Int = 50,
        maxConcurrentBatches: Int = 3
    ) async -> [CoinGeckoImageDTO] {

        let uniq = Array(Set(
            symbols
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { $0.lowercased() }
        ))

        guard !uniq.isEmpty else { return [] }

        let chunks = uniq.chunked(into: batchSize)
        var results: [CoinGeckoImageDTO] = []

        // 병럴 처리
        var start = 0
        while start < chunks.count {
            let end = min(start + maxConcurrentBatches, chunks.count)
            let window = Array(chunks[start..<end])
            start = end

            await withTaskGroup(of: [CoinGeckoImageDTO].self) { group in
                for chunk in window {
                    group.addTask { [vsCurrency] in
                        do {
                            return try await self.fetchCoinImages(symbols: chunk, vsCurrency: vsCurrency)
                        } catch {
                            print("네트워크 에러처리", error.localizedDescription)
                            return []
                        }
                    }
                }

                for await part in group {
                    results.append(contentsOf: part)
                }
            }
        }

        return results
    }

    /// symbols가 50개를 초과해도 배치로 모두 조회해 ["BTC": URL] 형태로 리턴합니다.
    func fetchImageMapBatched(
        symbols: [String],
        vsCurrency: String = "krw",
        batchSize: Int = 50,
        maxConcurrentBatches: Int = 3
    ) async -> [String: URL] {

        let dtos = await fetchCoinImagesBatched(
            symbols: symbols,
            vsCurrency: vsCurrency,
            batchSize: batchSize,
            maxConcurrentBatches: maxConcurrentBatches
        )

        // 키는 대문자 심볼로 통일
        return Dictionary(uniqueKeysWithValues:
                            dtos.compactMap { dto in
            guard let url = dto.imageURL else { return nil }
            return (dto.symbol.uppercased(), url)
        }
        )
    }

    //MARK: -- 온보딩 뷰에서 저장하는 새로운 fetch

    func fetchCoinImagesByIDs(ids: [String], vsCurrency: String = "krw") async throws -> [CoinGeckoImageDTO] {
        let trimmed = ids
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard !trimmed.isEmpty else { return [] }

        var comps = URLComponents(string: "\(endpoint)/coins/markets")
        comps?.queryItems = [
            URLQueryItem(name: "vs_currency", value: vsCurrency.lowercased()),
            URLQueryItem(name: "ids", value: trimmed.joined(separator: ","))
        ]

        guard let url = comps?.url else { throw NetworkError.invalidURL }

        let dtos: [CoinGeckoImageDTO] = try await network.request(url: url)
        //print(dtos, dtos.count)
        return dtos
    }

    func fetchImageMapByEnglishNames(
        englishNames: [String],
        vsCurrency: String = "krw"
    ) async -> [String: URL] {
        do {
            // 1. 메타 데이터(API로 이미지 URL 목록 가져오기)
            let dtos = try await fetchCoinImagesByIDs(ids: englishNames, vsCurrency: vsCurrency)

            // 2. URLCache에 이미지 저장 (ImageLoader 활용)
            var result: [String: URL] = [:]
            for dto in dtos {
                guard let url = dto.imageURL else { continue }
                let symbol = dto.symbol.uppercased()
                result[symbol] = url

                // 미리 캐싱 — 네트워크 요청이 필요해도 URLCache에 저장됨
                _ = try? await ImageLoader.shared.image(for: url)
            }

            return result
        } catch {
            print("네트워크 에러:", error.localizedDescription)
            return [:]
        }
    }
}
