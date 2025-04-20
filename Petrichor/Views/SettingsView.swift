//
//  SettingsView.swift
//  Petrichor
//
//  Created by Kushal Pandya on 2025-04-19.
//


import SwiftUI

struct SettingsView: View {
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("closeToTray") private var closeToTray = true
    @AppStorage("showNotifications") private var showNotifications = true
    
    var body: some View {
        Form {
            Section(header: Text("General")) {
                Toggle("Start at login", isOn: $startAtLogin)
                Toggle("Close to tray instead of quitting", isOn: $closeToTray)
                Toggle("Show notifications for new tracks", isOn: $showNotifications)
            }
            
            Section(header: Text("Library")) {
                Button("Reset Library Cache") {
                    // This would clear the cache in a real implementation
                }
            }
            
            Section(header: Text("About")) {
                Text("Petrichor Music Player")
                    .font(.headline)
                Text("Version 1.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 400, maxWidth: 600, minHeight: 300)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}