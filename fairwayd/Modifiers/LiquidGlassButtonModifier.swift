//
//  LiquidGlassModifier.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 7/26/26.
//

import SwiftUI

struct LiquidGlassModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
        } else {
            content
                .buttonStyle(.borderless)
        }
    }
}

extension View {
    func liquidGlass() -> some View {
        modifier(LiquidGlassModifier())
    }
}


