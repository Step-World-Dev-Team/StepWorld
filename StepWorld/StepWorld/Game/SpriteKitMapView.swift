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
    
    // Achievements Listeners
    @State private var showAchievements = false
    @State private var showAchievementBanner = false
    @State private var pendingAchievements: [String] = []
    
    @State private var changeToShow: (steps: Int, balance: Int)? = nil
    
    @State private var showDailyGoalBanner = false
    @State private var lastStepCount: Int = 0
    
    @StateObject private var shopVM = ShopViewModel()
    
    //MARK: Mark
    private var isModalPresented: Bool { showProfile || showSettings || showShop || showAchievements} //maybe remove showAchievements

    
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
                                    withAnimation {
                                        showAchievements = true
                                    }
                                } label: {
                                    Image("Achievement")
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
            if let delta = changeToShow, (delta.steps != 0 || delta.balance != 0) {
            
                       // Optional: block touches behind the popup
                ZStack {
                    
                    Image("build_menu_background")
                        .resizable()
                        .frame(width: 220, height: 230)
                    
                    VStack(spacing: 14) {
                        Text("What’s New")
                            .font(.custom("Press Start 2P", size: 16))
                            .padding(.top, 12)

                        if delta.steps != 0 {
                            Text("\(delta.steps >= 0 ? "▲" : "▼") Steps: \(delta.steps)")
                                .font(.custom("Press Start 2P", size: 12))
                        }
                        if delta.balance != 0 {
                            Text("\(delta.balance >= 0 ? "▲" : "▼") Balance: \(delta.balance)")
                                .font(.custom("Press Start 2P", size: 12))
                        }

                        Button {
                            map.markStatsAsSeenNow()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                changeToShow = nil
                            }
                        } label: {
                            Text("Got it")
                                .font(.custom("Press Start 2P", size: 12))
                                .foregroundColor(.black)
                                .background(Image("clear_button")
                                    .resizable()
                                    .frame(width: 100, height: 30)
                                )
                        }
                        .padding(.top, 45)
                        .padding(.bottom, 20)
                    }
                    .padding()
                    .frame(maxWidth: 320)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(200) // higher than modal
                }
            // 🔔 Achievement banner (after change pop-up)
            if showAchievementBanner, let currentId = pendingAchievements.first {
                AchievementBannerView(
                    message: "You completed an achievement!"
                ) {
                    handleAchievementBannerDismissed()
                }
                .zIndex(250)
            }
            
                if showDailyGoalBanner {
                    DailyGoalBannerView(
                        steps: map.todaySteps,
                        goal: map.dailyStepGoal
                    ) {
                        showDailyGoalBanner = false
                    }
                    .zIndex(240)
                }
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
                                showAchievements = false
                                
                            }
                        }
                    
                    // Choose which popup to show
                    GeometryReader { g in
                        Group {if showShop {
                            
                            ShopPanel(
                                // Merge server decor/buildings with local skin SKUs
                                items: {
                                    // 1) Server items from Firestore (decor/buildings)
                                    let buildingItems: [ShopItem] = shopVM.items
                                    
                                    // 2) Local skin SKUs (no backend change needed today)
                                    let skinEntries: [ShopItem] = [
                                        .init(type: "Barn#Blue",   price: 150, iconName: "BlueBarn_L1"),
                                        .init(type: "House#Candy", price: 150, iconName: "CandyHouse_L1"),
                                        .init(type: "Barn#Default", price: 0,   iconName: "Barn_L1"),
                                        .init(type: "House#Default",   price: 0, iconName: "House_L1"),
                                    ]
                                    
                                    return buildingItems + skinEntries
                                }(),
                                onClose: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        showShop = false
                                    }
                                },
                                onBuy: { item in
                                    if let scene = map.scene as? GameScene,
                                       let uid = map.userId ?? step.userId {
                                        
                                        if item.type.contains("#") {
                                            // Treat "Barn#Blue" / "House#Candy" as SKIN SKUs
                                            let parts = item.type.split(separator: "#")
                                            let baseType = String(parts[0])
                                            let skin = String(parts[1])
                                            
                                            // If already owned, equip; otherwise purchase+auto-equip
                                            if skin == "Default" {
                                                map.equipDefault(baseType: baseType)
                                            } else if map.inventory.ownedSkins.contains(item.type) {
                                                map.equipSkin(baseType: baseType, skin: skin)
                                            } else {
                                                Task {
                                                    await map.purchaseSkin(baseType: baseType,
                                                                           skin: skin,
                                                                           price: item.price,
                                                                           userId: uid)
                                                }
                                            }
                                        } else {
                                            // Server-provided decor/building → same behavior as before
                                            scene.attemptPurchaseAndStartPlacement(type: item.type,
                                                                                   price: item.price,
                                                                                   userId: uid)
                                        }
                                    }
                                    
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        showShop = false
                                    }
                                    
                                },
                                isOwned: { item in
                                    // Only skins have "#". Decor should never be considered owned for the UI.
                                    let parts = item.type.split(separator: "#")
                                    guard parts.count == 2 else { return false }          // <- decor/buildings
                                    let sku = item.type
                                    let skin = String(parts[1])
                                    return skin == "Default" || map.inventory.ownedSkins.contains(sku)
                                },
                                isEquipped: { item in
                                    // Only skins can be equipped
                                    let parts = item.type.split(separator: "#")
                                    guard parts.count == 2 else { return false }          // <- key change
                                    let base = String(parts[0])
                                    let skin = String(parts[1])
                                    if skin == "Default" { return map.equipped[base] == nil }
                                    return map.equipped[base] == skin
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
                                        map.resetScene()
                                        showSettings = false
                                        print("📤 signOut requested from SettingsView")
                                    } catch {
                                        print("❌ signOut failed: \(error)")
                                    }
                                }
                            })
                        } else if showAchievements {
                            AchievementsView {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                    showAchievements = false
                                }
                            }
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
                

            // TODO: Remove button and add logic to activate quake when user didn't walk enough
            
            ZStack(alignment: .topLeading) {
                 Button {
                     (map.scene as? GameScene)?.triggerEarthquake(duration: 3.0, breakProbability: 1.0)
                 } label: {
                     Text("Quake!")
                         .font(.caption)
                         .padding(.horizontal, 10)
                         .padding(.vertical, 6)
                         .background(Color.black.opacity(0.6))
                         .foregroundColor(.white)
                         .clipShape(RoundedRectangle(cornerRadius: 8))
                 }
                 .buttonStyle(.plain)
                 .padding(.top, 20)
                 .padding(.leading, 20)
             
            }
            .ignoresSafeArea(edges: .top)
            
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(NotificationCenter.default.publisher(for: .showChangePopup)) { note in
            let s = (note.userInfo?["steps"] as? Int) ?? 0
            let b = (note.userInfo?["balance"] as? Int) ?? 0
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                self.changeToShow = (s, b)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .achievementUnlocked)) { note in
            let id = note.userInfo?["id"] as? String ?? "achievement"
            
            // Queue the achievement
            pendingAchievements.append(id)
            
            // Only show banner immediately if the stats popup is NOT on-screen
            if changeToShow == nil {
                tryShowNextAchievementBanner()
            }
        }
        .onChange(of: map.todaySteps) { newSteps in
            let goal = map.dailyStepGoal
            guard goal > 0 else { return }

            // Only trigger when we cross the threshold (not every update above goal)
            if lastStepCount < goal && newSteps >= goal && !showDailyGoalBanner {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                    showDailyGoalBanner = true
                }
            }

            lastStepCount = newSteps
        }
        .onAppear {
            if map.scene.userId == nil {
                map.scene.userId = map.userId ?? Auth.auth().currentUser?.uid
            }
            Task {
                await map.refreshNow()
                await map.checkAndApplyDailyDisaster()
            }
            
            lastStepCount = map.todaySteps
        }
    }
    
    // MARK: Achievement Pop-up Functions
        func tryShowNextAchievementBanner() {
            guard changeToShow == nil else { return }
            guard !showAchievementBanner else { return }
            guard !pendingAchievements.isEmpty else { return }
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                showAchievementBanner = true
            }
        }

        func handleAchievementBannerDismissed() {
            if !pendingAchievements.isEmpty {
                pendingAchievements.removeFirst()
            }
            
            showAchievementBanner = false
            
            tryShowNextAchievementBanner()
        }
    
}

#Preview {
    //this comment is for testing purposes
    //SpriteKitMapView(changeToShow: (steps: 2000, balance: 150))
    SpriteKitMapView()
        .environmentObject(MapManager())
        .environmentObject(StepManager())
}

