//
//  ErrorResponseVo.swift
//  Pods
//
//  Created by Levi Bostian on 4/4/17.
//
//

import Foundation
import ObjectMapper

public protocol ErrorResponseVo: Mappable {
    
    func getErrorMessageToDisplayToUser() -> String
    
}
