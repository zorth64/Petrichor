//
//  CreatePlaylistSheet.swift
//  Petrichor
//
//  Created by Kushal Pandya on 2025-05-22.
//


import SwiftUI

struct CreatePlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Create Playlist")
                .font(.title)
            
            Text("Coming soon...")
                .foregroundColor(.secondary)
            
            Button("Close") {
                dismiss()
            }
        }
        .padding()
        .frame(minWidth: 300, minHeight: 200)
    }
}

#Preview {
    CreatePlaylistSheet()
}