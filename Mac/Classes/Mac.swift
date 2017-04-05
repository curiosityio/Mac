//
//  Mac.swift
//  Pods
//
//  Created by Levi Bostian on 4/4/17.
//
//

import Foundation
import RxSwift

class Mac {
    
    static let sharedInstance = Mac()
    private init() {
    }
    
    func runTasks() {
        _ = PendingApiTasksRunner.sharedInstance.runPendingTasks()
        .subscribeCompletable({
            MacConfigInstance?.macTasksRunnerManager.doneRunningTasks(tempInstance: false)
        }) { (error) in
            MacConfigInstance?.macTasksRunnerManager.errorRunningTasks(tempInstance: false, error: error)
        }
    }
    
    func runTempInstanceTasks() {
        _ = PendingApiTasksRunner.sharedInstance.runPendingTasks(useTempRealmInstance: true)
            .subscribeCompletable({
                MacConfigInstance?.macTasksRunnerManager.doneRunningTasks(tempInstance: true)
            }) { (error) in
                MacConfigInstance?.macTasksRunnerManager.errorRunningTasks(tempInstance: true, error: error)
        }
    }
    
    func runTask(_ pendingApiTask: PendingApiTask, useTempRealmInstance: Bool = false) {
        _ = PendingApiTasksRunner.sharedInstance.runSingleTask(pendingApiTask: pendingApiTask, useTempRealmInstance: useTempRealmInstance)
            .subscribeCompletable({
                MacConfigInstance?.macTasksRunnerManager.doneRunningSingleTask(pendingApiTask: pendingApiTask)
            }) { (error) in
                MacConfigInstance?.macTasksRunnerManager.errorRunningSingleTask(pendingApiTask: pendingApiTask, error: error)
        }
    }
    
    func subNumberPendingTasks() -> BehaviorSubject<Int> {
        return PendingApiTasksRunner.sharedInstance.numberPendingApiTasksRemaining
    }
    
    func subNumberTempPendingTasks() -> BehaviorSubject<Int> {
        return PendingApiTasksRunner.sharedInstance.numberTempPendingApiTasksRemaining
    }

}
