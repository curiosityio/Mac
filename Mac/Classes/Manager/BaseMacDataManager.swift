//
//  BaseMacDataManager.swift
//  Pods
//
//  Created by Levi Bostian on 4/4/17.
//
//

import Foundation
import RealmSwift
import RxSwift
import iOSBoilerplate

public class BaseMacDataManager {
    
    public func performRealmTransaction(changeData: @escaping ((Realm) -> Void), tempRealmInstance: Bool = false) {
        if Thread.isMainThread {
            fatalError("Cannot perform transaction from UI thread.")
        }
        
        let realm = getRealmInstance(tempInstance: tempRealmInstance)
        try! realm.write {
            changeData(realm)
        }
    }
    
    private func getRealmInstance(tempInstance: Bool) -> Realm {
        return tempInstance ? RealmInstanceManager.sharedInstance.getTempInstance() : RealmInstanceManager.sharedInstance.getInstance()
    }
    
    public func performRealmTransactionCompletable(changeData: @escaping (() -> Void), tempRealmInstance: Bool = false) -> Completable {
        return Completable.create(subscribe: { (observer) -> Disposable in
            if Thread.isMainThread {
                fatalError("Cannot perform transaction from UI thread.")
            }
            
            let realm = self.getRealmInstance(tempInstance: tempRealmInstance)
            try! realm.write(changeData)
            observer(CompletableEvent.completed)
            return Disposables.create()
        }).subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
    }
    
    public func getNextAvailableTempModelId() -> Double {
        let lastUsedId = NSUserDefaultsUtil.getDouble("preferences_last_used_temp_model_id") // TODO iosboidlerplate needs to support doubles.
        let nextAvailableTempModelId = lastUsedId - 1
        NSUserDefaultsUtil.saveDouble("preferences_last_used_temp_model_id", value: nextAvailableTempModelId)
        
        return nextAvailableTempModelId
    }
    
    public func createData<MODEL, PENDING_API_TASK_MODEL>(realm: Realm, data: MODEL, makeAdditionalRealmChanges: (MODEL) -> Void, pendingApiTask: PENDING_API_TASK_MODEL) where MODEL: Object, MODEL: OfflineCapableModel, PENDING_API_TASK_MODEL: Object, PENDING_API_TASK_MODEL: PendingApiTask {
        var managedData: MODEL = realm.add(data, update: true) as! MODEL
        
        makeAdditionalRealmChanges(managedData)
        
        realm.add(pendingApiTask)
        
        managedData.numberPendingApiSyncs += 1
    }
    
    // in future, make the pendingApiTask have have an interface for updating. We want to make sure that
    // only create, update, delete pending API models are calling the appropriate methods.
    public func updateData<MODEL, PENDING_API_TASK>(realm: Realm, modelClass: MODEL.Type, realmId: Int, updateValues: (MODEL) -> Void, pendingApiTask: PENDING_API_TASK) where MODEL: Object, MODEL: OfflineCapableModel, PENDING_API_TASK: Object, PENDING_API_TASK: PendingApiTask {
        guard var modelToUpdateValues = realm.objects(modelClass).filter(NSPredicate(format: "realmId == \(realmId)")).first else {
            fatalError("\(modelClass.className()) model to update is null. Cannot find it in Realm.")
        }
        
        updateValues(modelToUpdateValues)
        
        let existingPendingApiTask = realm.objects(pendingApiTask as! Object.Type).filter(pendingApiTask.queryForExistingTask()).first
        if existingPendingApiTask == nil {
            modelToUpdateValues.numberPendingApiSyncs += 1
        }
        realm.add(pendingApiTask, update: true) // updates created_at value which tells pending API task runner to run *another* update on the model.
    }
    
    public func deleteData<MODEL, PENDING_API_TASK>(realm: Realm, modelClass: MODEL.Type, realmId: Int, updateValues: ((MODEL) -> Void), pendingApiTask: PENDING_API_TASK? = nil) where MODEL: Object, MODEL: OfflineCapableModel, PENDING_API_TASK: Object, PENDING_API_TASK: PendingApiTask {
        guard var modelToUpdateValues = realm.objects(modelClass).filter(NSPredicate(format: "realmId == \(realmId)")).first else {
            fatalError("\(modelClass.className()) model to update is null. Cannot find it in Realm.")
        }
        
        modelToUpdateValues.deleted = true
        updateValues(modelToUpdateValues)
        
        if let pendingApiTask = pendingApiTask {
            if let _ = realm.objects(pendingApiTask.self as! Object.Type).filter(pendingApiTask.queryForExistingTask()).first as! PENDING_API_TASK? {
                modelToUpdateValues.numberPendingApiSyncs += 1
            }
            realm.add(pendingApiTask, update: true) // updates created_at value which tells pending API task runner to run *another* update on the model.
        }
    }
    
    public func undoDeleteData<MODEL>(realm: Realm, modelClass: MODEL.Type, realmId: Int, updateValues: (MODEL) -> Void) where MODEL: Object, MODEL: OfflineCapableModel {
        guard var modelToUpdateValues = realm.objects(modelClass).filter(NSPredicate(format: "realmId == \(realmId)")).first else {
            fatalError("\(modelClass.className()) model to update is null. Cannot find it in Realm.")
        }
        
        modelToUpdateValues.deleted = false
        updateValues(modelToUpdateValues)
    }
    
}
