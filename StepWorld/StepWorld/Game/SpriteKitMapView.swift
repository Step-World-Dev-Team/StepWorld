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
            Button {
                        (map.scene as? GameScene)?.triggerEarthquakeShake()
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
            
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if map.scene.userId == nil {
                map.scene.userId = map.userId ?? Auth.auth().currentUser?.uid
            }
            Task {
                await map.refreshNow()
                await map.checkAndApplyDailyDisaster()
            }
        }
        
    }
}

#Preview {
    SpriteKitMapView()
        .environmentObject(MapManager())
        .environmentObject(StepManager())
}
