//
//  Motion.swift
//  MirrorableHR WatchKit Extension
//
//  Created by Jacopo Mangiavacchi on 7/24/19.
//  Copyright © 2019 Jacopo Mangiavacchi. All rights reserved.
//

import Foundation

struct Motion {
    private var samples: [Double]
    private var size: Int
    private var count: Int
    private var full: Bool
    
    private(set) var average: Double
    
    init(size: Int = 250) { // 5 secs
        self.average = 0.0
        self.count = 0
        self.full = false
        self.size = size
        samples = [Double].init(repeating: 0.0, count: size)
    }
    
    mutating func reset() {
        self.average = 0.0
        self.count = 0
        self.full = false
        samples = [Double].init(repeating: 0.0, count: size)
    }
    
    mutating func addSample(x: Double, y: Double, z: Double) -> Double
    {
        var motion = abs(x) + abs(y) + abs(z)
        motion = motion / 3
        motion = Double(round(100*motion)/100)
        
        samples[count] = motion
        count = (count + 1) % size
        
        if count == 0 {
            full = true
        }
        
        if full {
            let avg = samples.reduce(0.0, +) / Double(size)
            return avg
        }
        
        return -1.0
    }
}
