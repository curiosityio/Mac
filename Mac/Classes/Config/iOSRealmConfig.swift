//
//  AndroidRealmConfig.swift
//  Pods
//
//  Created by Levi Bostian on 4/4/17.
//
//

import Foundation

public class iOSRealmConfigBuilder {
    
    var realmInstanceConfig: RealmInstanceConfig?
    var migrationManager: RealmMigrationManager?
    
    typealias BuilderClosure = (iOSRealmConfigBuilder) -> ()
    
    init(buildClosure: BuilderClosure) {
        buildClosure(self)
    }
    
}

internal var iOSRealmConfigInstance: iOSRealmConfig? = nil
public struct iOSRealmConfig {
    
    var realmInstanceConfig: RealmInstanceConfig?
    var migrationManager: RealmMigrationManager?
    
    init?(builder: iOSRealmConfigBuilder) {
        if let instanceConfig = builder.realmInstanceConfig, let migrationManager = builder.migrationManager {
            self.realmInstanceConfig = instanceConfig
            self.migrationManager = migrationManager
            
            iOSRealmConfigInstance = self
        } else {
            return nil
        }
    }
    
}
