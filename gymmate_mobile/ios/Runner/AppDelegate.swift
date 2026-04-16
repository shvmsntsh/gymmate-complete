import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController
    let galleryChannel = FlutterMethodChannel(
      name: "com.gymmate/gallery_picker",
      binaryMessenger: controller.binaryMessenger
    )

    galleryChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "pickGalleryImage" {
        self?.pickGalleryImage(controller: controller, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func pickGalleryImage(controller: FlutterViewController, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
        result(FlutterError(code: "UNAVAILABLE", message: "Photo library not available", details: nil))
        return
      }

      let picker = UIImagePickerController()
      picker.sourceType = .photoLibrary
      picker.delegate = GalleryPickerDelegate(result: result)
      picker.allowsEditing = false

      controller.present(picker, animated: true, completion: nil)
    }
  }
}

private class GalleryPickerDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  private let result: FlutterResult

  init(result: @escaping FlutterResult) {
    self.result = result
    super.init()
  }

  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
    picker.dismiss(animated: true) {
      guard let image = info[.originalImage] as? UIImage else {
        self.result(FlutterError(code: "NO_IMAGE", message: "No image selected", details: nil))
        return
      }

      guard let imageData = image.jpegData(compressionQuality: 0.9) else {
        self.result(FlutterError(code: "CONVERSION_FAILED", message: "Failed to convert image to JPEG", details: nil))
        return
      }

      let base64String = imageData.base64EncodedString()
      self.result("data:image/jpeg;base64,\(base64String)")
    }
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true) {
      self.result(nil)
    }
  }
}
