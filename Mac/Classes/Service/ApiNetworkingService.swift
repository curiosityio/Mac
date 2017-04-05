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
import ObjectMapper

public class ApiNetworkingService {
    
    public class func executeApiCall<ERROR_VO: ErrorResponseVo>(call: URLRequestConvertible, errorVo: ERROR_VO) -> Single<Any?> {
        return Single<Any?>.create { observer in
            clearCacheIfDev()
            
            Alamofire.request(call)
                .responseJSON { (response: DataResponse<Any>) in
                    switch response.result {
                    case .success:
                        let responseCode = response.response!.statusCode
                        _ = determineErrorResponse(response: response, responseStatusCode: responseCode, errorVo: errorVo)
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
    
    private class func determineErrorResponse<ERROR_VO: ErrorResponseVo>(response: DataResponse<Any>, responseStatusCode: Int, errorVo: ERROR_VO) -> Single<Any?> {
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
                        let responseData = Mapper<ERROR_VO>().map(JSONObject: response.result.value) // swiftlint:disable:this force_cast
                        observer(SingleEvent.error(APIError.apiSome400error(errorMessage: responseData?.getErrorMessageToDisplayToUser() ?? "Unknown error.")))
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
