//
//  ImageLoader.swift
//  TcgScanner
//

import UIKit

actor ImageLoader {

    static let shared = ImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private var inFlightTasks: [URL: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 300
        cache.totalCostLimit = 80 * 1024 * 1024
    }

    func image(for url: URL) async -> UIImage? {
        if let cachedImage = cache.object(forKey: url as NSURL) {
            return cachedImage
        }

        if let task = inFlightTasks[url] {
            return await task.value
        }

        let task = Task<UIImage?, Never> {
            guard
                let (data, _) = try? await URLSession.shared.data(from: url),
                !Task.isCancelled,
                let image = UIImage(data: data)
            else {
                return nil
            }

            return image
        }

        inFlightTasks[url] = task
        let image = await task.value
        inFlightTasks[url] = nil

        if let image {
            cache.setObject(
                image,
                forKey: url as NSURL,
                cost: imageCost(image)
            )
        }

        return image
    }

    func prefetch(_ urls: [URL]) {
        for url in urls where cache.object(forKey: url as NSURL) == nil && inFlightTasks[url] == nil {
            inFlightTasks[url] = Task<UIImage?, Never> {
                guard
                    let (data, _) = try? await URLSession.shared.data(from: url),
                    !Task.isCancelled,
                    let image = UIImage(data: data)
                else {
                    return nil
                }

                return image
            }
        }
    }

    func clear() {
        cache.removeAllObjects()
        inFlightTasks.values.forEach { $0.cancel() }
        inFlightTasks.removeAll()
    }

    private func imageCost(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else {
            return 0
        }

        return cgImage.bytesPerRow * cgImage.height
    }
}
