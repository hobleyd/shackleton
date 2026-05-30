import Cocoa
import FlutterMacOS
import AVFoundation
import CoreImage

// MARK: - Progress event channel

private class SlideshowProgressHandler: NSObject, FlutterStreamHandler {
    static var sink: FlutterEventSink?

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        SlideshowProgressHandler.sink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        SlideshowProgressHandler.sink = nil
        return nil
    }

    static func emit(current: Int, total: Int) {
        DispatchQueue.main.async {
            sink?(["current": current, "total": total])
        }
    }
}

// MARK: - Channel registration

class SlideshowExporter {
    private static let progressHandler = SlideshowProgressHandler()

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "com.shackleton/slideshow",
            binaryMessenger: messenger)

        let progressChannel = FlutterEventChannel(
            name: "com.shackleton/slideshow_progress",
            binaryMessenger: messenger)
        progressChannel.setStreamHandler(progressHandler)

        channel.setMethodCallHandler { (call, result) in
            guard call.method == "createSlideshow" else {
                result(FlutterMethodNotImplemented)
                return
            }
            guard
                let args          = call.arguments as? [String: Any],
                let imagePaths    = args["imagePaths"]        as? [String],
                let outputPath    = args["outputPath"]        as? String,
                let frameDelaySec = args["frameDelaySeconds"] as? Int
            else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "createSlideshow: missing or wrong-type arguments",
                                    details: nil))
                return
            }
            let audioPath               = args["audioPath"]               as? String
            let transitionDurationSec   = args["transitionDurationSeconds"] as? Double ?? 1.0
            let transitions             = (args["transitions"] as? [String]) ?? []
            let outputWidth             = (args["outputWidth"]  as? Int) ?? 1280
            let outputHeight            = (args["outputHeight"] as? Int) ?? 720

            Task {
                do {
                    try await SlideshowRenderer.run(
                        imagePaths:              imagePaths,
                        audioPath:               audioPath,
                        outputPath:              outputPath,
                        frameDelaySeconds:       frameDelaySec,
                        transitionDurationSec:   transitionDurationSec,
                        transitions:             transitions,
                        outputWidth:             outputWidth,
                        outputHeight:            outputHeight)
                    result(nil)
                } catch {
                    result(FlutterError(code: "EXPORT_FAILED",
                                        message: error.localizedDescription,
                                        details: nil))
                }
            }
        }
    }
}

// MARK: - Frame plan

private enum FrameSpec {
    case still(imageIndex: Int, cg: CGImage)
    case fade(ciA: CIImage, ciB: CIImage, alpha: Double)
    case flip(cgA: CGImage, cgB: CGImage, alpha: Double)
    case spiral(ciA: CIImage, ciB: CIImage, alpha: Double)
}

// MARK: - Renderer

private struct SlideshowRenderer {
    static let fps: Int32 = 30

    // One CIContext shared across every frame — creating it per-frame is very expensive.
    private static let ciCtx = CIContext(options: [.useSoftwareRenderer: false])

    // Pixel buffer pool set for the duration of each export; avoids per-frame CVPixelBufferCreate.
    private static var bufferPool: CVPixelBufferPool?

    // -------------------------------------------------------------------------
    // Image loading — decode at target size using JPEG DCT subsampling
    // -------------------------------------------------------------------------

    static func loadImages(_ paths: [String], maxPixels: Int) async -> [CGImage] {
        await withTaskGroup(of: (Int, CGImage?).self) { group in
            for (i, path) in paths.enumerated() {
                group.addTask { (i, loadThumbnail(path: path, maxPixels: maxPixels)) }
            }
            var pairs = [(Int, CGImage?)]()
            for await pair in group { pairs.append(pair) }
            return pairs.sorted { $0.0 < $1.0 }.compactMap(\.1)
        }
    }

    // Asks ImageIO to decode the JPEG at maxPixels on the longest side.
    // The codec uses DCT subsampling internally (~4–16× fewer pixels decoded).
    // kCGImageSourceCreateThumbnailWithTransform respects EXIF orientation.
    private static func loadThumbnail(path: String, maxPixels: Int) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(
                URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(src, 0, [
            kCGImageSourceThumbnailMaxPixelSize:          maxPixels,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform:   true,
        ] as CFDictionary)
    }

