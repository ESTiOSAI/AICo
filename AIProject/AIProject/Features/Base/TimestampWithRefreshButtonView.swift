//
//  TimestampWithRefreshButtonView.swift
//  AIProject
//
//  Created by Kitcat Seo on 8/24/25.
//

import SwiftUI

/// 주어진 시각(`timestamp`)을 표시하고, 새로고침 버튼을 함께 배치한 뷰.
/// 우측 정렬된 형태로 기준 시각 텍스트와 새로고침 버튼을 제공.
///
/// - Parameters:
///   - timestamp: 표시할 기준 시각.
///   - action: 새로고침 버튼이 탭되었을 때 실행할 동작.
struct TimestampWithRefreshButtonView: View {
    let timestamp: Date
    var action: () -> Void
    
    var body: some View {
        let formattedTime = timestamp.dateAndTime
        
        HStack {
            Spacer()
            
            Text("\(formattedTime) 기준")
                .font(.system(size: 11))
                .foregroundStyle(.aiCoLabelSecondary)
            
            RoundedButton(imageName: "arrow.counterclockwise", action: action)
        }
    }
}

#Preview {
    TimestampWithRefreshButtonView(timestamp: Date.now, action: { dummyAction() })
}
