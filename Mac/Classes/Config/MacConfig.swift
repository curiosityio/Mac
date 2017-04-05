//
//  MacConfig.swift
//  Pods
//
//  Created by Levi Bostian on 4/3/17.
//
//

import Foundation

public class MacConfigBuilder {
    
    var macProcessApiResponse: MacProcessApiResponse?
    var macErrorNotifier: MacErrorNotifier?
    var macTasksRunnerManager: MacTasksRunnerManager?
    
    typealias BuilderClosure = (MacConfigBuilder) -> ()
    
    init(buildClosure: BuilderClosure) {
        buildClosure(self)
    }
    
}

internal var MacConfigInstance: MacConfig? = nil
public struct MacConfig {
    
    let macProcessApiResponse: MacProcessApiResponse
    let macErrorNotifier: MacErrorNotifier
    let macTasksRunnerManager: MacTasksRunnerManager
    
    init?(builder: MacConfigBuilder) {
        if let processApiResponse = builder.macProcessApiResponse, let errorNotifier = builder.macErrorNotifier, let tasksRunner = builder.macTasksRunnerManager {
            self.macProcessApiResponse = processApiResponse
            self.macErrorNotifier = errorNotifier
            self.macTasksRunnerManager = tasksRunner
            
            MacConfigInstance = self
        } else {
            return nil
        }
    }
    
}
