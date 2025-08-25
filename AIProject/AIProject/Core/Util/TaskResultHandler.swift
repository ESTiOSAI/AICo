//
//  TaskResultHandler.swift
//  AIProject
//
//  Created by 장지현 on 8/25/25.
//

import Foundation

enum TaskResultHandler {
    /// 주어진 네트워크 `Task`의 결과를 변환하고 상태로 반영하는 유틸리티 메서드입니다.
    ///
    /// - Parameters:
    ///   - task: 실행할 네트워크 Task
    ///   - transform: Task 성공 결과(`Success`)를 출력 타입(`Output`)으로 변환하는 비동기 클로저
    ///   - update: 변환된 결과 상태(`FetchState`)를 메인 스레드에서 속성에 반영하는 클로저
    ///   - sideEffect: 선택적으로, 성공 시 원본 결과(`Success`)를 활용해 메인 스레드에서 UI를 갱신하는 클로저
    static func applyResult<Success, Output>(
        of task: Task<Success, Error>?,
        using transform: @Sendable (Success) async throws -> Output,
        update: @escaping (FetchState<Output>) -> Void,
        sideEffect: ((Success) -> Void)? = nil
    ) async {
        do {
            let value = try await task?.value
            if let value {
                let output = try await transform(value)
                await MainActor.run { update(.success(output)) }
                if let sideEffect {
                    await MainActor.run { sideEffect(value) }
                }
            }
        } catch {
            if error.isTaskCancellation {
                await MainActor.run { update(.cancel(.taskCancelled)) }
                return
            }
            if let ne = error as? NetworkError {
                print(ne.log())
                await MainActor.run { update(.failure(ne)) }
            } else {
                print(error)
            }
        }
    }
}
