//
//  GameViewController.swift
//  StepWorld
//
//  Created by Anali Cardoza on 10/24/25.
//
import UIKit
import SpriteKit

class GameViewController: UIViewController {
    private let map = MapManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let skView = SKView(frame: view.bounds)
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(skView)
        
        
        skView.presentScene(map.scene)
        
        print("✅ GameViewController launched GameScene.")
    }
}

