//
//  RecommendCoinScreen.swift
//  AIProject
//
//  Created by 강대훈 on 8/15/25.
//

import SwiftUI

struct RecommendCoinScreen: View {
    @EnvironmentObject var viewModel: RecommendCoinViewModel
    
    var body: some View {
        VStack(alignment: .center, spacing: CardConst.headerContentSpacing) {
            RecommendHeaderView()
            
            coinContentView()
                .frame(minHeight: CardConst.cardHeight)
        }
    }
    
    @ViewBuilder
    func coinContentView() -> some View {
        switch viewModel.status {
        case .loading:
            RecomendationPlaceholderCardView(status: .loading, message: "아이코가 추천할 코인을\n고르는 중이에요") {
                Task { await viewModel.cancelTask() }
            }
        case .success:
            if !(viewModel.recommendCoins.count > 0) {
                // 최종적으로 반환된 코인이 1개도 없을 때
                RecomendationPlaceholderCardView(status: .failure, message: "추천할 코인을 찾지 못했어요\n잠시 후 다시 시도해주세요") {
                    viewModel.loadRecommendCoin()
                }
            } else {
                SuccessCoinView(viewModel: viewModel)
            }
        case .failure(let networkError):
            RecomendationPlaceholderCardView(status: .failure, message: networkError.localizedDescription) {
                viewModel.loadRecommendCoin()
            }
        case .cancel(let networkError):
            RecomendationPlaceholderCardView(status: .cancel, message: networkError.localizedDescription) {
                viewModel.loadRecommendCoin()
            }
        }
    }
}

#Preview {
    RecommendCoinView()
}

