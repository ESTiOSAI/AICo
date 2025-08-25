//
//  RecommendCoinView.swift
//  AIProject
//
//  Created by 강대훈 on 8/1/25.
//

import SwiftUI

struct RecommendCoinView: View {
    @EnvironmentObject var viewModel: RecommendCoinViewModel

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [.aiBackgroundGradientLight, .aiBackgroundGradientProminent],
                startPoint: .topLeading,
                endPoint: .bottom
            )
            .frame(height: CardConst.headerHeight + CardConst.headerContentSpacing + (CardConst.cardHeight / 2))
            
            RecommendCoinScreen()
                .environmentObject(viewModel)
                .padding(.bottom, 30)
            
            VStack {
                Spacer()
                
                TimestampWithRefreshButtonView(timestamp: Date.now, action: { viewModel.loadRecommendCoin() })
                    .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 40)
    }
}

#Preview {
    RecommendCoinView()
}



