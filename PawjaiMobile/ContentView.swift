//
//  ContentView.swift
//  PawjaiMobile
//
//  Created by Purin Buriwong on 3/9/2568 BE.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        WebViewContainer(url: URL(string: "https://pawjai.co/auth/callback")!)
    }
}

#Preview {
    ContentView()
}
