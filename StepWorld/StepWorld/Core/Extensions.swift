//
//  Extensions.swift
//  StepWorld
//
//  Created by Isai soria on 11/4/25.
//

import Foundation

extension Notification.Name {
    // MARK: Sign Out Notification
    static let userDidSignOut = Notification.Name("userDidSignOut")
    
    // MARK: Pop up Notification
    static let showChangePopup = Notification.Name("showChangePopup")
    
    // MARK: Achievement Notification
    // ---FOR UI BANNERS---
    
    /// Fired when an achievement is unlocked (but not yet claimed).
    /// userInfo: ["id": AchievementId.rawValue]
    static let achievementUnlocked = Notification.Name("AchievementUnlocked")
    
    /// Fired when a reward is claimed.
    /// userInfo: ["id": AchievementId.rawValue, "reward": Int, "newBalance": Int]
    static let achievementRewardClaimed = Notification.Name("AchievementRewardClaimed")
    
}
