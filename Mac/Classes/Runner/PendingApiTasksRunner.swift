//
//  PendingApiTasksRunner.swift
//  Pods
//
//  Created by Levi Bostian on 4/3/17.
//
//

import Foundation
import RxSwift
import RealmSwift
import Alamofire
import ObjectMapper
import iOSBoilerplate

public class PendingApiTasksRunner: NSObject {
    
    internal static let sharedInstance = PendingApiTasksRunner()
    private override init() {
        super.init()
        numberPendingApiTasksRemaining = BehaviorSubject(value: getNumberPendingApiTasksRemainingFromRealm(useTempRealmInstance: false))
        numberTempPendingApiTasksRemaining = BehaviorSubject(value: getNumberPendingApiTasksRemainingFromRealm(useTempRealmInstance: true))
    }
    
    private var lastFailedApiTaskCreatedAtTime: Date? = nil // when an API task fails because of an API error (user error from API), we keep track of that created time to allow us to skip this parent and move onto the next group of tasks.
    
    private var _currentlyRunningTasks: Bool = false
    private var currentlyRunningTasks: Bool {
        get {
            var safeCurrentlyRunning = false
            synchronizedBlock(lockedObject: self._currentlyRunningTasks as AnyObject) {
                safeCurrentlyRunning = self._currentlyRunningTasks
            }
            return safeCurrentlyRunning
        }
        set (value) {
            synchronizedBlock(lockedObject: self._currentlyRunningTasks as AnyObject) {
                self._currentlyRunningTasks = value
            }
        }
    }
    
    // Going to try to use without the synchronizedBlock. The get {} worries me because it is creating a copy of the subject. I need the original one to keep reference to all the listeners.
    public var numberPendingApiTasksRemaining: BehaviorSubject<Int>!
    public var numberTempPendingApiTasksRemaining: BehaviorSubject<Int>!
    
    internal func getNumberPendingApiTasksOnce() -> Int {
        return try! numberPendingApiTasksRemaining.value()
    }
    
    internal func getNumberTempInstancePendingApiTasksOnce() -> Int {
        return try! numberTempPendingApiTasksRemaining.value()
    }
    
    fileprivate func getNumberPendingApiTasksRemainingFromRealm(useTempRealmInstance: Bool) -> Int {
        let realm = getRealmInstance(tempInstance: useTempRealmInstance)
        var numberPendingTasks = 0
        PendingApiTasksManager.pendingApiTaskTypes.forEach { (task) in
            numberPendingTasks += realm.objects(task as! Object.Type).count
        }
        
        return numberPendingTasks
    }
    
    fileprivate func getRealmInstance(tempInstance: Bool) -> Realm {
        return tempInstance ? RealmInstanceManager.sharedInstance.getTempInstance() : RealmInstanceManager.sharedInstance.getInstance()
    }
    
    internal func runSingleTask(pendingApiTask: PendingApiTask, useTempRealmInstance: Bool = false) -> Completable {
        return Completable.create(subscribe: { (observer) -> Disposable in
            var pendingApiTaskToRun = pendingApiTask
            if (pendingApiTask as! Object).isManaged() {
                pendingApiTaskToRun = Object(value: pendingApiTask as! Object) as! PendingApiTask
            }
            
            _ = self.runTask(pendingApiTaskController: pendingApiTaskToRun, useTempRealmInstance: useTempRealmInstance)
            .subscribeCompletable({ 
                observer(CompletableEvent.completed)
            }, onError: { (error) in
                observer(CompletableEvent.error(error))
            })
            
            return Disposables.create()
        })
    }
    
