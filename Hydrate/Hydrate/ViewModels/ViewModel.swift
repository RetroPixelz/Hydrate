//
//  ViewModel.swift
//  Hydrate
//
//  Created by Justin Koster on 2023/09/02.
//

import Foundation
import Firebase
import FirebaseFirestore
import HealthKit

class ViewModel: ObservableObject {
    let db = Firestore.firestore()

    let healthStore = HKHealthStore()
    
    var waterIntake: Double = 0
    var stepsCount: Double = 0
    var calorieCount: Double = 0
    
//    UserDefaults(suiteName: "group.Hydrate")?.set(waterIntakeValue, forKey: "WaterIntakeValue")

    func createUserInDB(username: String, email: String, userId: String) {
            db.collection("users")
                .document(userId)
                .setData([
                    "username": username,
                    "email": email,
                    "steps": "",
                    "calories": "",
                    "water": ""
                ]) { err in
                    if let err = err {
                        print("There was an error writing the document: \(err)")
                    } else {
                        print("Document was writed successfully")
                    }
                }
        }
    

    
    
    
    init() {
            // Check access to user data
            if(HKHealthStore.isHealthDataAvailable()) {
                // This will be all the activity stats
                let steps = HKQuantityType(.stepCount)
                let water = HKQuantityType(.dietaryWater)
                let calories = HKQuantityType(.activeEnergyBurned)
                    
                // HealthTypes we want access to
                let healthTypes: Set = [steps, water, calories]
                
                let writeTypes: Set<HKSampleType> = [HKSampleType.quantityType(forIdentifier: .dietaryWater)!]
                
                Task {
                    do {
                        try await healthStore.requestAuthorization(toShare: writeTypes, read: healthTypes)
    
                        fetchSteps()
                        fetchWater()
                        fetchCalories()
                    } catch {
                        print("Error fetching data")
                    }
                }
            }
        }
    
        func fetchSteps() {
            let steps = HKQuantityType(.stepCount)
    
            let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date())
    
            let query = HKStatisticsQuery(quantityType: steps, quantitySamplePredicate: predicate) {_, res, err in
                guard let quantity = res?.sumQuantity(), err == nil else {
                    print("Error fetching")
                    return
                }
    
                let stepCount = quantity.doubleValue(for: .count())
    
                self.stepsCount = stepCount
            }
    
            healthStore.execute(query)
        }
    
    
   
        func fetchWater() {
            let water = HKQuantityType(.dietaryWater)
    
            let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date())
    
            let query = HKStatisticsQuery(quantityType: water, quantitySamplePredicate: predicate) {_, res, err in
                guard let quantity = res?.sumQuantity(), err == nil else {
                    print("Error fetching")
                    return
                }
    
                let waterAmount = quantity.doubleValue(for: .liter())
    
                self.waterIntake = waterAmount
            }
    
            healthStore.execute(query)
        }
    
    func saveWaterIntake(amountInMilliliters: Double, date: Date) {
        let healthStore = HKHealthStore()

        // Create a quantity sample for water intake
        let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        let waterAmount = HKQuantity(unit: .liter(), doubleValue: amountInMilliliters)
        let waterSample = HKQuantitySample(type: waterType, quantity: waterAmount, start: date, end: date)

        // Save the water intake data
        healthStore.save(waterSample) { (success, error) in
            if success {
                // Water intake data saved successfully
                self.updateWaterIntake()
            } else {
                // Error occurred while saving data, handle accordingly
            }
        }
    }

    
    
    func fetchCalories() {
        let calories = HKQuantityType(.activeEnergyBurned)
        
        let  predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date())
        
        let query = HKStatisticsQuery(quantityType: calories, quantitySamplePredicate: predicate) {_, res, err in
            guard let quantity = res?.sumQuantity(), err == nil else {
                print("error fetching todays calories: \(err?.localizedDescription ?? "")")
                return
            }
            
            let calorieAmount = quantity.doubleValue(for: .kilocalorie())
          
            self.calorieCount = calorieAmount
            
        }
        
        //execute our query for the functionality to work
        healthStore.execute(query)
        
    }
    

    
    func updateWaterIntake() {
          guard let userId = Auth.auth().currentUser?.uid else {
              print("User is not authenticated.")
              return
          }
  
          let db = Firestore.firestore()
          let userRef = db.collection("users").document(userId)
          print("--------------\(waterIntake)")
  
          userRef.updateData([
              "water": waterIntake,
              "time": Date()
          ]) { error in
              if let error = error {
                  print("Error updating water document: \(error.localizedDescription)")
              } else {
                  print("water document updated successfully.")
              }
          }
        if let sharedUserDefaults = UserDefaults(suiteName: "group.Hydrate") {
                    sharedUserDefaults.set(waterIntake, forKey: "WaterIntakeValue")
                }
      }
    
    
    func updateFirebaseDocument() {
          guard let userId = Auth.auth().currentUser?.uid else {
              print("User is not authenticated.")
              return
          }
  
          let db = Firestore.firestore()
          let userRef = db.collection("users").document(userId)
          print("--------------\(stepsCount)")
  
          userRef.updateData([
              "steps": stepsCount,
              "water": waterIntake,
              "calories": calorieCount,
              "time": Date()
          ]) { error in
              if let error = error {
                  print("Error updating Firebase document: \(error.localizedDescription)")
              } else {
                  print("Firebase document updated successfully.")
              }
          }
      }
    }


