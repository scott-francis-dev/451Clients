//
//  AppTopHeader.swift
//  thesis
//
//  Shared top-of-screen header showing the app wordmark.
//

import SwiftUI

/// A lightweight header displaying the "thesis" wordmark.
/// Used at the top of the standalone flow screens.
struct AppTopHeader: View {
    var body: some View {
        HStack {
            Text("thesis")
                .font(.custom("Courier New", size: 24))
                .fontWeight(.bold)
                .tracking(8)
                .foregroundColor(.black)
                .textCase(.lowercase)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

#Preview {
    AppTopHeader()
}
