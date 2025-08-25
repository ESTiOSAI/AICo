//
//  ChatBotViewModel.swift
//  AIProject
//
//  Created by 강대훈 on 8/7/25.
//

import Foundation

final class ChatBotViewModel: ObservableObject {
    /// 화면이 클릭되었을 때의 상태를 기록합니다.
    @Published var isTapped: Bool = false
    /// 사용자와 챗봇의 메세지를 담은 배열입니다.
    @Published private(set) var messages: [ChatMessage] = []
    /// 현재 유저가 메세지를 전송할 수 있는지 상태를 기록합니다.
    @Published private(set) var isEditable: Bool = false
    /// 메세지가 전송되고 화면에 메세지가 나타났을 때 트리거되는 프로퍼티입니다.
    @Published private(set) var isReceived: Bool = false
	/// 현재 챗봇이 데이터를 스트림하고 있는 중인지 상태를 기록합니다.
    @Published private(set) var isStreaming: Bool = false {
        didSet {
            Task { @MainActor in
                checkValid()
            }
        }
    }
    /// 유저가 보낼 메세지 텍스트입니다.
    @Published var searchText: String = "" {
        didSet {
            Task { @MainActor in
                checkValid()
            }
        }
    }

    /// 서버와 통신하는 클라이언트입니다.
    private let chatBotClient: ChatBotClient

    init(chatBotClient: ChatBotClient = ChatBotClient()) {
        self.chatBotClient = chatBotClient
    }

    /// 사용자가 입력한 메시지를 전송하고, 챗봇 응답 스트림을 관찰하여 UI에 반영합니다.
    /// - Parameter content: 사용자가 전송하는 메세지 내용입니다.
    ///
    /// 이 메소드는 메인 쓰레드에서 실행됩니다.
    @MainActor
    func sendMessage() async {
        let message = searchText

        searchText = ""
        isStreaming = true

        do {
            addMessage(with: message)
            isReceived = true
            try await chatBotClient.connect(content: message)
            try await observeStream()
            isReceived = false
        } catch {
            await MainActor.run { showStreamError() }
        }

        isStreaming = false
    }

    /// 챗봇 SSE 스트림을 관찰하여 토큰 단위로 UI에 메시지를 업데이트합니다.
    private func observeStream() async throws {
        guard let stream = chatBotClient.stream else { return }

        for try await content in stream {
            try await Task.sleep(for: .seconds(0.05))
            await MainActor.run {
                if let index = messages.lastIndex(where: { !$0.isUser }) {
                    let message = messages[index]
                    messages[index] = ChatMessage(content: message.content + content, isUser: false)
                }
            }
        }
    }

    /// 사용자 메시지와 빈 챗봇 응답 메시지를 목록에 추가합니다.
    /// - Parameter content: 사용자의 메시지 내용입니다.
    ///
    /// 이 메소드는 메인 쓰레드에서 실행됩니다.
    @MainActor
    private func addMessage(with content: String) {
        messages.append(ChatMessage(content: content, isUser: true))
        messages.append(ChatMessage(content: "", isUser: false))
    }

    /// 전송 버튼(편집 가능 상태)을 갱신합니다.
    ///
    /// 이 메소드는 메인 쓰레드에서 실행됩니다.
    @MainActor
    private func checkValid() {
        isEditable = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }
    
    /// SSE 데이터 전달 과정에서 에러가 발생했을 때 호출합니다.
    ///
    /// 이 메소드는 메인 쓰레드에서 실행됩니다.
    @MainActor
    private func showStreamError() {
        if let index = messages.lastIndex(where: { !$0.isUser }) {
            messages[index] = ChatMessage(content: "알 수 없는 에러가 발생했습니다.", isUser: false, isError: true)
        }
    }
}
