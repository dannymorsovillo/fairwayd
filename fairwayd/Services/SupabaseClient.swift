//
//  SupabaseClient.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/27/25.
//

import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: APIConfig.supabaseURL)!,
            supabaseKey: APIConfig.supabaseAnonKey
        )
    }
    
}
