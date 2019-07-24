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
    private var samples: [Double]
    private var size: Int
    private var count: Int
    private var full: Bool

    private(set) var sdnn: Double
    
    init(size: Int = 50) {
        self.sdnn = 0.0
        self.count = 0
        self.full = false
        self.size = size
        samples = [Double].init(repeating: 0.0, count: size)
    }
    
    mutating func reset() {
        self.sdnn = 0.0
        self.count = 0
        self.full = false
        samples = [Double].init(repeating: 0.0, count: size)
    }
    
    mutating func addSample(_ value: Double) -> Double
    {
        samples[count] = value // 1000 / value
        count = (count + 1) % size

        if count == 0 {
            full = true
        }

        if full {
            let avg = samples.reduce(0.0, +) / Double(size)
            let sumOfSquaredAvgDiff = samples.map{ pow($0 - avg, 2.0) }.reduce(0.0, +)
            
            sdnn = sqrt(sumOfSquaredAvgDiff / Double(size - 1))
            return sdnn // sdnn * 100
        }
        
        return -1.0
    }
}
