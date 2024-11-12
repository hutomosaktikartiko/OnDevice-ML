//
//  OnDevice_MLApp.swift
//  OnDevice-ML
//
//  Created by Hutomo on 12/11/24.
//

import SwiftUI

@main
struct OnDevice_MLApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
