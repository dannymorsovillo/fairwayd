//
//  LiquidGlassSurfaceModifier.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 7/27/26.
//

import SwiftUI
    
struct LiquidGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(Color(.systemGray6))
                .cornerRadius(10)
        }
    }
}

extension View {
    func liquidGlassSurface(cornerRadius: CGFloat = 10) -> some View {
        modifier(LiquidGlassSurfaceModifier(cornerRadius: cornerRadius))
    }
}

