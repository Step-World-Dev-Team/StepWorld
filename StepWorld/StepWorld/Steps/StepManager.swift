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
    
    @Published var todaySteps: Int = 0
    @Published var balance: Int = 0
    
    var userId: String?
    
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
    
    // convenient way of fetching steps
    func fetchTodaySteps() {
        let steps = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(withStart: .startOfDay, end: Date())  //what day are we grabbing the info from? today? ok.
        let query = HKStatisticsQuery(quantityType: steps, quantitySamplePredicate: predicate) { _, result, error in
            guard let quantity = result?.sumQuantity(), error == nil else {
                print("error in fetching today's step data")
                return
            }
            
            let stepCount = Int(quantity.doubleValue(for: .count()))
            
            DispatchQueue.main.async {
                self.todaySteps = stepCount
            }
        }
        
        healthStore.execute(query)
    }
    
    // Convenient way of refreshing shown balance
    // For displaying in shop
    func refreshBalance() {
        guard let uid = userId else { return }
        Task {
            do {
                let bal = try await UserManager.shared.getBalance(userId: uid)
                DispatchQueue.main.async { self.balance = bal }
            } catch {
                print("Failed to fetch balance: \(error)")
            }
        }
    }
    
    // Spend from balance (shop/upgrades)
    func attemptPurchase(cost: Int, onSuccess: (() -> Void)? = nil, onInsufficient: (() -> Void)? = nil) {
        guard let uid = userId else { return }
        Task {
            do {
                let newBalance = try await UserManager.shared.spend(userId: uid, amount: cost)
                DispatchQueue.main.async {
                    self.balance = newBalance
                    onSuccess?()
                }
            } catch {
                if case SpendError.insufficientFunds = error {
                    DispatchQueue.main.async { onInsufficient?() }
                } else {
                    print("Purchase error: \(error)")
                }
            }
        }
    }
    
    // syncs data collected with database
    func syncToday() async {

        let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let predicate = HKQuery.predicateForSamples(withStart: .startOfDay, end: Date())
        
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let query = HKStatisticsQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate
            ) { [weak self] _, result, error in
                guard let self else {
                    cont.resume()
                    return
                }
                
                guard let quantity = result?.sumQuantity(), error == nil else {
                    print("error in fetching today's step data: \(String(describing: error))")
                    cont.resume()
                    return
                }
                
                let stepCount = Int(quantity.doubleValue(for: .count()))
                DispatchQueue.main.async {
                    self.todaySteps = stepCount
                }
                
                guard let uid = self.userId else {
                    cont.resume()
                    return
                }
                
                Task {
                    do {
                        let outcome = try await UserManager.shared.creditStepsAndSyncDaily(
                            userId: uid,
                            date: Date(),
                            newStepCount: stepCount
                        )
                        DispatchQueue.main.async {
                            self.balance = outcome.balance
                        }
                    } catch {
                        print("Failed to persist daily metrics: \(error)")
                    }
                    cont.resume()   // ✅ return from syncToday() *after* DB is updated
                }
            }
            self.healthStore.execute(query)
        }
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
