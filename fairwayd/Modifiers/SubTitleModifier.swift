//
//  SubTitleModifier.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 8/5/26.
//

import SwiftUI

struct SubTitleModifier: ViewModifier {
    let subTitle: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .navigationSubtitle(subTitle)
        } else {
            content
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            Text(subTitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
        }
    }
}

extension View {
    func subTitleCreator(subTitle: String) -> some View {
        modifier(SubTitleModifier(subTitle: subTitle))
    }
}
