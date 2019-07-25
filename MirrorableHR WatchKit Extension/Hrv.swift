//
//  Hrv.swift
//  MirrorableHR WatchKit Extension
//
//  Created by Jacopo Mangiavacchi on 7/23/19.
//  Copyright © 2019 Jacopo Mangiavacchi. All rights reserved.
//

import Foundation

// SDNN formula from https://www.kubios.com/about-hrv/

struct Hrv {
    static func ssdnAverageFunction(_ samples: [Double]) -> Double {
        let size = samples.count
        let avg = samples.reduce(0.0, +) / Double(size)
        let sumOfSquaredAvgDiff = samples.map{ pow($0 - avg, 2.0) }.reduce(0.0, +)
        
        let sdnn = sqrt(sumOfSquaredAvgDiff / Double(size - 1))
        return sdnn
    }

    private var ringAverage: RingAverage

    var average: Double {
        get {
            return ringAverage.average
        }
    }
    
    init(size: Int = 50) {
        self.ringAverage = RingAverage(size: size, averageFunc: Hrv.ssdnAverageFunction)
    }
    
    mutating func reset() {
        self.ringAverage.reset()
    }
    
    mutating func addSample(_ value: Double) -> Double {
        return ringAverage.addSample(value)
    }
}
