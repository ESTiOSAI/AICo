//
//  ImageLoader.swift
//  AIProject
//
//  Created by 백현진 on 8/14/25.
//

import UIKit

actor ImageLoader {
    static let shared = ImageLoader()

    private var inFlight: [NSURL: Task<UIImage, Error>] = [:]
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .useProtocolCachePolicy
        config.urlCache = URLCache.shared
        return URLSession(configuration: config)
    }()

    func image(for url: URL, useCacheOnly: Bool = false) async throws -> UIImage {
        let key = url as NSURL

        // 이미 진행 중인 요청이 있으면 합류
        if let running = inFlight[key] {
            return try await running.value
        }

        let task = Task { () throws -> UIImage in
            var request = URLRequest(url: url)
            request.cachePolicy = useCacheOnly ? .returnCacheDataDontLoad : .returnCacheDataElseLoad

            // 디스크 캐시 확인
            if let cached = URLCache.shared.cachedResponse(for: request),
               let img = UIImage(data: cached.data) {
                print("캐시(디스크0)에서 이미지 로드됨:", url.lastPathComponent)
                return img
            }

            // 네트워크 요청
            let (data, response) = try await session.data(for: request)
            print("네트워크에서 이미지 로드됨:", url.lastPathComponent)
            guard let img = UIImage(data: data) else {
                throw URLError(.cannotDecodeContentData)
            }

            // 디스크 캐시에 저장 (HTTP 캐시 가능 응답만 저장됨)
            let cached = CachedURLResponse(response: response, data: data)
            URLCache.shared.storeCachedResponse(cached, for: request)

            return img
        }

        inFlight[key] = task
        defer { inFlight[key] = nil }

        return try await task.value
    }
}
