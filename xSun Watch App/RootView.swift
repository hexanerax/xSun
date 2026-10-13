//
//  RootView.swift
//  xSun Watch App
//
//  Created by Shubhankar Singh on 6/12/26.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink(destination: PhaseView()) {
                    Label("Phase", systemImage: "sun.lefthalf.filled")
                }

                NavigationLink(destination: DirectionView()) {
                    Label("Direction", systemImage: "location.fill.viewfinder")
                }
            }
            .navigationTitle("xSun")
            .navigationBarTitleDisplayMode(.large)
            .tint(.white)
        }
    }
}

#Preview {
    RootView()
}
