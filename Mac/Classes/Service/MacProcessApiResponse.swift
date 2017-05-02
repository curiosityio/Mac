//
//  MacProcessApiResponse.swift
//  Pods
//
//  Created by Levi Bostian on 4/3/17.
//
//

import Foundation

public protocol MacProcessApiResponse {
    
    func success(response: Any?, headers: [AnyHashable : Any])
    func error(error: Error?, statusCode: Int?, response: Any?, headers: [AnyHashable : Any]?) -> Error?
    
}
