//
//  ContentView.swift
//  On-DeviceLiveness
//
//  Created by Hutomo on 12/11/24.
//

import CoreData
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink {
                    FaceDetectionVisionViewContainer()
                } label: {
                    Text("Face Detection Vision")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
