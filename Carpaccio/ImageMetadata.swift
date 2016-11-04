//
//  ImageMetadata.swift
//  Carpaccio
//
//  Created by Markus Piipari on 25/07/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//


import Foundation
import QuartzCore
import ImageIO

public enum FlashMode: Int
{
	case FlashDidNotFire = 0x0000
	case FlashFired = 0x0001
	case StrobeReturnLightNotDetected = 0x0005
	case StrobeReturnLightDetected = 0x0007
	case FlashFiredCompulsoryFlashMode = 0x0009
	case FlashFiredCompulsoryFlashModeReturnLightNotDetected = 0x000D
	case FlashFiredCompulsoryFlashModeReturnLightDetected = 0x000F
	case FlashDidNotFireCompulsoryFlashMode = 0x0010
	case FlashDidNotFireAutoMode = 0x0018
	case FlashFiredAutoMode = 0x0019
	case FlashFiredAutoModeReturnLightNotDetected = 0x001D
	case FlashFiredAutoModeReturnLightDetected = 0x001F
	case NoFlashFunction = 0x0020
	case FlashFiredRedEyeReductionMode = 0x0041
	case FlashFiredRedEyeReductionModeReturnLightNotDetected = 0x0045
	case FlashFiredRedEyeReductionModeReturnLightDetected = 0x0047
	case FlashFiredCompulsoryFlashModeRedEyeReductionMode = 0x0049
	case FlashFiredCompulsoryFlashModeRedEyeReductionModeReturnLightNotDetected = 0x004D
	case FlashFiredCompulsoryFlashModeRedEyeReductionModeReturnLightDetected = 0x004F
	case FlashFiredAutoModeRedEyeReductionMode = 0x0059
	case FlashFiredAutoModeRedEyeReductionModeReturnLightNotDetected = 0x005D
	case FlashFiredAutoModeRedEyeReductionModeReturnLightDetected = 0x005F
}

public struct ExifMetadata
{
    public let imageId: String?
    public let bodySerialNumber: String?
    public let lensSpecification: String?
    public let lensMake: String?
    public let lensModel: String?
    public let lensSerialNumber: String?
    public let colorSpace: CGColorSpace?
    /** In common tog parlance, this'd be "aperture": f/2.8 etc.*/
    public let fNumber: Double?
    public let focalLength: Double?
    public let focalLength35mmEquivalent: Double?
    public let iso: Double?
    public let shutterSpeed: TimeInterval?
    public let nativeSize: CGSize
    
    public let originalTimestamp: Date?
    public let digitizedTimestamp: Date?
	
	public let subjectDistance: Double?
	public let subjectArea: [Double]?
	public let flashMode: FlashMode?

    public var humanReadableFNumber: String? {
        get
        {
            guard let f = self.fNumber, f > 0.0 else {
                return nil
            }
            
            // Default to showing one decimal place...
            let oneTenthPrecisionfNumber = round(f * 10.0) / 10.0
            let integerApterture = Int(oneTenthPrecisionfNumber)
            
            // ..but avoid displaying .0
            if oneTenthPrecisionfNumber == Double(integerApterture) {
                return "f/\(integerApterture)"
            }
            
            return "f/\(oneTenthPrecisionfNumber)"
        }
    }
    
    public var humanReadableFocalLength: String? {
        get
        {
            guard let f = self.focalLength, f > 0.0 else {
                return nil
            }
            
            let mm = Int(round(f))
            return "\(mm)mm"
        }
    }
    
    public var humanReadableFocalLength35mmEquivalent: String? {
        get
        {
            guard let f = self.focalLength35mmEquivalent, f > 0.0 else {
                return nil
            }
            
            let mm = Int(round(f))
            return "(\(mm)mm)"
        }
    }
    
    public var humanReadableISO: String? {
        get
        {
            guard let iso = self.iso, iso > 0.0 else {
                return nil
            }
            
            let integerISO = Int(round(iso))
            return "ISO \(integerISO)"
        }
    }
    
    public var humanReadableShutterSpeed: String? {
        get
        {
            guard let s = self.shutterSpeed, s > 0.0 else {
                return nil
            }
            
            if s < 1.0
            {
                let dividend = Int(round(1.0 / s))
                return "1/\(dividend)"
            }
            
            let oneTenthPrecisionSeconds = round(s * 10.0) / 10.0
            return "\(oneTenthPrecisionSeconds)s"
        }
    }
    
