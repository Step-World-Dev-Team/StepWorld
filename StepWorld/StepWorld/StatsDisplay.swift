//
//  StatsDisplay.swift
//  StepWorld
//
//  Created by Andre Bortoloto Lebeis on 10/9/25.
//

import SwiftUI

struct StatsDisplay: View {
    @EnvironmentObject var steps: StepManager
    
    var body: some View {
            //might have to correct the alignment...
        HStack {
            VStack {
                VStack {
                    HStack {
                        Image("Boot")
                            .resizable()
                            .interpolation(.none)   // keeps pixel art sharp
                            .frame(width: 25, height: 25) // smaller size
                            
                        Text(steps.todaySteps.formattedString())
                            .font(.custom("Press Start 2P", size: 13))
                    }
                    HStack {
                        Image("Coin")
                            .interpolation(.none)
                            .padding(.leading, 5)
                            
                        Text(steps.money.formattedString())
                            .font(.custom("Press Start 2P", size: 13))
                            .padding(.leading, 6)
                    }
                }
                .padding()
            }
        }
        .font(.callout.monospacedDigit())
        .padding(10)
        .background(.ultraThinMaterial) // nice blur
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(radius: 4)
        .accessibilityElement(children: .combine)
        .onAppear {
            steps.fetchTodaySteps()
        }

    }
}

#Preview {
    StatsDisplay()
        .environmentObject(StepManager())

}
