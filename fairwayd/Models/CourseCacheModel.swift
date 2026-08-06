//
//  CourseCacheModel.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 8/6/26.
//

import Foundation
import CoreLocation

struct CachedData {
    let courses: [GolfCourse]
    let timestamp: Date
    let location: CLLocation
}
