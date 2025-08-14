//
//  CachedAsyncImage.swift
//  AIProject
//
//  Created by 백현진 on 8/14/25.
//

import SwiftUI

struct CachedAsyncImage: View {
    let url: URL
    var useCacheOnly: Bool = false
    var placeholder: Image = Image(systemName: "photo")

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                placeholder
                    .resizable()
                    .scaledToFit()
                    .opacity(isLoading ? 0.5 : 1.0)
            }
        }
        .task {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        guard !isLoading else { return }
        isLoading = true
        do {
            image = try await ImageLoader.shared.image(for: url, useCacheOnly: useCacheOnly)
        } catch {
            print("이미지 로드 실패:", error.localizedDescription)
        }
        isLoading = false
    }
}
