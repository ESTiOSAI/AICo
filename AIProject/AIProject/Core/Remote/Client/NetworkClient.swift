//
//  NetworkManager.swift
//  AIProject
//
//  Created by kangho lee on 7/29/25.
//

import Foundation

/// Network 통신을 담당하는 객체
final class NetworkClient {
    func request<T: Decodable>(url: URL) async throws -> T {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            let statusCode = httpResponse.statusCode
            try handleStatusCode(statusCode, data: data)
            
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch let decodingError as DecodingError {
                throw NetworkError.decodingError(decodingError)
            }
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw NetworkError.taskCancelled
        } catch let urlError as URLError {
            throw NetworkError.networkError(urlError)
        }  catch {
            throw error
        }
    }
    
    private func handleStatusCode(_ statusCode: Int, data: Data) throws {
        switch statusCode {
        case 200..<300:
            return
        case 401:
            throw NetworkError.quotaExceeded(statusCode)
        case 404:
            throw NetworkError.notFound(statusCode)
        case 414:
            throw NetworkError.uriTooLong(statusCode)
        case 503:
            throw NetworkError.serviceUnavilable(statusCode)
        case 500..<600:
            throw NetworkError.serverError(statusCode)
        default:
            if let errorData = String(data: data, encoding: .utf8) {
                throw NetworkError.remoteError(statusCode, errorData)
            } else {
                throw NetworkError.unknown(statusCode)
            }
        }
    }
}

extension NetworkClient {
    /// 서버에서 반환하는 상태 코드가 유효한지를 검증하고 Bool 타입으로 반환합니다.
    func requestWithBool(_ request: URLRequest) async throws -> Bool {
        let (_, response) = try await URLSession.shared.data(from: request.url!)
        
        if let httpResponse = response as? HTTPURLResponse, (200..<300) ~= httpResponse.statusCode {
            return true
        } else {
            return false
        }
    }
}
