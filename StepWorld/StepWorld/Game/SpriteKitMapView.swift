//
//  SpriteKitMapView.swift
//  StepWorld
//
//  Created by Anali Cardoza on 10/24/25.
//
import SwiftUI
import SpriteKit

struct SpriteKitMapView: View {
    var scene: SKScene {
        let scene = GameScene(size: UIScreen.main.bounds.size)
        scene.scaleMode = .aspectFill
        return scene
    }
    
    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}

#Preview {
    SpriteKitMapView()
}