    internal func runPendingTasks(useTempRealmInstance: Bool = false) -> Completable {
        if currentlyRunningTasks || !(MacConfigInstance?.macTasksRunnerManager.shouldRunApiTasks() ?? true) {
            return Completable.empty().subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
        } else {
            currentlyRunningTasks = true
            
            return Completable.create(subscribe: { (observer) -> Disposable in
                func getNextTaskToRun(realm: Realm) -> PendingApiTask? {
                    if useTempRealmInstance {
                        self.numberTempPendingApiTasksRemaining.onNext(self.getNumberPendingApiTasksRemainingFromRealm(useTempRealmInstance: true))
                    } else {
                        self.numberPendingApiTasksRemaining.onNext(self.getNumberPendingApiTasksRemainingFromRealm(useTempRealmInstance: false))
                    }
                    
                    var nextAvailableApiTaskToRun: PendingApiTask?
                    PendingApiTasksManager.pendingApiTaskTypes.forEach({ (task) in
                        let getAllPendingApiTasksQuery = realm.objects(task as! Object.Type)
                        var getAllPendingApiTasksQueryFilter = "manuallyRunTask = false"
                        
                        if let lastFailedApiTaskCreatedAtTime = self.lastFailedApiTaskCreatedAtTime {
                            getAllPendingApiTasksQueryFilter += " createdAt > \(lastFailedApiTaskCreatedAtTime)"
                        }
                        
                        getAllPendingApiTasksQuery.filter(NSPredicate(format: getAllPendingApiTasksQueryFilter)).sorted(byKeyPath: "createdAt", ascending: true).forEach({ (apiTask) in
                            if (apiTask as! PendingApiTask).canRunTask(realm: realm) {
                                nextAvailableApiTaskToRun = (apiTask as! PendingApiTask)
                            }
                        })
                    })
                    
                    return nextAvailableApiTaskToRun
                }
                
                func runNextPendingApiTask() {
                    func stopRunningApiTasks(error: Error? = nil) {
                        self.lastFailedApiTaskCreatedAtTime = nil
                        self.currentlyRunningTasks = false
                        if let error = error {
                            observer(CompletableEvent.error(error))
                        } else {
                            observer(CompletableEvent.completed)
                        }
                    }
                    
                    let realm: Realm = self.getRealmInstance(tempInstance: useTempRealmInstance)
                    if let nextTaskToRun: PendingApiTask = getNextTaskToRun(realm: realm) {
                        let apiSyncController: PendingApiTask = Object(value: nextTaskToRun as! Object) as! PendingApiTask
                        
                        _ = self.runTask(pendingApiTaskController: apiSyncController, useTempRealmInstance: useTempRealmInstance)
                            .subscribeCompletable({
                                runNextPendingApiTask()
                            }, onError: { (error) in
                                // TODO don't know the equivalent in Alamofire for no internet connection exception.
                                //                                if (error is NoInternetConnectionException || error is APIDownException) {
                                //                                    stopRunningApiTasks(error: error)
                                //                                } else {
                                // If API comes back with error, we don't want to block *all* API tasks. Skip this parent and all it's children and move onto the next.
                                self.lastFailedApiTaskCreatedAtTime = apiSyncController.createdAt
                                runNextPendingApiTask()
                                //                                }
                            })
                    } else {
                        stopRunningApiTasks()
                    }
                }
                
                runNextPendingApiTask()
                return Disposables.create()
            }).subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
        }
    }
    
    fileprivate func runTask(pendingApiTaskController: PendingApiTask, useTempRealmInstance: Bool) -> Completable {
        return Completable.create(subscribe: { (observer) -> Disposable in
            var apiCall: URLRequestConvertible? = nil
            let realm = self.getRealmInstance(tempInstance: useTempRealmInstance)
            try! realm.write {
                var modelForTask: OfflineCapableModel = pendingApiTaskController.getOfflineModelTaskRepresents(realm: realm)
                modelForTask.apiSyncInProgress = true
                modelForTask.statusUpdate(task: pendingApiTaskController, status: OfflineCapableModelStatus.RUNNING, error: nil)
                
                apiCall = pendingApiTaskController.getApiCall(realm: realm)
            }
            
            // We save this to compare later on. If created_at times dont line up, then the model has been edited since API call triggered.
            NSUserDefaultsUtil.saveInt("current_api_sync_task_created_at", value: pendingApiTaskController.createdAt.getIntTimeInverval())
            
            _ = ApiNetworkingService.executeApiCall(call: apiCall!, errorVo: pendingApiTaskController.getApiErrorVo() ?? ErrorVo())
                .subscribeSingle({ (apiResponse: Any?) in
                    let realm = self.getRealmInstance(tempInstance: useTempRealmInstance)
                    try! realm.write {
                        pendingApiTaskController.processApiResponse(realm: realm, response: apiResponse)
                        
                        var managedModelPendingApiTaskRepresents: OfflineCapableModel = pendingApiTaskController.getOfflineModelTaskRepresents(realm: realm)
                        managedModelPendingApiTaskRepresents.apiSyncInProgress = false
                        managedModelPendingApiTaskRepresents.statusUpdate(task: pendingApiTaskController, status: OfflineCapableModelStatus.SUCCESS, error: nil)
                        
                        // If created_at times before and after API call are the same, the model has not been updated by user action and we can safely delete this task and not run again. (update tasks can update during API call)
                        let managedOriginalPendingApiTask: PendingApiTask = realm.objects(pendingApiTaskController.self as! Object.Type).filter(pendingApiTaskController.queryForExistingTask()) as! PendingApiTask
                        if NSUserDefaultsUtil.getInt("current_api_sync_task_created_at") == managedOriginalPendingApiTask.createdAt.getIntTimeInverval() {
                            realm.delete(managedOriginalPendingApiTask as! Object)
                            managedModelPendingApiTaskRepresents.numberPendingApiSyncs -= 1
                        }
                    }
                    observer(CompletableEvent.completed)
                }, onError: { (error) in
                    let realm = self.getRealmInstance(tempInstance: useTempRealmInstance)
                    try! realm.write {
                        var managedModelPendingApiTaskRepresents: OfflineCapableModel = pendingApiTaskController.getOfflineModelTaskRepresents(realm: realm)
                        managedModelPendingApiTaskRepresents.apiSyncInProgress = false
                        managedModelPendingApiTaskRepresents.statusUpdate(task: pendingApiTaskController, status: OfflineCapableModelStatus.ERROR, error: error)
                    }
                    observer(CompletableEvent.error(error))
                })
            return Disposables.create()
        })
    }
    
}
