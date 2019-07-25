//
//  RingAverage.swift
//  MirrorableHR WatchKit Extension
//
//  Created by Jacopo Mangiavacchi on 7/24/19.
//  Copyright © 2019 Jacopo Mangiavacchi. All rights reserved.
//

import Foundation

struct RingAverage {
    private var samples: [Double]
    private var size: Int
    private var count: Int
    private var full: Bool
    
    typealias AverageFunctionDefinition = ([Double]) -> Double
    
    private var averageFunc: AverageFunctionDefinition
    private(set) var average: Double
    
    init(size: Int = 50, averageFunc: @escaping AverageFunctionDefinition) {
        self.averageFunc = averageFunc
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
    
    mutating func addSample(_ value: Double) -> Double
    {
        samples[count] = value
        count = (count + 1) % size
        
        if count == 0 {
            full = true
        }
        
        if full {
            average = averageFunc(samples)
            return average
        }
        
        return -1.0
    }
}
