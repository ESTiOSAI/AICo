//
//  CoinDetailView.swift
//  AIProject
//
//  Created by 장지현 on 7/31/25.
//

import SwiftUI

struct CoinDetailView: View {
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss
    
    let coin: Coin
    
    private let tabs = ["차트", "AI 리포트"]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                /// 커스텀 백버튼
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(.aiCoLabel)
                        .frame(width: 30, height: 36)
                        .contentShape(Rectangle())
                }
                
                Text(coin.koreanName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.aiCoLabel)

                Text(coin.id)                        
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.aiCoLabelSecondary)

                Spacer()
            }
            .padding(.bottom, 10)
            
            HStack(spacing: 8) {
                ForEach(tabs.indices, id: \.self) { index in
                    RoundedRectangleButton(
                        title: tabs[index],
                        isActive: selectedTab == index
                    ) {
                        selectedTab = index
                    }
                    .frame(height: 36)
                }
                
                Spacer(minLength: 0)
            }
            .padding(.bottom, 15)
            
            ZStack(alignment: .topLeading) {
                /// 차트 탭
                ChartView(coin: coin)
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 0)
                    .accessibilityHidden(selectedTab != 0)

                /// AI 리포트 탭
                ReportView(coin: coin)
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 1)
                    .accessibilityHidden(selectedTab != 1)
            }
            .animation(.easeInOut(duration: 0.15), value: selectedTab)

             Spacer(minLength: 0)
        }
        .padding(20)
        .background(.aiCoBackground)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    let sampleCoin = Coin(id: "KRW-BTC", koreanName: "비트코인")
    CoinDetailView(coin: sampleCoin)
        .environmentObject(ThemeManager())
}
