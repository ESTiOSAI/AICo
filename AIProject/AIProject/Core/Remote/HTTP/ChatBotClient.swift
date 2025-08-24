//
//  SSEClient.swift
//  AIProject
//
//  Created by 강대훈 on 8/7/25.
//

import Foundation

/// 챗봇에 활용할 OpenRouter API와 통신하고 SSE 방식으로 데이터를 내려주는 객체
final class ChatBotClient: NSObject {
    private var task: URLSessionDataTask?
    private var session: URLSession?

    private let url: String = "https://openrouter.ai/api/v1/chat/completions"

    typealias ChatBotStream = AsyncThrowingStream<String, Error>
    private(set) var continuation: ChatBotStream.Continuation?
    var stream: ChatBotStream?
    
    /// OpenRouter SSE 서버에 연결을 생성하고 응답 스트림을 시작합니다.
    /// - Parameter content: 서버에 전송할 유저 메세지 입니다.
    func connect(content: String) async throws {
        stream = ChatBotStream { continuation in
            self.continuation = continuation
        }

        let request = try configureRequest(content: content)
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        task = session?.dataTask(with: request)
        task?.resume()
    }
    
    /// 현재 SSE 연결과 스트림을 종료합니다.
    func disconnect() {
        continuation?.finish()
        continuation = nil
        stream = nil

        task?.cancel()
        session?.invalidateAndCancel()
    }

    
    /// OpenRouter SSE 요청을 구성합니다.
    /// - Parameter content: 요청을 보낼 유저의 메세지입니다.
    /// - Returns: SSE 연결에 사용할 준비된 `URLRequest`를 반환합니다.
    private func configureRequest(content: String) throws -> URLRequest {
        guard let token = Bundle.main.infoDictionary?["CHATBOT_API_KEY"] as? String else {
            throw NetworkError.invalidAPIKey
        }

        guard let url = URL(string: url) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Content-Type")

        let jsonBody: [String: Any] = [
            "model": "openai/gpt-3.5-turbo",
            "messages": [
                [
                    "role": "system",
                    "content": "너는 코인 투자 도우미야, 모든 가상 화폐는 KRW로 보여줘"
                ],
                [
                    "role": "user",
                    "content": "\(content)"
                ]
            ],
            "stream": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)

        return request
    }
}

extension ChatBotClient: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }

        // SSE는 무조건 하나의 데이터만 들어오는 것이 아니고, 2개의 줄바꿈으로 데이터를 구분하여 들어오기 때문에 파싱이 필요합니다.
        let comps = text.components(separatedBy: "\n\n")

        for comp in comps {
            if let index = comp.firstIndex(of: ":") {
                let afterIndex = comp.index(after: index)
                let subString = comp.suffix(from: afterIndex).trimmingCharacters(in: .whitespaces)

                if let jsonData = subString.data(using: .utf8) {
                    Task { @MainActor in
                        if let jsonObject = try? JSONDecoder().decode(ChatDTO.self, from: jsonData) {
                            let value = jsonObject.choices.first?.delta.content ?? ""
                            continuation?.yield(value)
                        } else {
                            if subString == "[DONE]" { disconnect() }
                        }
                    }
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let error {
            print("챗봇 에러 \(error.localizedDescription)")
            continuation?.finish(throwing: error)
            disconnect()
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) async -> URLSession.ResponseDisposition {
        if let httpResponse = response as? HTTPURLResponse {
            if (200..<300) ~= httpResponse.statusCode {
                return .allow
            }
        }

        return .cancel
    }
}
