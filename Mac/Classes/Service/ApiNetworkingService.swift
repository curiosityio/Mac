//
//  ApiNetworkingService.swift
//  Pods
//
//  Created by Levi Bostian on 4/4/17.
//
//

import Foundation
import RxSwift
import Alamofire
import iOSBoilerplate

public class MimeTypeConstants {
    public static let jpeg = "image/jpeg"
    public static let png = "image/png"
}

public class ApiNetworkingService {
    
    public struct UploadMultipartFormData {
        var data: Data!
        var name: String!
    }
    
    public struct UploadFileMultipartFormData {
        var data: Data!
        var multipartFormName: String!
        var fileName: String!
        var mimeType: String!
    }
    
    public class func executeUploadApiCall(_ call: URLRequestConvertible, data: [UploadMultipartFormData], files: [UploadFileMultipartFormData], parseError: @escaping (Any?) -> String) -> Single<Any?> {
        return Single<Any?>.create { observer in
            clearCacheIfDev()
        
            Alamofire.upload(multipartFormData: { (multiformData) in
                for formData in data {
                    multiformData.append(formData.data, withName: formData.name)
                }
                for file in files {
                    multiformData.append(file.data, withName: file.multipartFormName, fileName: file.fileName, mimeType: file.mimeType.description)
                }
            }, with: call) { (encodingResult) in
                switch encodingResult {
                case .success(let upload, _, _):
                    upload.responseJSON(completionHandler: { (response: DataResponse<Any>) in
                        let responseCode = response.response!.statusCode
                        _ = determineErrorResponse(response: response, responseStatusCode: responseCode, parseError: parseError)
                            .subscribeSingle({ (responseValue) in
                                observer(SingleEvent.success(responseValue))
                            }, onError: { (error) in
                                observer(SingleEvent.error(error))
                            })
                    })
                case .failure(let error):
                    observer(SingleEvent.error(error))
                }
            }
            return Disposables.create()
        }
    }
    
    public class func executeApiCall(call: URLRequestConvertible, parseError: @escaping (Any?) -> String) -> Single<Any?> {
        return Single<Any?>.create { observer in
            clearCacheIfDev()
            
            Alamofire.request(call)
                .responseJSON { (response: DataResponse<Any>) in
                    switch response.result {
                    case .success:
                        let responseCode = response.response!.statusCode
                        _ = determineErrorResponse(response: response, responseStatusCode: responseCode, parseError: parseError)
                            .subscribeSingle({ (responseValue) in
                                observer(SingleEvent.success(responseValue))
                            }, onError: { (error) in
                                observer(SingleEvent.error(error))
                            })
                    case .failure(let error):
                        observer(SingleEvent.error(error))
                    }
            }
            return Disposables.create()
        }
    }
    
    private class func determineErrorResponse(response: DataResponse<Any>, responseStatusCode: Int, parseError: @escaping (Any?) -> String) -> Single<Any?> {
        return Single<Any?>.create { observer in
            if responseStatusCode >= 200 && responseStatusCode < 300 {
                MacConfigInstance?.macProcessApiResponse.success(response: response.value, headers: response.response!.allHeaderFields)
                observer(SingleEvent.success(response.value))
            } else {
                if let userProcessedError = MacConfigInstance?.macProcessApiResponse.error(statusCode: responseStatusCode, response: response.value, headers: response.response!.allHeaderFields) {
                    observer(SingleEvent.error(userProcessedError))
                } else {
                    switch responseStatusCode {
                    case _ where responseStatusCode >= 500:
                        let error = APIError.api500ApiDown
                        observer(SingleEvent.error(error))
                        MacConfigInstance?.macErrorNotifier.errorEncountered(error: error)
                        break
                    case _ where responseStatusCode == 403:
                        let error = APIError.api403UserNotEnoughPrivileges
                        observer(SingleEvent.error(error))
                        MacConfigInstance?.macErrorNotifier.errorEncountered(error: error)
                        break
                    case _ where responseStatusCode == 401:
                        observer(SingleEvent.error(APIError.api401UserUnauthorized))
                        break
                    default:
                        observer(SingleEvent.error(APIError.apiSome400error(errorMessage: parseError(response.value))))
                        break
                    }
                }
            }
            return Disposables.create()
        }
    }
    
    private class func clearCacheIfDev() {
        #if DEBUG
            URLCache.shared.removeAllCachedResponses()
        #endif
    }
    
}