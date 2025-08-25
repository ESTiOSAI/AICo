//
//  ReportSectionView.swift
//  AIProject
//
//  Created by 장지현 on 8/18/25.
//

import SwiftUI

struct ReportSectionData<Value>: Identifiable {
    let id: String
    let icon: String
    let title: String
    let state: FetchState<Value>
    let onCancel: () -> Void
    let onRetry: () -> Void
}

struct ReportSectionView<Value, Trailing: View, Content: View>: View {
    let icon: String
    let title: String
    let state: FetchState<Value>
    let onCancel: () -> Void
    let onRetry: () -> Void
    @ViewBuilder var trailing: (Value) -> Trailing
    @ViewBuilder var content: (Value) -> Content

    private let cornerRadius: CGFloat = 20
    
    // No-trailing initializer
    init(
        icon: String,
        title: String,
        state: FetchState<Value>,
        onCancel: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        @ViewBuilder content: @escaping (Value) -> Content
    ) where Trailing == EmptyView {
        self.icon = icon
        self.title = title
        self.state = state
        self.onCancel = onCancel
        self.onRetry = onRetry
        self.trailing = { _ in EmptyView() }
        self.content = content
    }

    // Trailing initializer
    init(
        icon: String,
        title: String,
        state: FetchState<Value>,
        onCancel: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        @ViewBuilder trailing: @escaping (Value) -> Trailing,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.icon = icon
        self.title = title
        self.state = state
        self.onCancel = onCancel
        self.onRetry = onRetry
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.aiCoAccent)

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.aiCoLabel)

                Spacer()

                if case let .success(value) = state {
                    trailing(value)
                }
            }

            // Content
            Group {
                switch state {
                case .loading:
                    DefaultProgressView(status: .loading, message: "아이코가 리포트를 작성하고 있어요") {
                        onCancel()
                    }
                    .padding(.vertical, 20)
                case .success(let value):
                    content(value)
                        .font(.system(size: 14))
                        .foregroundStyle(.aiCoLabel)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxHeight: .infinity, alignment: .top)
                case .cancel(let error):
                    DefaultProgressView(status: .cancel, message: error.localizedDescription) {
                        onRetry()
                    }
                    .padding(.vertical, 20)
                case .failure(let error):
                    DefaultProgressView(status: .failure, message: error.localizedDescription) {
                        onRetry()
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .background(.aiCoBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(.defaultGradient, lineWidth: 0.5)
        )
    }
}
