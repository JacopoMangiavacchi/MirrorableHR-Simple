//
//  Motion.swift
//  MirrorableHR WatchKit Extension
//
//  Created by Jacopo Mangiavacchi on 7/24/19.
//  Copyright © 2019 Jacopo Mangiavacchi. All rights reserved.
//

import Foundation

struct Motion {
    static func simpleAverageFunction(_ samples: [Double]) -> Double {
        let size = samples.count
        let avg = samples.reduce(0.0, +) / Double(size)
        return avg
    }
    
    private var ringAverage: RingAverage
    
    var average: Double {
        get {
            return ringAverage.average
        }
    }
    
    init(size: Int = 250) { // 5 secs
        self.ringAverage = RingAverage(size: size, averageFunc: Motion.simpleAverageFunction)
    }
    
    mutating func reset() {
        self.ringAverage.reset()
    }
    
    mutating func addSample(x: Double, y: Double, z: Double) -> Double
    {
        var motion = abs(x) + abs(y) + abs(z)
        motion = motion / 3
        motion = Double(round(100*motion)/100)

        return ringAverage.addSample(motion)
    }
}

