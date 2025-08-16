//
//  CoinChartView.swift
//  AIProject
//
//  Created by 강민지 on 7/31/25.
//

import SwiftUI
import Charts

/// 코인 상세 화면의 가격 차트 뷰
/// `ChartViewModel`이 제공하는 시계열 데이터를 라인 차트로 렌더링
struct ChartView: View {
    /// 헤더/차트에 바인딩되는 상태를 관리하는 ViewModel
    @StateObject private var viewModel: ChartViewModel
    /// 세그먼트 탭 선택 인덱스 (커스텀 SegmentedControlView와 바인딩)
    @State private var selectedTab = 0
    /// 현재 선택된 테마 정보를 가져오기 위한 전역 상태 객체
    @EnvironmentObject var themeManager: ThemeManager

    /// 차트 데이터 (시계열 포인트)
    private var data: [CoinPrice] { viewModel.prices }
    /// 헤더의 가격 요약 정보(마지막가 / 변화 / 등락률)
    private var summary: PriceSummary? { viewModel.summary }

    init(coin: Coin) {
        _viewModel = StateObject(wrappedValue:  ChartViewModel(coin: coin))
    }
    
    private static let headerDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd HH:mm"
        return f
    }()
    private var lastUpdatedText: String {
        Self.headerDateFormatter.string(from: Date()) + " 기준"
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            /// 타이틀 영역
            HStack(alignment: .top, spacing: 8) {
                /// 기준 시간 / 현재가 / 등락가, 등락률 / 거래대금
                VStack(alignment: .leading, spacing: 8) {
                    Text(lastUpdatedText)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.aiCoLabel)
                        .lineLimit(1)
                    
                    // 요약 데이터 유무
                    let hasSummary = (summary != nil)
                    
                    let lastPrice = summary?.lastPrice ?? 0
                    let changeValue = summary?.change ?? 0
                    let changeRate  = summary?.changeRate ?? 0
                    
                    let isRising = changeValue > 0
                    let isFalling = changeValue < 0
                    let color: Color = isRising ? themeManager.selectedTheme.positiveColor :
                    isFalling ? themeManager.selectedTheme.negativeColor :
                        .gray
                    let sign = isRising ? "+" : (isFalling ? "-" : "")
                    let arrow = isRising ? "▲" : (isFalling ? "▼" : "")
                    
                    Text(lastPrice.formatKRW)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.aiCoLabel)
                        .lineLimit(1)
                        .opacity(hasSummary ? 1 : 0)
                    
                    Text("\(sign)\(abs(changeValue).formatKRW) (\(arrow)\(abs(changeRate).formatRate))")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .opacity(hasSummary ? 1 : 0)
                    
                    let trade = viewModel.prices.last?.trade ?? 0
                    Text("거래대금 \(trade.formatMillion)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.aiCoLabelSecondary)
                        .lineLimit(1)
                        .opacity(hasSummary ? 1 : 0)
                }
                
                Spacer()
                
                /// 코인 북마크 버튼
                /// - 현재 코인이 북마크되어 있는지 여부에 따라 아이콘 표시 변경
                /// - 탭 시 북마크 추가/제거 로직 호출
                Button(action: {
                    viewModel.toggleBookmark()
                }) {
                    CircleIconView(imageName: viewModel.isBookmarked ? "bookmark.fill" : "bookmark")
                }
            }
            
            let chartRatio: CGFloat = 1.7
            
            ZStack {
                if data.isEmpty {
                    DefaultProgressView(
                        status: .loading,
                        message: "차트를 불러오는 중이에요",
                        buttonAction: { print("차트 불러오기 취소") }
                    )
                } else {
                    let yRange = viewModel.yAxisRange(from: data)
                    let xDomain = viewModel.xAxisDomain(for: data)
                    let scrollTo = viewModel.scrollToTime(for: data)
                    
                    /// 캔들 차트: 가격 시계열을 고가/저가 선(RuleMark) + 시가/종가 직사각형(RectangleMark)으로 표현
                    Chart(data) { point in
                        /// 고가/저가 수직선 표시 (위꼬리/아래꼬리 역할)
                        RuleMark(
                            x: .value("Date", point.date),
                            yStart: .value("Low", point.low),
                            yEnd: .value("High", point.high)
                        )
                        .foregroundStyle(
                            point.close >= point.open ? themeManager.selectedTheme.positiveColor : themeManager.selectedTheme.negativeColor
                        )
                        
                        /// 시가/종가 직사각형 (실체 바)
                        RectangleMark(
                            x: .value("Date", point.date),
                            yStart: .value("Open", point.open),
                            yEnd: .value("Close", point.close),
                            width: 6
                        )
                        .foregroundStyle(
                            point.close >= point.open ? themeManager.selectedTheme.positiveColor : themeManager.selectedTheme.negativeColor
                        )
                    }
                    /// X축 도메인 설정 및 스크롤 위치 초기화
                    .chartXScale(domain: xDomain)
                    .chartScrollPosition(initialX: scrollTo)
                    .chartScrollableAxes(.horizontal)
                    /// Y축 도메인 설정 (동적 범위)
                    .chartYScale(domain: yRange)
                    /// 한 화면에서 보이는 X축 범위 (2880초 = 48분)
                    .chartXVisibleDomain(length: 2880)
                    /// X축 눈금 (15분 간격) + 1시간마다 세로선 표시
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .minute, count: 15)) { value in
                            AxisTick()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(viewModel.timeFormatter.string(from: date))
                                }
                            }
                            
                            // 세로선은 1시간 단위(분 == 0)일 때만 표시
                            if let date = value.as(Date.self),
                               Calendar.current.component(.minute, from: date) == 0 {
                                AxisGridLine()
                            }
                        }
                    }
                    /// Y축 눈금 (20만 원 단위) + 값 포맷을 M(억) 단위로 축약
                    .chartYAxis {
                        AxisMarks(values: .stride(by: 200_000)) { value in // 20만원 단위 눈금 표시
                            AxisGridLine()
                            AxisTick()
                            if let price = value.as(Double.self) {
                                AxisValueLabel {
                                    Text(String(format: "%.1fM", price / 1_000_000))
                                }
                            }
                        }
                    }
                    /// 차트 오른쪽 영역에 여백 추가
                    .chartPlotStyle { plotArea in
                        plotArea
                            .padding(.trailing, 10)
                            .padding(.bottom, 8) 
                    }
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 20)
            .frame(height: 380)
        }
        .padding(20)
        .onAppear {
            viewModel.checkBookmark()
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.aiCoBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.default, lineWidth: 0.5)
        )
    }
}

#Preview {
    ChartView(coin: Coin(id: "KRW-BTC", koreanName: "비트코인"))
        .environmentObject(ThemeManager())
}
