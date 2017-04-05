//
//  ErrorVo.swift
//  Pods
//
//  Created by Levi Bostian on 4/4/17.
//
//

import Foundation
import ObjectMapper

class ErrorVo: ErrorResponseVo {
    
    var errors: [String] = []
    
    required convenience init?(map: Map) {
        self.init()
    }
    
    func getErrorMessageToDisplayToUser() -> String {
        return errors[0]
    }
    
    func mapping(map: Map) {
        errors <- map["errors"]
    }
    
}
