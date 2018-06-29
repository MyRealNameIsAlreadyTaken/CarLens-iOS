//
//  CarRecognizerService.swift
//  CarRecognition
//

import CoreML
import Vision
import UIKit.UIImage

internal final class CarClassificationService {
    
    /// Completion handler for recognized cars
    var completionHandler: ((CarClassifierResponse) -> ())?
    
    /// Indicates if recognizer is ready to analyze next frame
    var isReadyForNextFrame: Bool {
        return currentBuffer == nil
    }
    
    /// Value contains last recognized cars
    var lastTopRecognition: CarClassifierResponse?
    
    private var currentBuffer: CVPixelBuffer?
    
    private var currectBufferStartAnalyzeDate = Date()
    
    private lazy var request: VNCoreMLRequest = { [unowned self] in
        guard let model = try? VNCoreMLModel(for: CarRecognitionModel().model) else {
            fatalError("Core ML model initialization failed")
        }
        let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
            self?.handleDetection(request: request, error: error)
        })
        request.imageCropAndScaleOption = .centerCrop
        return request
    }()
    
    /// Perform ML analyze on given buffer. Will do the analyze only when finished last one.
    ///
    /// - Parameter pixelBuffer: Pixel buffer to be analyzed
    func perform(on pixelBuffer: CVPixelBuffer) {
        guard isReadyForNextFrame else { return }
        self.currentBuffer = pixelBuffer
        let orientation = CGImagePropertyOrientation.right
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                defer { self.currentBuffer = nil }
                self.currectBufferStartAnalyzeDate = Date()
                try handler.perform([self.request])
            } catch {
                print("Vision request failed with error \"\(error)\"")
            }
        }
    }
    
    private func handleDetection(request: VNRequest, error: Error?) {
        guard let results = request.results, let currentBuffer = currentBuffer else {
            print("Unable to classify image, error: \(String(describing: error?.localizedDescription))")
            return
        }
        let classifications = results as! [VNClassificationObservation]
        let rocognizedCars = classifications.compactMap { RecognitionResult(label: $0.identifier, confidence: $0.confidence) }
        let analyzeDuration = Date().timeIntervalSince(currectBufferStartAnalyzeDate)
        let analyzedImage = UIImage(pixelBuffer: currentBuffer) ?? UIImage()
        let response = CarClassifierResponse(cars: rocognizedCars, analyzeDuration: analyzeDuration, analyzedImage: analyzedImage)
        lastTopRecognition = response
        completionHandler?(response)
    }
}