/// 무한 스크롤이 적용된 코인 추천 뷰
///
/// 뷰모델에서 네트워크 통신으로 추천 코인을 5개 받아온 후
/// 스크롤 시 양옆에 보여줄 안전 리스트들을 양 옆에 추가합니다.
/// [코인 리스트] + [코인 리스트] + [코인 리스트]
///  0, 1, 2, 3, 4      5, 6, 7, 8, 9       10, 11, 12, 13, 14
/// 각 배열의 경계에 도달할 시, 양 옆에 안전 리스트를 통째로 삽입/삭제하는데
/// 이를 위해 2차원 배열을 사용합니다.
///
/// 무한 스크롤은 뷰모델에서 제공해주는 타이머에 맞춰
/// 5 ~ 9까지 순환 -> 10에 도달 시 5로 순간 이동한 후 6으로 순환하는
/// 로직으로 작동합니다.
struct SuccessCoinView: View {
    @ObservedObject var viewModel: RecommendCoinViewModel
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.scenePhase) private var scenePhase
    
    @GestureState var isDragging: Bool = false
    
    /// 현재 추천 코인 카드의 인덱스를 저장하며,
    /// 선택된 카드의 위치를 추적하고 스크롤 포지션을 관리하는 데 사용하는 상태 변수
    @State var cardID: Int?
    /// viewModel에서 받아온 코인의 배열
    private var recommendedCoins: [RecommendCoin] { viewModel.recommendCoins }
    /// 코인의 배열을 무한 스크롤시키기 위해 3번 반복해 저장하는 상태 변수
    @State var wrappedCoins = [[RecommendCoin]]()
    /// 카드 선택 시 코인의 상세 페이지로 이동시키기 위해 사용하는 상태 변수
    @State var selectedCoin: RecommendCoin?
    
    var body: some View {
        /// 화면의 가로 크기에 따라 카드 갯수를 관리하는 computed property
        var numberOfColumn: Int { hSizeClass == .regular ? 2 : 1 }
        /// 3번 반복한 코인 리스트를 뷰에서 사용하기 쉽게 평탄화해 저장
        let tempCoinArray = wrappedCoins.flatMap { $0.map { $0 } }
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: .spacing) {
                ForEach(tempCoinArray.indices, id: \.self) { index in
                    let coin = tempCoinArray[index]
                    
                    VStack {
                        RecommendCardView(recommendCoin: coin)
                            .frame(
                                width: .infinity,
                                height: CardConst.cardHeight
                            )
                            .onTapGesture { selectedCoin = coin }
                            .scrollTransition(axis: .horizontal) { content, phase in // 활성화된 코인은 크게 보이게 하기
                                content.scaleEffect(
                                    y: phase.isIdentity ? 1 : CardConst.cardHeightMultiplier,
                                    anchor: .bottom
                                )
                            }
                    }
                    .containerRelativeFrame(
                        .horizontal,
                        count: numberOfColumn, // 컨테이너의 크기에 따라 한 화면에 몇 개의 카드를 보여줄지 결정하기
                        spacing: .spacing
                    )
                }
            }
            .scrollTargetLayout()
            .frame(height: CardConst.cardHeight + 1, alignment: .top) // stroke가 잘려보이는 듯 해서 1 포인트 추가하기
        }
        .contentMargins(.horizontal, CardConst.cardInnerPadding + .spacing) // 활성 카드의 양쪽에 2개의 카드 꽁지가 보이게하기
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(
            id: $cardID,
            anchor: .leading // 큰 화면에서 2개의 카드가 보일 때 어떤 카드를 기준으로 이동시킬건지에 영향을 주는 것 같음
        )
        .simultaneousGesture(DragGesture()
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onEnded({ _ in
                // 사용자가 스크롤링 한 후에는 타이머를 초기화하기
                viewModel.stopTimer()
                viewModel.startTimer()
            })
        )
        .onReceive(viewModel.timer) { _ in // 타이머를 구독해 UI 업데이트하기
            guard !isDragging,
                  !recommendedCoins.isEmpty,
                  let cardID
            else { return }
            
            handleInfiniteScrolling(cardID: cardID)
        }
        .navigationDestination(item: $selectedCoin) { coin in
            CoinDetailView(coin: Coin(id: "KRW-" + coin.id, koreanName: coin.name, imageURL: coin.imageURL))
        }
        .onAppear {
            // 무한 스크롤링 효과를 구현하기 위해 추천 코인 배열의 앞 뒤에 안전 코인을 붙이기
            wrappedCoins = [recommendedCoins, recommendedCoins, recommendedCoins]
            cardID = recommendedCoins.count // 시작점을 중간 배열의 첫 번째 카드로 지정하기
            viewModel.startTimer()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // 백그라운드 상태에서는 타이머 실행 중단하기
            switch newPhase {
            case .active:
                viewModel.startTimer()
            default:
                viewModel.stopTimer()
            }
        }
        .onDisappear {
            cardID = nil
            viewModel.stopTimer()
            wrappedCoins.removeAll()
        }
    }
}

extension SuccessCoinView {
    func handleInfiniteScrolling(cardID: Int) {
        let totalCoinCount = recommendedCoins.count
        
        /// 코인 리스트의 배열의 index
        ///
        /// 0: 첫번째
        /// 1: 중간 ( 자동 스크롤이 순환하는 실제 코인 리스트 )
        /// 2: 마지막
        let position = cardID / totalCoinCount
        let indexInGroup = cardID % totalCoinCount
        
        switch (position, indexInGroup) {
        case (2, 0):
            /// 중간 배열을 모두 순환해 10에 도달했을 시
            /// - 기존 0번 배열 삭제 + 맨 마지막에 새로운 배열 추가
            /// - 10 -> 5으로 순간 이동 + 5 -> 6으로 자연스럽게 순환
            wrappedCoins.removeFirst()
            wrappedCoins.append(recommendedCoins)
            self.cardID = cardID - totalCoinCount // 10 -> 5로 빛보다 빠르게 바꿔치기
            
            Task {
                try? await Task.sleep(nanoseconds: 50_000_000) // 5 -> 6으로 애니메이션과 함께 순환하기
                withAnimation(.easeInOut(duration: 0.5)) {
                    if let cardID = self.cardID {
                        self.cardID = (cardID + 1) % (totalCoinCount * 3)
                    }
                }
            }
            return
        default:
            /// 기본적인 자동 스크롤 처리
            withAnimation(.easeInOut(duration: 0.5)) {
                self.cardID = (cardID + 1) % (totalCoinCount * 3)
            }
        }
    }
}
