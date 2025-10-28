//
//  StatWidget.swift
//  StepWorld
//
//  Created by Andre Bortoloto Lebeis on 10/26/25.
//

import SwiftUI

struct StatWidget: View {
    let backgroundImageName: String
    let title: String
    let value: String?
    var icon: Image? = nil
    var width: CGFloat = 280
    var height: CGFloat = 95

    var body: some View {
        ZStack {
            Image(backgroundImageName)
                .interpolation(.none)
                .antialiased(false)
                .resizable()
                .frame(width: width, height: height)

            HStack {
                VStack {
                    
                    Text(title)
                        .font(.custom("Press Start 2P", size: 14))
                    
                    if let value = value {
                        Text(value)
                            .font(.custom("Press Start 2P", size: 14))
                            .padding(.top, 5)
                    }
                }
                
                Spacer()
            }
            .padding(.leading, 140)
        }
    }
}


#Preview {
    StatWidget(backgroundImageName: "CoinsWidget",
               title: "Coins:",
               value: "300")
}
