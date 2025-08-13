//
//  ThemeView.swift
//  AIProject
//
//  Created by 백현진 on 8/3/25.
//

import SwiftUI

/// 사용자가 테마를 선택할 수 있는 설정 뷰
struct ThemeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack {
            HeaderView(heading: "테마 변경")
            SubheaderView(subheading: "차트 색상 변경")
                .padding(.bottom, 20)
            
            VStack(spacing: 16) {
                ForEach(Theme.allCases, id: \.self) { theme in
                    ThemeRow(
                        title: theme.displayName,
                        theme: theme,
                        isSelected: themeManager.selectedTheme == theme
                    ) {
                        themeManager.selectedTheme = theme
                    }
                }
            }
            .padding(.horizontal, 16)
            .animation(.snappy, value: themeManager.selectedTheme)
            .buttonStyle(.plain)
            
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    ThemeView()
        .environmentObject(ThemeManager())
}
