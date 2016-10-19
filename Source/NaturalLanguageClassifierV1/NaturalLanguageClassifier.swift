/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Foundation
import Alamofire
import Freddy
import RestKit

/**
 The IBM Watson Natural Language Classifier service enables developers without a background in
 machine learning or statistical algorithms to create natural language interfaces for their
 applications. The service interprets the intent behind text and returns a corresponding
 classification with associated confidence levels. The return value can then be used to trigger
 a corresponding action, such as redirecting the request or answering a question.
 */
public class NaturalLanguageClassifier {
    
    /// The base URL to use when contacting the service.
    public var serviceURL = "https://gateway.watsonplatform.net/natural-language-classifier/api"
    
    /// The default HTTP headers for all requests to the service.
    public var defaultHeaders = [String: String]()
    
    private let username: String
    private let password: String
    private let domain = "com.ibm.watson.developer-cloud.NaturalLanguageClassifierV1"
    
    /**
     Create a `NaturalLanguageClassifier` object.
     
     - parameter username: The username used to authenticate with the service.
     - parameter password: The password used to authenticate with the service.
     */
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
    
    /**
     If the given data represents an error returned by the Visual Recognition service, then return
     an NSError with information about the error that occured. Otherwise, return nil.
     
     - parameter data: Raw data returned from the service that may represent an error.
     */
    private func dataToError(data: Data) -> NSError? {
        do {
            let json = try JSON(data: data)
            let error = try json.getString(at: "error")
            let code = try json.getInt(at: "code")
            let description = try json.getString(at: "description")
            let userInfo = [
                NSLocalizedFailureReasonErrorKey: error,
                NSLocalizedRecoverySuggestionErrorKey: description
            ]
            return NSError(domain: domain, code: code, userInfo: userInfo)
        } catch {
            return nil
        }
    }
    
    /**
     Retrieves the list of classifiers for the service instance.
     
     - parameter failure: A function executed if an error occurs.
     - parameter success: A function executed with the list of available standard and custom models.
       The array is empty if no classifiers are available.
     */
    public func getClassifiers(
        failure: ((Error) -> Void)? = nil,
        success: @escaping ([ClassifierModel]) -> Void) {
        
        // construct REST request
        let request = RestRequest(
            method: .get,
            url: serviceURL + "/v1/classifiers",
            headerParameters: defaultHeaders,
            acceptType: "application/json"
        )
        
        // execute REST request
        request.authenticate(user: username, password: password)
            .responseArray(path: ["classifiers"]) { (response: DataResponse<[ClassifierModel]>) in
                switch response.result {
                case .success(let classifiers): success(classifiers)
                case .failure(let error): failure?(error)
                }
        }
    }
    
    /**
     Sends data to create and train a classifier. When the operation is successful, the status of 
     the classifier is set to "Training". The status must be "Available" before you can use the 
     classifier.
     
     - parameter trainingMetadata: A file that contains, in JSON form, the user-supplied name for 
       the classifier and the language of the training data.
     - parameter trainingData: The set of questions and their "keys" used to adapt a system to a 
       domain (the ground truth).
     - parameter failure: A function executed if an error occurs.
     - parameter success: A function executed with the list of available standard and custom models.
     */
    public func createClassifier(
        trainingMetadata: URL,
        trainingData: URL,
        failure: ((Error) -> Void)? = nil,
        success: @escaping (ClassifierDetails) -> Void) {
        
        // construct REST request
        let request = RestRequest(
            method: .post,
            url: serviceURL + "/v1/classifiers",
            headerParameters: defaultHeaders,
            acceptType: "application/json"
        )
        
        // execute REST request
        request.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(trainingMetadata, withName: "training_metadata")
                multipartFormData.append(trainingData, withName: "training_data")
            },
            encodingCompletion: { encodingResult in
                switch encodingResult {
                case .success(let upload, _, _):
                    upload.authenticate(user: self.username, password: self.password)
                    upload.responseObject() { (response: DataResponse<ClassifierDetails>) in
                        switch response.result {
                        case .success(let classifierDetails): success(classifierDetails)
                        case .failure(let error): failure?(error)
                        }
                    }
                case .failure:
                    let failureReason = "Files could not be encoded as form data."
                    let userInfo = [NSLocalizedFailureReasonErrorKey: failureReason]
                    let error = NSError(domain: self.domain, code: 0, userInfo: userInfo)
                    failure?(error)
                    return
                }
            }
        )
    }
    
    /**
     Uses the provided classifier to assign labels to the input text. The status of the classifier 
     must be "Available" before you can classify calls.
     
     - parameter classifierId: Classifier ID to use
     - parameter text: Phrase to classify
     - parameter failure: A function executed if an error occurs.
     - parameter success: A function executed with the list of available standard and custom models.
     */
    public func classify(
        classifierId: String,
        text: String,
        failure: ((Error) -> Void)? = nil,
        success: @escaping (Classification) -> Void) {
        
        // construct query parameters
        guard let body = try? ["text": text].toJSON().serialize() else {
            let failureReason = "Classification text could not be serialized to JSON."
            let userInfo = [NSLocalizedFailureReasonErrorKey: failureReason]
            let error = NSError(domain: domain, code: 0, userInfo: userInfo)
            failure?(error)
            return
        }
        
        // construct REST request
        let request = RestRequest(
            method: .post,
            url: serviceURL + "/v1/classifiers/\(classifierId)/classify",
            headerParameters: defaultHeaders,
            acceptType: "application/json",
            contentType: "application/json",
            messageBody: body
        )
        
        // execute REST request
        request.authenticate(user: username, password: password)
            .responseObject() { (response: DataResponse<Classification>) in
                switch response.result {
                case .success(let classification): success(classification)
                case .failure(let error): failure?(error)
                }
            }
    }
    
    /**
     Deletes the classifier with the classifierId.
     
     - parameter classifierId: The classifer ID used to delete the classifier
     - parameter failure: A function executed if an error occurs.
     - parameter success: A function executed with the list of available standard and custom models.
     */
    public func deleteClassifier(
        classifierId: String,
        failure: ((Error) -> Void)? = nil,
        success: ((Void) -> Void)? = nil) {
        
        // construct REST request
        let request = RestRequest(
            method: .delete,
            url: serviceURL + "/v1/classifiers/\(classifierId)",
            headerParameters: defaultHeaders,
            acceptType: "application/json"
        )
        
        // execute REST request
        request.authenticate(user: username, password: password)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    switch self.dataToError(data: data) {
                    case .some(let error): failure?(error)
                    case .none: success?()
                    }
                case .failure(let error):
                    failure?(error)
                }
        }
    }

    /**
     Provides detailed information about the classifier with the user-specified classifierId.
     
     - parameter classifierId: The classifer ID used to retrieve the classifier
     - parameter failure: A function executed if an error occurs.
     - parameter success: A function executed with the list of available standard and custom models.
     */
    public func getClassifier(
        classifierId: String,
        failure: ((Error) -> Void)? = nil,
        success: @escaping (ClassifierDetails) -> Void) {
        
        // construct REST request
        let request = RestRequest(
            method: .get,
            url: serviceURL + "/v1/classifiers/\(classifierId)",
            headerParameters: defaultHeaders,
            acceptType: "application/json"
        )
        
        // execute REST request
        request.authenticate(user: username, password: password)
            .responseObject() { (response: DataResponse<ClassifierDetails>) in
                switch response.result {
                case .success(let classifier): success(classifier)
                case .failure(let error): failure?(error)
                }
        }
    }
}
