//
//  ContentView.swift
//  StepWorld
//
//  Created by Isai soria on 10/2/25.
//

import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var steps: StepManager
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
