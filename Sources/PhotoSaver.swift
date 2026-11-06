import Foundation
import Photos

/// Salva i file arrivati dalla fotocamera nel Rullino dell'iPhone.
enum PhotoSaver {
    static func save(_ data: Data, filename: String, completion: @escaping (Bool, String) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                completion(false, "permesso Foto negato (Impostazioni → Alpha Monitor → Foto)")
                return
            }
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = filename
                request.addResource(with: .photo, data: data, options: options)
            }) { ok, error in
                completion(ok, error?.localizedDescription ?? "")
            }
        }
    }
}