    public var humanReadableNativeSize: String {
        return "\(Int(self.nativeSize.width))x\(Int(self.nativeSize.height))"
    }
}

public struct TIFFMetadata
{
    public let cameraMaker: String?
    public let cameraModel: String?
    public let nativeOrientation: CGImagePropertyOrientation
    public let timestamp: Date?

    public var cleanedUpCameraModel: String? {
        get {
            guard let model = self.cameraModel else {
                return nil
            }
            
            let cleanModel = model.replacingOccurrences(of: "NIKON", with: "Nikon")
            return cleanModel
        }
    }
    
    
    
    public var humanReadableTimestamp: String {
        if let t = timestamp {
            return ImageMetadata.timestampFormatter.string(from: t)
        }
        return ""
    }
}

public enum LatitudeRef
{
    case north
    case south
}

public enum LongtitudeRef
{
    case east
    case west
}

public enum AltitudeRef
{
    case aboveSeaLevel
    case belowSeaLevel
}

public struct GpsMetadata
{
    public let gpsVersion: String?
    public let latitudeRef: LatitudeRef?
    public let latitude: Double?
    public let longtitudeRef: LongtitudeRef?
    public let longtitude: Double?
    public let altitudeRef: AltitudeRef?
    public let altitude: Double?
    public let timestamp: Date?
    public let imgDirection: String?
}

public struct ImageMetadata
{
    
    /**
     
     Date & time best suitable to be interpreted as the image's original creation timestamp.
 
     Some notes:
     
     - The value is usually extracted from EXIF or TIFF metadata (in that order), which both appear
       to save it as a string with one second resolution, without time zone information.
     
     - This means the value alone is suitable only for coarse sorting, and typically needs combining
       with the image filename saved by the camera, which usually contains a numerical sequence. For
       example, you will encounter images shot in burst mode that will have the same timestamp.
     
     - As of this writing (2016-08-25), it is unclear if this limitation is fundamentally about
       cameras, the EXIF/TIFF metadata specs or (most unlikely) the Core Graphics implementation.
       However, neither Lightroom, Capture One, FastRawViewer nor RawRightAway display any more
       detail or timezone-awareness, so it seems like this needs to be accepted as just the way it
       is.
     
    */
    
    public let exif: ExifMetadata
    public let tiff: TIFFMetadata?
    
    public init(exif: ExifMetadata, tiff: TIFFMetadata?)
    {
        self.exif = exif;
        self.tiff = tiff
    }
    
    public var size: CGSize
    {
        var shouldSwapWidthAndHeight: Bool = false
		
		if let orientation = self.tiff?.nativeOrientation {
			switch orientation
			{
			case .left, .right, .leftMirrored, .rightMirrored:
				shouldSwapWidthAndHeight = true
			default:
				shouldSwapWidthAndHeight = false
			}
		}
		
        if shouldSwapWidthAndHeight {
            return CGSize(width: self.exif.nativeSize.height, height: self.exif.nativeSize.width)
        }
        
        return self.exif.nativeSize
    }

    static var timestampFormatter: DateFormatter =
        {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .medium
            return f
    }()
    
    /*
    public var humanReadableMetadataSummary: String {
        get {
            return "\(padTail(ofString:self.cleanedUpCameraModel))\(padTail(ofString: self.humanReadableFocalLength))\(padTail(ofString: conditional(string: self.humanReadableFocalLength35mmEquivalent, condition: (self.focalLength35mmEquivalent != self.focalLength))))\(padTail(ofString: self.humanReadableFNumber))\(padTail(ofString: self.humanReadableShutterSpeed))\(padTail(ofString: self.humanReadableISO))"
        }
    }
    */
}

func conditional(string s: String?, condition: Bool) -> String
{
    if let t = s
    {
        if condition {
            return t
        }
    }
    return ""
}

func padTail(ofString s: String?, with: String = " ") -> String
{
    if let t = s
    {
        if !t.isEmpty {
            return "\(t)\(with)"
        }
    }
    return ""
}
