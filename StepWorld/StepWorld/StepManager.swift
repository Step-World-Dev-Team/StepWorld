//
//  StepManager.swift
//  StepWorld
//
//  Created by Andre Bortoloto Lebeis on 10/8/25.
//

import Combine
import Foundation
import HealthKit

//start of today's date
extension Date {
    static var startOfDay: Date {
        Calendar.current.startOfDay(for: Date())
    }
}

class StepManager: ObservableObject {
    
    let healthStore = HKHealthStore() //allows fetching data
    
    @Published var todaySteps: Double = 0
    
    @Published var money: Double = 0

    init() {
        let steps = HKQuantityType(.stepCount)  //figure out if we have to use HKQuantityType?
        
        let healthTypes: Set = [steps]
        
        //request authorization from health app
        Task {
            do {
                try await healthStore.requestAuthorization(toShare: [], read: healthTypes)  //wanted to use steps instead of healthTypes
            } catch {
                print("error fetching health data")
            }
        }
    }
    
    func fetchTodaySteps() {
        let steps = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(withStart: .startOfDay, end: Date())  //what day are we grabbing the info from? today? ok.
        let query = HKStatisticsQuery(quantityType: steps, quantitySamplePredicate: predicate) { _, result, error in
            guard let quantity = result?.sumQuantity(), error == nil else {
                print("error in fetching today's step data")
                return
            }
            
            let stepCount = quantity.doubleValue(for: .count())
        
            
            DispatchQueue.main.async {
                self.todaySteps = stepCount
                self.money = stepCount
            }
        }
        
        healthStore.execute(query)
    }
}

extension Double {
    func formattedString() -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 0
        
        return numberFormatter.string(from: NSNumber(value: self))!
    }
}
