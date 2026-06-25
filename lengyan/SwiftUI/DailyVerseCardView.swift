//
//  DailyVerseCardView.swift
//  lengyan
//
//  Created by Antigravity on 2026/06/25.
//

import SwiftUI

struct SutraOnboardingView: View {
    var onComplete: () -> Void
    
    @State private var isReminderOn: Bool = true
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // Background splash image
            Image("sutra_splash")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            // Subtle dark/warm overlay to ensure text readability
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 24) {
                    // Opening Verse (开经偈)
                    VStack(spacing: 12) {
                        Text("無上甚深微妙法")
                        Text("百千萬劫難遭遇")
                        Text("我今見聞得受持")
                        Text("願解如來真實義")
                    }
                    .font(.custom("STKaiti", size: 22))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .tracking(4)
                    .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 2)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    
                    // 🌿 禅意引言 — 引导听经
                    Text(Book.shared.isSimplifiedChinese ? "— 随文静读，亦可听经 —" : "— 隨文靜讀，亦可聽經 —")
                        .font(.system(size: 13, weight: .light, design: .serif))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.top, 12)
                        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 1)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                }
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 24) {
                    // Notification opt-in
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                            isReminderOn.toggle()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: isReminderOn ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundColor(isReminderOn ? Color(uiColor: SutraDesignTokens.shared.color(for: .primary)) : .white.opacity(0.7))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Book.shared.isSimplifiedChinese ? "开启每日晨钟提醒" : "開啟每日晨鐘提醒")
                                    .font(.system(size: 14, weight: .medium, design: .serif))
                                    .foregroundColor(.white)
                                Text(Book.shared.isSimplifiedChinese ? "每日早晨八时为您推送，可在设置中自定义时间" : "每日早晨八時為您推送，可在設置中自定義時間")
                                    .font(.system(size: 11, weight: .light))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.3))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    
                    // Enter button
                    Button(action: enterApp) {
                        Text("進入經卷")
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .tracking(3)
                            .foregroundColor(.white)
                            .padding(.horizontal, 64)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(Color(uiColor: SutraDesignTokens.shared.color(for: .primary)))
                            )
                            .shadow(color: Color(uiColor: SutraDesignTokens.shared.color(for: .primary)).opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            // Serene entrance animation
            withAnimation(.easeOut(duration: 1.2).delay(0.2)) {
                showContent = true
            }
        }
    }
    
    private func enterApp() {
        if isReminderOn {
            ReminderManager.shared.requestPermissionAndSchedule { _ in
                onComplete()
            }
        } else {
            Prefers.shared.isDailyReminderOn = false
            onComplete()
        }
    }
}
