//
//  APIError.swift
//  Pods
//
//  Created by Levi Bostian on 4/4/17.
//
//

import Foundation

public enum APIError: Error, LocalizedError {
    case parseErrorFromAPIException
    
    case api500ApiDown
    case api403UserNotEnoughPrivileges
    case api401UserUnauthorized
    case apiSome400error(errorMessage: String)
    
    public var errorDescription: String? {
        switch self {
        case .api500ApiDown:
            return NSLocalizedString("The system is currently down. Come back later and try again.", comment: "")
        case .api403UserNotEnoughPrivileges:
            return NSLocalizedString("You do not have enough privileges to continue.", comment: "This should not happen.")
        case .api401UserUnauthorized:
            return NSLocalizedString("Unauthorized", comment: "")
        case .apiSome400error(let errorMessage):
            return NSLocalizedString(errorMessage, comment: "")
            
        case .parseErrorFromAPIException:
            return NSLocalizedString("Unknown error. Sorry, try again.", comment: "")
        }
    }
}