    // -------------------------------------------------------------------------
    // Frame plan — lightweight descriptors built before writing begins
    // -------------------------------------------------------------------------

    // Pre-renders each image to a canvas-sized pixel buffer once (non-pool, so
    // available before startWriting) for use as CIImage endpoints in transitions.
    private static func buildCIStills(_ images: [CGImage], canvas: CGSize) -> [CIImage] {
        images.compactMap { cg in
            renderSingle(cg, canvas: canvas).map { CIImage(cvPixelBuffer: $0) }
        }
    }

    // Returns an ordered list of (frame descriptor, presentation timestamp) pairs.
    // Each descriptor is cheap — just references to CGImages or CIImages.
    private static func buildFramePlan(
        images:               [CGImage],
        ciStills:             [CIImage],
        canvas:               CGSize,
        frameDelaySeconds:    Int,
        transitionDurationSec: Double,
        transitions:          [String]
    ) -> [(spec: FrameSpec, pts: CMTime)] {
        let framesPerImage   = Int(fps) * frameDelaySeconds
        // Clamp so the transition never consumes the entire hold time.
        let clampedTransSec  = transitions.isEmpty ? 0.0
            : max(0.1, min(transitionDurationSec, Double(frameDelaySeconds) - 0.1))
        let transitionFrames = transitions.isEmpty ? 0 : Int(Double(fps) * clampedTransSec)
        let frameDuration    = CMTime(value: 1, timescale: CMTimeScale(fps))
        var plan: [(FrameSpec, CMTime)] = []
        var now  = CMTime.zero

        for (i, cg) in images.enumerated() {
            let hasNext    = i + 1 < images.count
            let mainFrames = hasNext ? framesPerImage - transitionFrames : framesPerImage
            plan.append((.still(imageIndex: i, cg: cg), now))
            now = CMTimeAdd(now, CMTime(value: CMTimeValue(mainFrames), timescale: CMTimeScale(fps)))

            guard hasNext, transitionFrames > 0,
                  i     < ciStills.count,
                  i + 1 < ciStills.count else { continue }

            let pick  = transitions.randomElement()!
            let ciA   = ciStills[i]
            let ciB   = ciStills[i + 1]
            let nextCG = images[i + 1]

            for f in 0..<transitionFrames {
                let alpha = Double(f) / Double(transitionFrames)
                let spec: FrameSpec
                switch pick {
                case "flip":   spec = .flip(cgA: cg, cgB: nextCG, alpha: alpha)
                case "spiral": spec = .spiral(ciA: ciA, ciB: ciB, alpha: alpha)
                default:       spec = .fade(ciA: ciA, ciB: ciB, alpha: alpha)
                }
                plan.append((spec, now))
                now = CMTimeAdd(now, frameDuration)
            }
        }
        return plan
    }

    // Renders one frame from its descriptor; uses pool when available.
    private static func renderSpec(_ spec: FrameSpec, canvas: CGSize) -> CVPixelBuffer? {
        switch spec {
        case .still(_, let cg):
            return renderSingle(cg, canvas: canvas)
        case .fade(let ciA, let ciB, let alpha):
            return renderFade(ciA: ciA, ciB: ciB, alpha: alpha, canvas: canvas)
        case .flip(let cgA, let cgB, let alpha):
            return renderFlip(cgA, cgB, alpha: alpha, canvas: canvas)
        case .spiral(let ciA, let ciB, let alpha):
            return renderSpiral(ciA: ciA, ciB: ciB, alpha: alpha, canvas: canvas)
        }
    }

    // -------------------------------------------------------------------------
    // Public entry point
    // -------------------------------------------------------------------------

