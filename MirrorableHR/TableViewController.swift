//
//  TableViewController.swift
//  MirrorableHR
//
//  Created by Jacopo Mangiavacchi on 11/18/17.
//  Copyright © 2017 Jacopo Mangiavacchi. All rights reserved.
//

import UIKit
import HealthKit
import WatchConnectivity
import UserNotifications

struct HRDataView {
    let time: String
    var min: Float
    var max: Float
    var count: Int
}

class TableViewController: UITableViewController {

    let healthStore = HKHealthStore()
    let hrUnit = HKUnit(from: "count/min")
    var hrData = [HKQuantitySample]()
    var hrDataView = [HRDataView]()
    var query: HKQuery!
    
    var session : WCSession!
    let center = UNUserNotificationCenter.current()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        refreshControl = UIRefreshControl()
        tableView.refreshControl = refreshControl
        
        refreshControl?.addTarget(self, action: #selector(refreshHRData(_:)), for: .valueChanged)
        refreshControl?.tintColor = UIColor(red:0.25, green:0.72, blue:0.85, alpha:1.0)
        refreshControl?.attributedTitle = NSAttributedString(string: "Quering HealthKit ...", attributes: nil)
        
        guard HKHealthStore.isHealthDataAvailable() == true else {
            print("not available")
            return
        }
        
        guard let hrQuantityType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else {
            print("not allowed")
            return
        }
        
        let dataTypes: Set<HKQuantityType> = [hrQuantityType]
        
        healthStore.requestAuthorization(toShare: nil, read: dataTypes) { (success, error) -> Void in
            if success {
                let day = Date(timeIntervalSinceNow: -1*24*60*60) // one day ago
                self.query = self.createheartRateQuery(day)
                self.healthStore.execute(self.query)
            }
            else {
                print("not allowed")
            }
        }
        
        let options: UNAuthorizationOptions = [.alert, .sound, .criticalAlert];
        center.requestAuthorization(options: options) {
            (granted, error) in
            if !granted {
                print("Handle this !!")
            }
        }
        
        center.delegate = self
        
        if WCSession.isSupported() {
            session = WCSession.default
            session.delegate = self
            session.activate()
            
            watchConnectionStatus()
        }
    }
    
    func watchConnectionStatus(){
        print("isPaired",session.isPaired)
        print("session.isWatchAppInstalled",session.isWatchAppInstalled)
        print(session.watchDirectoryURL)
    }
    
    @objc private func refreshHRData(_ sender: Any) {
        hrDataView.removeAll()
        hrData.removeAll()
        tableView.reloadData()
        let day = Date(timeIntervalSinceNow: -1*24*60*60) // one day ago
        query = createheartRateQuery(day)
        self.healthStore.execute(query)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    
    func createheartRateQuery(_ startDate: Date) -> HKQuery {
        let typeHR = HKQuantityType.quantityType(forIdentifier: .heartRate)
        let predicate: NSPredicate? = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: HKQueryOptions.strictStartDate)
        
        let squery = HKSampleQuery(sampleType: typeHR!, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (query, samples, error) in
            DispatchQueue.main.async(execute: {() -> Void in
                guard error == nil, let hrSamples = samples as? [HKQuantitySample] else {return}
                
                self.hrData.append(contentsOf: hrSamples)
                self.refreshHrDataView()
                self.refreshControl?.endRefreshing()
                self.tableView.reloadData()
            })
        }
        
        return squery
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return hrDataView.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "hrCell", for: indexPath)

        let dataView = hrDataView[indexPath.row]

        cell.textLabel?.text = String(format: "%.1f < %.1f (%d)", dataView.min, dataView.max, dataView.count)
        cell.detailTextLabel?.text = dataView.time
        
        return cell
    }
    
    func refreshHrDataView() {
        hrData.sort { $0.startDate > $1.startDate }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd hh:mm"

        var newHrDataView: HRDataView? = nil
        
        for sample in hrData {
            if let newData = newHrDataView {
                let value = Float(sample.quantity.doubleValue(for: self.hrUnit))
                let time = dateFormatter.string(from: sample.startDate)

                if time == newData.time {
                    newHrDataView!.count += 1
                    newHrDataView!.min = min(newHrDataView!.min, value)
                    newHrDataView!.max = max(newHrDataView!.max, value)
                }
                else {
                    hrDataView.append(newData)
                    newHrDataView = HRDataView(time: time, min: value, max: value, count: 1)
                }
                
            }
            else {
                let value = Float(sample.quantity.doubleValue(for: self.hrUnit))
                let time = dateFormatter.string(from: sample.startDate)

                newHrDataView = HRDataView(time: time, min: value, max: value, count: 1)
            }
        }
        
        if let newData = newHrDataView {
            hrDataView.append(newData)
        }
    }
}

extension TableViewController : WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        watchConnectionStatus()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        let message = message["message"] as! String
        print(message)
        
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState == .active {
                let alert = UIAlertController(title: "Watch Alert", message: message, preferredStyle: .actionSheet)
                alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                self.present(alert, animated: true)
            }
            else {
                let content = UNMutableNotificationContent()
                content.title = "MirrorableHR"
                content.body = "Alert ..."
                content.sound = UNNotificationSound.defaultCriticalSound(withAudioVolume: 1.0)
                content.categoryIdentifier = "MirrorableHRCategory"
                
                //            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1,
                //                                                            repeats: false)
                
                let snoozeAction = UNNotificationAction(identifier: "Snooze",
                                                        title: "Snooze", options: [])
                let deleteAction = UNNotificationAction(identifier: "Delete",
                                                        title: "Delete", options: [.destructive])
                
                let category = UNNotificationCategory(identifier: "MirrorableHRCategory",
                                                      actions: [snoozeAction,deleteAction],
                                                      intentIdentifiers: [], options: [])
                
                self.center.setNotificationCategories([category])
                
                let identifier = "MirrorableHRLocalNotification"
                let request = UNNotificationRequest(identifier: identifier,
                                                    content: content, trigger: nil)
                self.center.add(request, withCompletionHandler: { (error) in
                    if let error = error {
                        print(error)
                    }
                })
            }
        }
        
        // replyHandler(["msg":"successfully received from iPhone"])
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
    }
}

extension TableViewController : UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Play sound and show alert to the user
        completionHandler([.alert,.sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        // Determine the user action
        switch response.actionIdentifier {
        case UNNotificationDismissActionIdentifier:
            print("Dismiss Action")
        case UNNotificationDefaultActionIdentifier:
            print("Default")
        case "Snooze":
            print("Snooze")
        case "Delete":
            print("Delete")
        default:
            print("Unknown action")
        }
        completionHandler()
    }
}

