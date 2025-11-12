//
//  SpriteKitMapView.swift
//  StepWorld
//
//  Created by Anali Cardoza on 10/24/25.
//
import SwiftUI
import SpriteKit
import FirebaseAuth

struct SpriteKitMapView: View {
    @EnvironmentObject private var map: MapManager
    @EnvironmentObject private var step: StepManager   // wherever your userId comes from
    
    @AppStorage("remember_me") private var rememberMe: Bool = true
    
    
    @State private var showProfile = false
    @State private var showSettings = false
    @State private var showShop = false
    
    @StateObject private var shopVM = ShopViewModel()
    
    private var isModalPresented: Bool { showProfile || showSettings || showShop}
    
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
                            switch index {
                            case 1:
                                Button {
                                    print("Home tapped")
                                } label: {
                                    Image("home_icon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .offset(x: 0, y: 46)
                                        .frame(maxWidth: .infinity)
                                }
                                
                            case 2:
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                        showShop = true
                                    }
                                } label: {
                                    Image("money_icon 1")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .offset(x: 0, y: 46)
                                        .frame(maxWidth: .infinity)
                                }
                                
                            case 3:
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
                                
                            case 4:
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                        showSettings = true
                                    }
                                } label: {
                                    Image("gear_icon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .offset(x: 0, y: 46)
                                        .frame(maxWidth: .infinity)
                                }
                                
                            default:
                                EmptyView()
                            }
                        }
                        
                    }
                    .padding(.vertical, 12)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(!isModalPresented)
                    .zIndex(1)
                }
            
            
            if isModalPresented {
                ZStack {
                    // Dim fades independently
                    Color.black
                        .opacity(0.5)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: isModalPresented)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                showProfile = false
                                showSettings = false
                                showShop = false

                            }
                        }
                    
                    // Choose which popup to show
                    GeometryReader { g in
                        Group {if showShop {
                            ShopPanel(
                                items: shopVM.items,
                                onClose: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        showShop = false
                                    }
                                },
                                onBuy: { item in
                                    // Prefer map.userId, fallback to step.userId (if your StepManager has it)
                                    if let uid = map.userId ?? step.userId {
                                        // map.scene is already a GameScene, no need to cast
                                        map.scene.attemptPurchaseAndStartPlacement(
                                            type: item.type,
                                            price: item.price,
                                            userId: uid
                                        )
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                            showShop = false
                                        }
                                    } else {
                                        print("⚠️ No user id available; cannot buy.")
                                    }
                                }
                            )
                            .task { await shopVM.load() }
                        } else if showProfile {
                                ProfileView(onClose: {
                                    Task {
                                        await map.refreshNow()
                                        print("Attempted refresh")
                                    }
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        showProfile = false
                                    }
                                })
                            } else if showSettings {
                                SettingsView(onClose: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        showSettings = false
                                    }
                                }, onSignOut: {
                                    Task { @MainActor in
                                        do {
                                            try AuthenticationManager.shared.signOutUser()   // ← this triggers the listener
                                            map.userId = nil                                 // optional: clear local state
                                            showSettings = false
                                            print("📤 signOut requested from SettingsView")
                                        } catch {
                                            print("❌ signOut failed: \(error)")
                                        }
                                    }
                                })
                            }
                        }
                        .background(Color.clear)
                        .frame(
                            width: min(g.size.width * 0.92, 500),
                            height: min(g.size.height * 0.90, 800)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.scale.combined(with: .opacity)) // keep the pop animation
                    }
                }
                .zIndex(100)
            }
            
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if map.scene.userId == nil {
                map.scene.userId = map.userId ?? Auth.auth().currentUser?.uid
            }
            Task {
                await map.refreshNow()
            }
        }
        
    }
}

#Preview {
    SpriteKitMapView()
        .environmentObject(MapManager())
        .environmentObject(StepManager())
}