    static func run(
        imagePaths:            [String],
        audioPath:             String?,
        outputPath:            String,
        frameDelaySeconds:     Int,
        transitionDurationSec: Double,
        transitions:           [String],
        outputWidth:           Int,
        outputHeight:          Int
    ) async throws {

        // 1. Load images: thumbnail-decode at target size using JPEG DCT subsampling.
        //    All three images load in parallel.
        let cgImages = await loadImages(imagePaths, maxPixels: max(outputWidth, outputHeight))
        guard !cgImages.isEmpty else {
            throw makeError("No valid images could be loaded")
        }

        let canvas = canvasSize(for: cgImages[0], maxW: outputWidth, maxH: outputHeight)
        let outURL = URL(fileURLWithPath: outputPath)
        if FileManager.default.fileExists(atPath: outputPath) {
            try FileManager.default.removeItem(at: outURL)
        }

        // 2. Pre-render each image to a canvas-sized CIImage for transitions.
        //    Done before startWriting so pool isn't needed yet.
        let ciStills = buildCIStills(cgImages, canvas: canvas)

        // 3. Build lightweight frame plan (CGImage/CIImage refs + timestamps).
        let plan = buildFramePlan(
            images:               cgImages,
            ciStills:             ciStills,
            canvas:               canvas,
            frameDelaySeconds:    frameDelaySeconds,
            transitionDurationSec: transitionDurationSec,
            transitions:          transitions)
        let vidDuration = plan.last.map {
            CMTimeAdd($0.pts, CMTime(value: 1, timescale: CMTimeScale(fps)))
        } ?? .zero

        // 4. Set up AVAssetWriter.
        let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)

        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey:  AVVideoCodecType.h264,
                AVVideoWidthKey:  Int(canvas.width),
                AVVideoHeightKey: Int(canvas.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey:             4_000_000,
                    AVVideoProfileLevelKey:               AVVideoProfileLevelH264BaselineAutoLevel,
                    AVVideoExpectedSourceFrameRateKey:    Int(fps),
                ],
            ])
        videoInput.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey           as String: Int(canvas.width),
                kCVPixelBufferHeightKey          as String: Int(canvas.height),
            ])
        writer.add(videoInput)

        // 5. Set up audio (if provided).
        //    Pre-read all sample buffers into an array now, before writing begins.
        //    Calling copyNextSampleBuffer() inside requestMediaDataWhenReady can
        //    block on I/O; if it blocks long enough for isReadyForMoreMediaData to
        //    flip to NO, the subsequent append crashes. Pre-reading avoids that race.
        var audioWriterInput:    AVAssetWriterInput?
        var pendingAudioSamples: [CMSampleBuffer] = []

        if let ap = audioPath, FileManager.default.fileExists(atPath: ap) {
            let asset = AVURLAsset(url: URL(fileURLWithPath: ap))
            if let track = asset.tracks(withMediaType: .audio).first {
                // Encode to AAC — MP3 passthrough is not supported in the MP4 container.
                let aIn = AVAssetWriterInput(
                    mediaType: .audio,
                    outputSettings: [
                        AVFormatIDKey:         kAudioFormatMPEG4AAC,
                        AVSampleRateKey:       44100,
                        AVNumberOfChannelsKey: 2,
                        AVEncoderBitRateKey:   128_000,
                    ],
                    sourceFormatHint: nil)
                aIn.expectsMediaDataInRealTime = false
                writer.add(aIn)
                audioWriterInput = aIn

                // Decode compressed audio (MP3/WAV/etc.) to linear PCM for the AAC encoder.
                let reader = try AVAssetReader(asset: asset)
                let aOut   = AVAssetReaderTrackOutput(track: track, outputSettings: [
                    AVFormatIDKey:               kAudioFormatLinearPCM,
                    AVLinearPCMBitDepthKey:      16,
                    AVLinearPCMIsFloatKey:       false,
                    AVLinearPCMIsBigEndianKey:   false,
                    AVLinearPCMIsNonInterleaved: false,
                ])
                reader.add(aOut)
                reader.startReading()
                while let sample = aOut.copyNextSampleBuffer() {
                    let pts = CMSampleBufferGetOutputPresentationTimeStamp(sample)
                    if CMTimeCompare(pts, vidDuration) >= 0 { break }
                    pendingAudioSamples.append(sample)
                }
                // reader and aOut release here; samples are retained by the array.
            }
        }

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        bufferPool = adaptor.pixelBufferPool

        // 6. Write video and audio concurrently via requestMediaDataWhenReady.
        //    AVFoundation requires ALL inputs to be fed concurrently; sequential
        //    write deadlocks because the encoder withholds the video-ready signal
        //    while waiting for the audio input.
        let writeGroup = DispatchGroup()
        var planIdx    = 0
        var audioIdx   = 0

        writeGroup.enter()
        videoInput.requestMediaDataWhenReady(on: .global(qos: .userInitiated)) {
            while videoInput.isReadyForMoreMediaData {
                if planIdx >= plan.count {
                    videoInput.markAsFinished()
                    writeGroup.leave()
                    return
                }
                // Peek without advancing — renderSpec can take time (CI transitions),
                // and isReadyForMoreMediaData may flip to NO before we can append.
                let entry = plan[planIdx]
                guard let buf = renderSpec(entry.spec, canvas: canvas) else {
                    planIdx += 1  // skip unrenderable frame
                    continue
                }
                // Re-check after rendering; if the encoder is full now, return and
                // let requestMediaDataWhenReady re-invoke us for this same frame.
                guard videoInput.isReadyForMoreMediaData else { return }
                planIdx += 1
                adaptor.append(buf, withPresentationTime: entry.pts)
                if case .still(let idx, _) = entry.spec {
                    SlideshowProgressHandler.emit(current: idx + 1, total: cgImages.count)
                }
            }
        }

        if let aIn = audioWriterInput {
            writeGroup.enter()
            aIn.requestMediaDataWhenReady(on: .global(qos: .utility)) {
                // Drain the pre-read array — no blocking between the ready check
                // and the append, so isReadyForMoreMediaData cannot race to NO.
                while aIn.isReadyForMoreMediaData {
                    if audioIdx >= pendingAudioSamples.count {
                        aIn.markAsFinished()
                        writeGroup.leave()
                        return
                    }
                    aIn.append(pendingAudioSamples[audioIdx])
                    audioIdx += 1
                }
            }
        }

        // Suspend the async task (no thread blocked) until both inputs are done.
        await withCheckedContinuation { continuation in
            writeGroup.notify(queue: .global()) { continuation.resume() }
        }

        await writer.finishWriting()
        bufferPool = nil
        if writer.status == .failed {
            throw writer.error ?? makeError("AVAssetWriter finished with unknown error")
        }
    }

    // -------------------------------------------------------------------------
    // Transition: fade (CIDissolveTransition)
    // -------------------------------------------------------------------------

    static func renderFade(
        ciA: CIImage, ciB: CIImage,
        alpha: Double, canvas: CGSize
    ) -> CVPixelBuffer? {
        guard
            let filter = CIFilter(name: "CIDissolveTransition", parameters: [
                kCIInputImageKey:       ciA,
                kCIInputTargetImageKey: ciB,
                kCIInputTimeKey:        alpha as NSNumber,
            ]),
            let blended = filter.outputImage
        else { return nil }

        guard let out = allocateBuffer(canvas) else { return nil }
        ciCtx.render(blended, to: out,
                     bounds: CGRect(origin: .zero, size: canvas),
                     colorSpace: CGColorSpaceCreateDeviceRGB())
        return out
    }

    // -------------------------------------------------------------------------
    // Transition: flip (horizontal card-flip via CGContext scale transform)
    // -------------------------------------------------------------------------

    static func renderFlip(
        _ a: CGImage, _ b: CGImage,
        alpha: Double, canvas: CGSize
    ) -> CVPixelBuffer? {
        let phase1 = alpha < 0.5
        let src    = phase1 ? a : b
        let scale  = phase1 ? CGFloat(1.0 - 2.0 * alpha) : CGFloat(2.0 * alpha - 1.0)

        guard let buf = allocateBuffer(canvas) else { return nil }
        CVPixelBufferLockBaseAddress(buf, [])
        defer { CVPixelBufferUnlockBaseAddress(buf, []) }

        guard let ctx = CGContext(
            data:             CVPixelBufferGetBaseAddress(buf),
            width:            Int(canvas.width),
            height:           Int(canvas.height),
            bitsPerComponent: 8,
            bytesPerRow:      CVPixelBufferGetBytesPerRow(buf),
            space:            CGColorSpaceCreateDeviceRGB(),
            bitmapInfo:       CGImageAlphaInfo.premultipliedFirst.rawValue
                              | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: canvas))

        if scale > 0.01 {
            ctx.translateBy(x: canvas.width / 2, y: 0)
            ctx.scaleBy(x: scale, y: 1.0)
            ctx.translateBy(x: -canvas.width / 2, y: 0)
            ctx.draw(src, in: letterbox(CGSize(width: src.width, height: src.height),
                                        in: canvas))
        }
        return buf
    }

    // -------------------------------------------------------------------------
    // Transition: spiral (clock-sweep wipe via CGContext arc mask)
    // -------------------------------------------------------------------------

    static func renderSpiral(
        ciA: CIImage, ciB: CIImage,
        alpha: Double, canvas: CGSize
    ) -> CVPixelBuffer? {
        guard let maskCG = makeSpiralMask(alpha: alpha, size: canvas) else { return nil }
        let ciMask = CIImage(cgImage: maskCG)

        guard
            let blend = CIFilter(name: "CIBlendWithMask", parameters: [
                kCIInputImageKey:           ciB,
                kCIInputBackgroundImageKey: ciA,
                kCIInputMaskImageKey:       ciMask,
            ])?.outputImage
        else { return nil }

        guard let out = allocateBuffer(canvas) else { return nil }
        ciCtx.render(blend, to: out,
                     bounds: CGRect(origin: .zero, size: canvas),
                     colorSpace: CGColorSpaceCreateDeviceRGB())
        return out
    }

    static func makeSpiralMask(alpha: Double, size: CGSize) -> CGImage? {
        guard let ctx = CGContext(
            data:             nil,
            width:            Int(size.width),
            height:           Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow:      Int(size.width),
            space:            CGColorSpaceCreateDeviceGray(),
            bitmapInfo:       CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(origin: .zero, size: size))
        guard alpha > 0.001 else { return ctx.makeImage() }

        let cx = size.width / 2
        let cy = size.height / 2
        let r  = (size.width * size.width + size.height * size.height).squareRoot()
        let startAngle = CGFloat.pi / 2
        let endAngle   = startAngle - CGFloat(min(alpha, 1.0)) * 2 * .pi

        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.move(to: CGPoint(x: cx, y: cy))
        ctx.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                   startAngle: startAngle, endAngle: endAngle, clockwise: true)
        ctx.closePath()
        ctx.fillPath()
        return ctx.makeImage()
    }

    // -------------------------------------------------------------------------
    // Shared: single letterboxed frame
    // -------------------------------------------------------------------------

    static func renderSingle(_ cg: CGImage, canvas: CGSize) -> CVPixelBuffer? {
        guard let buf = allocateBuffer(canvas) else { return nil }
        CVPixelBufferLockBaseAddress(buf, [])
        defer { CVPixelBufferUnlockBaseAddress(buf, []) }

        guard let ctx = CGContext(
            data:             CVPixelBufferGetBaseAddress(buf),
            width:            Int(canvas.width),
            height:           Int(canvas.height),
            bitsPerComponent: 8,
            bytesPerRow:      CVPixelBufferGetBytesPerRow(buf),
            space:            CGColorSpaceCreateDeviceRGB(),
            bitmapInfo:       CGImageAlphaInfo.premultipliedFirst.rawValue
                              | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: canvas))
        ctx.draw(cg, in: letterbox(CGSize(width: cg.width, height: cg.height), in: canvas))
        return buf
    }

    // -------------------------------------------------------------------------
    // Geometry helpers
    // -------------------------------------------------------------------------

    static func canvasSize(for img: CGImage, maxW: Int, maxH: Int) -> CGSize {
        let aspect       = Double(img.width) / Double(img.height)
        let targetAspect = Double(maxW) / Double(maxH)
        return aspect >= targetAspect
            ? CGSize(width: maxW, height: max(2, Int(Double(maxW) / aspect)))
            : CGSize(width: max(2, Int(Double(maxH) * aspect)), height: maxH)
    }

    static func letterbox(_ imgSize: CGSize, in canvas: CGSize) -> CGRect {
        let scale = min(canvas.width / imgSize.width, canvas.height / imgSize.height)
        let w = imgSize.width * scale, h = imgSize.height * scale
        return CGRect(x: (canvas.width - w) / 2, y: (canvas.height - h) / 2, width: w, height: h)
    }

    static func allocateBuffer(_ size: CGSize) -> CVPixelBuffer? {
        var buf: CVPixelBuffer?
        if let pool = bufferPool {
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buf)
        } else {
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                Int(size.width), Int(size.height),
                kCVPixelFormatType_32BGRA,
                [kCVPixelBufferCGImageCompatibilityKey:         true,
                 kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary,
                &buf)
        }
        return buf
    }

    static func makeError(_ msg: String) -> NSError {
        NSError(domain: "SlideshowExporter", code: -1,
                userInfo: [NSLocalizedDescriptionKey: msg])
    }
}
