//
//  AIProjectApp.swift
//  AIProject
//
//  Created by kangho lee on 7/29/25.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct AIProjectApp: App {
    let persistenceController = PersistenceController.shared
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var recommendCoinViewModel = RecommendCoinViewModel()
    
    @State private var isLoading = true
    
    var body: some Scene {
        WindowGroup {
            if isLoading {
                SplashScreenView()
                    .onAppear {
                        if hasSeenOnboarding { recommendCoinViewModel.loadRecommendCoin() }
                        
                        Task {
                            try await Task.sleep(nanoseconds: 3000_000_000)
                            isLoading = false
                        }
                    }
            } else {
                if hasSeenOnboarding {
                    MainTabView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(themeManager)
                        .environmentObject(recommendCoinViewModel)
                } else {
                    OnboardingView()
                        .environmentObject(recommendCoinViewModel)
                }
            }
        }
    }
}

struct SplashScreenView: View {
    @State private var opacity: Double = 0.0

    var body: some View {
        ZStack {
            Color.accentColor
                .edgesIgnoringSafeArea(.all)
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 1.5)) {
                        opacity = 1.0
                    }
                }
        }
    }
}
