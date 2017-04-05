//
//  PendingApiTask.swift
//  Pods
//
//  Created by Levi Bostian on 4/3/17.
//
//

import Foundation
import RealmSwift
import Alamofire
import RxRealm

public protocol PendingApiTask {
    
    func queryForExistingTask() -> NSPredicate
    
    func canRunTask(realm: Realm) -> Bool
    
    var createdAt: Date { get set }
    var manuallyRunTask: Bool { get set }
    
    func getOfflineModelTaskRepresents(realm: Realm) -> OfflineCapableModel
    
    func getApiCall(realm: Realm) -> URLRequestConvertible
    
    func getApiErrorVo<ErrorVo: ErrorResponseVo>() -> ErrorVo?
    
    func processApiResponse(realm: Realm, response: Any?)
    
}
