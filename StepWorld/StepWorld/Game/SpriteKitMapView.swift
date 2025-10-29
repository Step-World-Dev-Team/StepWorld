//
//  SpriteKitMapView.swift
//  StepWorld
//
//  Created by Anali Cardoza on 10/24/25.
//
import SwiftUI
import SpriteKit

struct SpriteKitMapView: View {
    @EnvironmentObject private var map: MapManager
    
    @State private var showProfile = false
    

    var body: some View {
        ZStack {
            SpriteView(scene: map.scene)
                .ignoresSafeArea()

            Color.clear
                // Top-right stats
                .overlay(alignment: .topTrailing) {
                    StatsDisplay()
                        .padding(.top, 4)
                        .padding(.trailing, 6)
                }
                // Bottom bar with 4 buttons (profile opens modal)
                .overlay(alignment: .bottom) {
                    HStack(spacing: 0) {
                        ForEach(1...4, id: \.self) { index in
                            if index == 3 {
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                        showProfile = true
                                    }
                                } label: {
                                    Image("profile_icon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .offset(x: 0, y: 46)
                                        .frame(maxWidth: .infinity)
                                }
                            } else {
                                Button {
                                    print("Bottom button \(index) tapped")
                                } label: {
                                    switch index {
                                    case 1:
                                        Image("home_icon")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 100, height: 100)
                                            .offset(x: 0, y: 46)
                                            .frame(maxWidth: .infinity)
                                    case 2:
                                        Image("money_icon 1")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 100, height: 100)
                                            .offset(x: 0, y: 46)
                                            .frame(maxWidth: .infinity)
                                    case 4:
                                        Image("gear_icon")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 100, height: 100)
                                            .offset(x: 0, y: 46)
                                            .frame(maxWidth: .infinity)
                                    default:
                                        EmptyView()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(!showProfile)
                    .zIndex(1)
                }

            // Show Profile
            if showProfile {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                showProfile = false
                            }
                        }

                    GeometryReader { g in
                        ProfileView(onClose: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                showProfile = false
                            }
                        })
                        .background(Color.clear)
                        .frame(
                            width: min(g.size.width * 0.92, 500),
                            height: min(g.size.height * 0.90, 800)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .transition(.scale.combined(with: .opacity))
                .zIndex(100)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)

    }
}

#Preview {
    SpriteKitMapView()
        .environmentObject(MapManager())
        .environmentObject(StepManager())
}
