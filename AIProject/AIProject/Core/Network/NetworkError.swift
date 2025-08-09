//
//  NetworkError.swift
//  AIProject
//
//  Created by 강대훈 on 7/30/25.
//

import Foundation

/// 네트워크 에러를 정의한 객체입니다.
enum NetworkError: Error {
    /// 일반 네트워크 연결 오류입니다.
    case networkError(_ error: Error)
    /// 사용자가 작업을 취소한 경우입니다.
    case taskCancelled
    /// 잘못된 URL 요청입니다.
    case invalidURL
    /// 유효하지 않은 응답을 수신한 경우입니다.
    case invalidResponse
    /// 인코딩 오류입니다.
    case encodingError
    /// 디코딩 오류로, 발생 위치와 DecodingError를 포함합니다.
    case decodingError(_ error: DecodingError)
    
    /// API 키가 유효하지 않거나 누락된 경우입니다.
    case invalidAPIKey
    /// API 호출 한도를 초과한 경우입니다.
    case quotaExceeded(_ statusCode: Int)
    /// 요청한 리소스를 찾을 수 없는 경우입니다 (404).
    case notFound(_ statusCode: Int)
    /// 요청 URI가 너무 길어 서버가 처리할 수 없는 경우입니다.
    case uriTooLong(_ statusCode: Int)
    
    /// 서버가 유지보수 중이거나 일시적으로 사용할 수 없는 경우입니다.
    case serviceUnavilable(_ statusCode: Int)
    /// 서버 내부 오류(500번대 HTTP 응답 등)입니다.
    case serverError(_ statusCode: Int)
    /// 서버로부터 전달된 상태 코드와 오류 메시지를 포함한 오류입니다.
    case remoteError(_ statusCode: Int, _ errorData: String)
    /// 알 수 없는 상태 코드 기반의 오류입니다.
    case unknown(_ statusCode: Int)
    
    /// 웹소켓 통신 중 발생한 오류입니다.
    case webSocketError
}

extension NetworkError: LocalizedError {
    /// 사용자에게 표시할 오류 설명입니다.
    ///
    /// - `taskCancelled`: "작업이 취소되었습니다. 아래 버튼을 눌러 다시 시도해 주세요."
    /// - 그 외: "데이터를 불러오는 데 실패했어요. 잠시 후 다시 시도해 주세요."
    var errorDescription: String? {
        switch self {
        case .taskCancelled:
            return "작업이 취소되었습니다. 아래 버튼을 눌러 다시 시도해 주세요."
        default:
            return "데이터를 불러오는 데 실패했어요. 잠시 후 다시 시도해 주세요."
        }
    }
}

extension NetworkError {
    /// 오류 정보를 문자열로 변환하여 로그 형식으로 반환합니다.
    ///
    /// - Parameters:
    ///   - file: 호출한 파일 경로 (`#fileID`로 기본값 지정)
    ///   - function: 호출한 함수 이름 (`#function`으로 기본값 지정)
    /// - Returns: 오류 유형과 호출 위치, `.decodingError`의 경우 디버그 설명을 포함한 문자열
    func log(file: String = #fileID, function: String = #function) -> String {
        /// DecodingError인 경우 debugDescription을 log로 출력합니다.
        if case .decodingError(let err) = self {
            let message: String
            switch err {
            case .typeMismatch(_, let context),
                    .valueNotFound(_, let context),
                    .keyNotFound(_, let context),
                    .dataCorrupted(let context):
                message = context.debugDescription
            @unknown default:
                message = "알 수 없는 디코딩 오류입니다."
            }
            let escaped = message.replacingOccurrences(of: "\"", with: "\\\"")
            return "decodingError(\"\(escaped)\")-\"\(file)#\(function)\""
        }
        
        return "\(String(describing: self))-\"\(file)#\(function)\""
    }
}
