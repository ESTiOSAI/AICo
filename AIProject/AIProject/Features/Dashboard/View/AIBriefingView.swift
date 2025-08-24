//
//  AIBriefingView.swift
//  AIProject
//
//  Created by 장지현 on 8/13/25.
//

import SwiftUI

/// 대시보드에서 AI 브리핑 섹션을 보여주는 뷰입니다.
///
/// 오늘의 인사이트, 커뮤니티 반응, 공포 탐욕 지수으로 구성합니다.
struct AIBriefingView: View {
    @Environment(\.horizontalSizeClass) var hSizeClass
    @Environment(\.verticalSizeClass) var vSizeClass
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel: InsightViewModel
    
    private var isPadLayout: Bool {
        hSizeClass == .regular && vSizeClass == .regular
    }
    
    init() {
        _viewModel = StateObject(wrappedValue: InsightViewModel())
    }
    
    var body: some View {
        SubheaderView(subheading: "새로운 소식들이 있어요")
            .padding(.bottom, 4)
        
        VStack(alignment: .leading, spacing: 20) {
            Text(String.aiGeneratedContentNotice)
                .font(.system(size: 11))
                .foregroundStyle(.aiCoNeutral)
                .lineSpacing(5)
            
            VStack(spacing: 16) {
                if isPadLayout {
                    HStack(spacing: 16) {
                        briefingView
                            .frame(height: 280)
                    }
                } else {
                    briefingView
                }
                
                FearGreedView()
                    .padding(.bottom, 30)
            }
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var briefingView: some View {
        ForEach(viewModel.sectionDataSource) { data in
            ReportSectionView(
                icon: data.icon,
                title: data.title,
                state: data.state,
                onCancel: data.onCancel,
                onRetry: data.onRetry,
                content: { Text($0.summary.byCharWrapping) }
            )
        }
    }
}

#Preview {
    AIBriefingView()
}
