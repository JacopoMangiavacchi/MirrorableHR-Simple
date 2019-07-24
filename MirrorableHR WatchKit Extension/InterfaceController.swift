//
//  InterfaceController.swift
//  MirrorableHR WatchKit Extension
//
//  Created by Jacopo Mangiavacchi on 1/31/19.
//  Copyright © 2019 Jacopo Mangiavacchi. All rights reserved.
//

import WatchKit
import Foundation
import HealthKit
import CoreMotion
import WatchConnectivity

class InterfaceController: WKInterfaceController {
    
    typealias HKQueryUpdateHandler = ((HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Swift.Void)

    var authorized = false
    let healthStore = HKHealthStore()
    var workoutActive = false
    var workoutSession : HKWorkoutSession?
    let queue = OperationQueue()
    let motionManager = CMMotionManager()
    // The app is using 50hz data and the buffer is going to hold 1s worth of data.
    let sampleInterval = 1.0 / 50 // Parametrize this in settings !!
    var heartRateQuery : HKQuery?
    var wcSession : WCSession!
    let csvFileUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("motion.csv")
    
    var hrv = Hrv(size: 50) // Parametrize this in settings !!

    @IBOutlet private weak var startStopButton : WKInterfaceButton!
    @IBOutlet private weak var hrLabel: WKInterfaceLabel!
    @IBOutlet weak var hrvLabel: WKInterfaceLabel!
    @IBOutlet weak var motionLabel: WKInterfaceLabel!
    
    override func awake(withContext context: Any?) {
        super.willActivate()
        
        self.setTitle("MirrorHR")
        
        guard HKHealthStore.isHealthDataAvailable() == true else {
            displayNotAvailable()
            return
        }
        
        guard let hrQuantityType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else {
            displayNotAllowed()
            return
        }
        
        let dataTypes: Set<HKQuantityType> = [hrQuantityType]
        healthStore.requestAuthorization(toShare: nil, read: dataTypes) { (success, error) -> Void in
            if success {
                self.authorized = true
            }
            else {
                self.displayNotAllowed()
            }
        }
    }
    
    override func willActivate() {
        super.willActivate()
        
        if WCSession.isSupported() {
            wcSession = WCSession.default
            wcSession.delegate = self
            wcSession.activate()
        }
    }
    
    override func didDeactivate() {
        super.didDeactivate()
    }
    
    func displayNotAvailable() {
        hrLabel.setText("N/A")
    }
    
    func displayNotAllowed() {
        hrLabel.setText("n/a")
    }
    
    @IBAction func startStopSession() {
        if (self.workoutActive) {
            self.workoutActive = false
            self.startStopButton.setTitle("Start")
            stopWorkout()
        } else {
            self.workoutActive = true
            self.startStopButton.setTitle("Stop")
            startWorkout()
        }
    }
    
    @IBAction func sendAlert() {
        wcSession.sendMessage(["message":"Alert from Watch"], replyHandler: nil, errorHandler: nil)
    }
    
    @IBAction func sendFile() {
    }
    
    func stopWorkout() {
        self.workoutSession?.end()
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.stopDeviceMotionUpdates()
        }
    }
    
    func deleteFile() {
        do {
            try FileManager.default.removeItem(at: csvFileUrl)
        }
        catch let error as NSError {
            print("\(error)")
        }
    }
    
    func startWorkout() {
        guard workoutSession == nil else { return }
        
        hrv.reset()
        deleteFile()

        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = .mindAndBody
        workoutConfiguration.locationType = .unknown

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: workoutConfiguration)
            workoutSession?.delegate = self
        } catch {
        }
        
        self.workoutSession?.startActivity(with: nil)
        
        if !motionManager.isDeviceMotionAvailable {
            print("Device Motion is not available.")
            return
        }

        motionManager.deviceMotionUpdateInterval = sampleInterval
        motionManager.startDeviceMotionUpdates(to: queue) { (deviceMotion: CMDeviceMotion?, error: Error?) in
            if error != nil {
                print("Encountered error: \(error!)")
            }
            
            if deviceMotion != nil {
                self.processDeviceMotion(deviceMotion!)
            }
        }
    }
    
    func processDeviceMotion(_ deviceMotion: CMDeviceMotion) {
        let time = deviceMotion.timestamp
        let accelleration = deviceMotion.userAcceleration
//        let rotationRate = deviceMotion.rotationRate
//        let gravity = deviceMotion.gravity
//
//        let vector = [time,
//                      accelleration.x,
//                      accelleration.y,
//                      accelleration.z,
//                      rotationRate.x,
//                      rotationRate.y,
//                      rotationRate.z,
//                      gravity.x,
//                      gravity.y,
//                      gravity.z,
//                     ]
//
//        print(vector)

//        let csvText = "\(time),\(accelleration.x),\(accelleration.y),\(accelleration.z)"

        var motion = abs(accelleration.x) + abs(accelleration.y) + abs(accelleration.z)
        motion = motion / 3
        motion = Double(round(100*motion)/100)

        DispatchQueue.main.async {
            self.motionLabel.setText(String(format: "%.1f", motion))
        }

//        let csvText = "\(time),\(motion)"
//        do {
//            try csvText.write(to: csvFileUrl, atomically: true, encoding: String.Encoding.utf8)
//        } catch {
//            print("Failed to write file \(error)")
//        }
    }
    
    func getQuery(date: Date, identifier: HKQuantityTypeIdentifier) -> HKQuery? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        
        let datePredicate = HKQuery.predicateForSamples(withStart: date, end: nil, options: .strictStartDate )
        let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])
        let queryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates:[datePredicate, devicePredicate])
        
        let updateHandler: HKQueryUpdateHandler =
        { query, samples, deletedObjects, queryAnchor, error in
            
            if let quantitySamples = samples as? [HKQuantitySample] {
                self.processSamples(quantitySamples)
            }
        }
        
        let query = HKAnchoredObjectQuery(type: quantityType, predicate: queryPredicate, anchor: nil, limit: HKObjectQueryNoLimit, resultsHandler: updateHandler)
        
        query.updateHandler = updateHandler
        
        return query
    }
    
    func processSamples(_ samples: [HKQuantitySample]?) {
        guard let heartRateQuantityType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else { return }
        
        samples?.forEach { sample in
            switch sample.quantityType {
            case heartRateQuantityType:
                //Heart beat per Minute
                let heartRate = 60.0 * sample.quantity.doubleValue(for: HKUnit(from: "count/s"))
                let heartRateVariability = hrv.addSample(heartRate)
                
                DispatchQueue.main.async {
                    self.hrLabel.setText(String(format: "%.0f", heartRate))
                    self.hrvLabel.setText(String(format: "%.1f", heartRateVariability))
                }

            default:
                break
            }
        }
    }
}


extension InterfaceController: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        switch toState {
        case .running:
            workoutDidStart(date)
        case .ended:
            workoutDidEnd(date)
        default:
            break
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    }
    
    
    func workoutDidStart(_ date : Date) {
        hrLabel.setText("-")
        if let query = getQuery(date: date, identifier: HKQuantityTypeIdentifier.heartRate) {
            self.heartRateQuery = query
            healthStore.execute(query)
        } else {
            hrLabel.setText("/")
        }
    }
    
    func workoutDidEnd(_ date : Date) {
        if let q = self.heartRateQuery {
            healthStore.stop(q)
        }
        
        workoutSession = nil
    }
}

extension InterfaceController : WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
    }
}
