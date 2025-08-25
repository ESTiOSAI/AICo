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
    var timestamp: Date? = nil
    let onCancel: () -> Void
    let onRetry: () -> Void
}

struct ReportSectionView<Value, Trailing: View, Content: View>: View {
    let data: ReportSectionData<Value>
    @ViewBuilder var trailing: (Value) -> Trailing
    @ViewBuilder var content: (Value) -> Content

    private let cornerRadius: CGFloat = 20
    
    // No-trailing initializer
    init(
        data: ReportSectionData<Value>,
        @ViewBuilder content: @escaping (Value) -> Content
    ) where Trailing == EmptyView {
        self.data = data
        self.trailing = { _ in EmptyView() }
        self.content = content
    }

    // Trailing initializer
    init(
        data: ReportSectionData<Value>,
        @ViewBuilder trailing: @escaping (Value) -> Trailing,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.data = data
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: data.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.aiCoAccent)

                Text(data.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.aiCoLabel)

                Spacer()

                if case let .success(value) = data.state {
                    trailing(value)
                }
            }

            // Content
            Group {
                switch data.state {
                case .loading:
                    DefaultProgressView(status: .loading, message: "아이코가 리포트를 작성하고 있어요") {
                        data.onCancel()
                    }
                    .padding(.vertical, 20)
                case .success(let value):
                    content(value)
                        .font(.system(size: 14))
                        .foregroundStyle(.aiCoLabel)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxHeight: .infinity, alignment: .top)
                    
                    if let ts = data.timestamp {
                        TimestampWithRefreshButtonView(timestamp: ts) {
                            data.onRetry()
                        }
                    }
                case .cancel(let error):
                    DefaultProgressView(status: .cancel, message: error.localizedDescription) {
                        data.onRetry()
                    }
                    .padding(.vertical, 20)
                case .failure(let error):
                    DefaultProgressView(status: .failure, message: error.localizedDescription) {
                        data.onRetry()
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
