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
    // MARK: - State / Env
    /// 헤더/차트에 바인딩되는 상태를 관리하는 ViewModel
    @StateObject private var viewModel: ChartViewModel
    /// 세그먼트 탭 선택 인덱스 (커스텀 SegmentedControlView와 바인딩)
    @State private var selectedTab = 0
    /// 현재 선택된 테마 정보를 가져오기 위한 전역 상태 객체
    @EnvironmentObject var themeManager: ThemeManager

    // MARK: - Init
    /// 프로덕션 기본 경로
    init(coin: Coin) {
        _viewModel = StateObject(wrappedValue:  ChartViewModel(coin: coin))
    }
    
    #if DEBUG
    /// 프리뷰/디버그 전용 주입 경로
    init(
        coin: Coin,
        priceService: any CoinPriceProvider,
        tickerAPI: UpBitAPIService = UpBitAPIService()
    ) {
        _viewModel = StateObject(
            wrappedValue: ChartViewModel(
                coin: coin,
                priceService: priceService,
                tickerAPI: tickerAPI
            )
        )
    }
    #endif

    // MARK: - Computed & Helpers
    /// 차트 데이터 (시계열 포인트)
    private static let headerDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd HH:mm"
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()
    
    private var data: [CoinPrice] { viewModel.prices }
    
    private var shouldShowHeader: Bool {
        if case .success = viewModel.status, viewModel.hasHeader { return true }
        return false
    }
    
    /// 뷰모델이 제공하는 기준 시각 사용 (없으면 빈 문자열)
    private var lastUpdatedText: String {
        guard let time = viewModel.lastUpdated else { return "" }
        return Self.headerDateFormatter.string(from: time) + " 기준"
    }
    
    /// 뷰 전용 매핑 (테마/색)
    private var headerColor: Color {
        let v = viewModel.displayChangeValue
        if v > 0 { return themeManager.selectedTheme.positiveColor }
        if v < 0 { return themeManager.selectedTheme.negativeColor }
        return .gray
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading) {
            if shouldShowHeader {
                headerView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            chartArea
        }
        .padding(20)
        .onAppear {
            viewModel.checkBookmark()
            viewModel.retry()
        }
        .onDisappear {
            viewModel.stopUpdating()
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.aiCoBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.defaultGradient, lineWidth: 0.5)
        )
    }
    
    // MARK: - Subviews
    @ViewBuilder
    private var headerView: some View {
        let change = viewModel.displayChangeValue
        let sign   = change > 0 ? "+" : (change < 0 ? "-" : "")
        let arrow  = change > 0 ? "▲" : (change < 0 ? "▼" : "")
        let absChange  = abs(change)

        /// 타이틀 영역
        HStack(alignment: .top, spacing: 8) {
            /// 기준 시간 / 현재가 / 등락가, 등락률 / 거래대금
            VStack(alignment: .leading, spacing: 8) {
                Text(lastUpdatedText)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.aiCoLabel)
                    .lineLimit(1)
                
                Text(viewModel.displayLastPrice.formatKRW)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.aiCoLabel)
                    .lineLimit(1)
                
                Text("\(sign)\(absChange.formatKRW) (\(arrow)\(abs(viewModel.displayChangeRate).formatRate))")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(headerColor)
                    .lineLimit(1)
                
                Text("거래대금 \(viewModel.headerAccTradePrice.formatMillion)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.aiCoLabelSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            /// 코인 북마크 버튼
            /// - 현재 코인이 북마크되어 있는지 여부에 따라 아이콘 표시 변경
            /// - 탭 시 북마크 추가/제거 로직 호출
            Button(action: { viewModel.toggleBookmark() }) {
                CircleIconView(imageName: viewModel.isBookmarked ? "bookmark.fill" : "bookmark")
            }
        }
    }
    
    @ViewBuilder
    private var chartArea: some View {
        switch viewModel.status {
        case .loading:
            DefaultProgressView(
                status: .loading,
                message: "차트를 불러오는 중이에요"
            ) { viewModel.cancelLoading() }
        case .failure(let err):
            DefaultProgressView(
                status: .failure,
                message: err.localizedDescription
            ) { viewModel.retry() }
            
        case .cancel(let err):
            DefaultProgressView(
                status: .cancel,
                message: err.localizedDescription
            ) { viewModel.retry() }
            
        case .success:
            if data.isEmpty {
                DefaultProgressView(
                    status: .failure,
                    message: "최근 24시간 체결 데이터가 없어요"
                ) { viewModel.retry() }
            } else {
                let yRange = viewModel.yAxisRange(from: data)
                let xDomain = viewModel.xAxisDomain(for: data)
                let scrollTo = viewModel.scrollToTime(for: data)
                
                CandleChartView(
                    data: data,
                    xDomain: xDomain,
                    yRange: yRange,
                    scrollTo: scrollTo,
                    timeFormatter: viewModel.timeFormatter,
                    positiveColor: themeManager.selectedTheme.positiveColor,
                    negativeColor: themeManager.selectedTheme.negativeColor
                )
            }
        }
    }
}

/// 캔들 차트: 가격 시계열을 고가/저가 선(RuleMark) + 시가/종가 직사각형(RectangleMark)으로 표현
private struct CandleChartView: View {
    let data: [CoinPrice]
    let xDomain: ClosedRange<Date>
    let yRange: ClosedRange<Double>
    let scrollTo: Date
    let timeFormatter: DateFormatter
    let positiveColor: Color
    let negativeColor: Color
    
    var body: some View {
        Chart {
            ForEach(data, id: \.date) { point in
                /// 고가/저가 수직선 표시 (위꼬리/아래꼬리 역할)
                RuleMark(
                    x: .value("Date", point.date),
                    yStart: .value("Low", point.low),
                    yEnd: .value("High", point.high)
                )
                .foregroundStyle( point.close >= point.open ? positiveColor : negativeColor )
                
                /// 시가/종가 직사각형 (실체 바)
                RectangleMark(
                    x: .value("Date", point.date),
                    yStart: .value("Open", point.open),
                    yEnd: .value("Close", point.close),
                    width: 6
                )
                .foregroundStyle( point.close >= point.open ? positiveColor : negativeColor )
            }
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
                        Text(timeFormatter.string(from: date))
                    }
                }
                
                /// 세로선은 1시간 단위(분 == 0)일 때만 표시
                if let date = value.as(Date.self),
                   Calendar.current.component(.minute, from: date) == 0 {
                    AxisGridLine()
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisTick()
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        if yRange.upperBound >= 1_000_000 {
                            Text(String(format: "%.1fM", v / 1_000_000)) // 백만 단위
                        } else if yRange.upperBound >= 1_000 {
                            Text(String(format: "%.1fK", v / 1_000)) // 천 단위
                        } else {
                            Text(String(format: "%.0f", v)) // 원 단위 그대로
                        }
                    }
                }
            }
        }
        /// 차트 오른쪽 영역에 여백 추가
        .chartPlotStyle { $0.padding(.trailing, 10).padding(.bottom, 8) }
    }
}

#Preview {
    ChartView(coin: Coin(id: "KRW-BTC", koreanName: "비트코인"))
        .environmentObject(ThemeManager())
}
