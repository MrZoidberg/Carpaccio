//
//  ImageMetadataLoaderProtocol.swift
//  Carpaccio
//
//  Created by Mikhail Merkulov on 11/4/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation
import CoreGraphics
import CoreImage
import ImageIO


enum ImageMetadataLoadError: Error {
    case cannotFindImageProperties(msg: String)
    case imageUrlIsInvalid(msg: String)
}

public protocol ImageMetadataLoader {
	func loadImageMetadata(imageSource: CGImageSource) throws -> ImageMetadata
	
}

public class RAWImageMetadataLoader: ImageMetadataLoader {
    
    init() {
        
    }
	
	public func loadImageMetadata(imageSource: CGImageSource) throws -> ImageMetadata {
		return try getImageMetadata(imageSource)
	}
    
    public func loadImageMetadata(imageUrl: URL) throws -> ImageMetadata {
        let options = [String(kCGImageSourceShouldCache): false, String(kCGImageSourceShouldAllowFloat): true] as NSDictionary as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(imageUrl as CFURL, options) else {
            throw ImageMetadataLoadError.imageUrlIsInvalid(msg: "Url \(imageUrl.absoluteString) is invalid or doesn't contain an CGImage")
        }
        
        return try getImageMetadata(imageSource)
    }
    
    // See ImageMetadata.timestamp for known caveats about EXIF/TIFF
    // date metadata, as interpreted by this date formatter.
    private static let EXIFDateFormatter: DateFormatter =
        {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            return formatter
    }()
	
	private func getImageMetadata(_ imageSource: CGImageSource) throws -> ImageMetadata {
		func getString(_ from: NSDictionary, _ key: CFString) -> String? {
			return from[key as String] as? String
		}
		
		func getDouble(_ from: NSDictionary, _ key: CFString) -> Double? {
			return (from[key as String] as? NSNumber)?.doubleValue
		}
		
		func getInt(_ from: NSDictionary, _ key: CFString) -> Int? {
			return (from[key as String] as? NSNumber)?.intValue
		}
		
		func getBool(_ from: NSDictionary, _ key: CFString) -> Bool? {
			guard let val = (from[key as String] as? NSNumber)?.doubleValue else {
				return nil
			}
			
			return val == 1 ? true : false
		}
		
		func getEnum<T, KEYT>(_ from: NSDictionary, _ key: CFString, _ matches: [KEYT: T]) -> T? {
			guard let val = from[key as String] as? KEYT else {
				return nil
			}
			
			let enumValue: T? = matches[val];
			
			guard (enumValue != nil) else {
				return nil
			}
			
			return enumValue
		}
		
		func getArray<T>(_ from: NSDictionary, _ key: CFString) -> [T]? {
			guard let ar = from[key as String] as? [T] else {
				return nil
			}
			
			return ar
		}
		
		guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) else {
			throw ImageMetadataLoadError.cannotFindImageProperties(msg: "Cannot find image properties")
		}
		
		let properties = NSDictionary(dictionary: imageProperties)
		
		
		// Examine EXIF metadata
		var exifMetadata: ExifMetadata? = nil
		if let EXIF = properties[kCGImagePropertyExifDictionary as String] as? NSDictionary
		{
			var fNumber: Double? = nil, focalLength: Double? = nil, focalLength35mm: Double? = nil, ISO: Double? = nil, shutterSpeed: Double? = nil
			var colorSpace: CGColorSpace? = nil
			var width: CGFloat? = nil, height: CGFloat? = nil
			var imageId: String? = nil
			var bodySerialNumber: String? = nil, lensSpecs: String? = nil, lensMake: String? = nil, lensModel: String? = nil,lensSerialNumber: String? = nil
			var originalTimestamp: Date? = nil, digitizedTimestamp: Date? = nil
			var subjectDistance: Double? = nil
			var subjectArea: [Double]? = nil
			var flashMode: FlashMode? = nil
			
			imageId = getString(EXIF, kCGImagePropertyExifImageUniqueID)
			
			fNumber = getDouble(EXIF, kCGImagePropertyExifFNumber)
			
			if let colorSpaceName = getString(EXIF, kCGImagePropertyExifColorSpace) {
				colorSpace = CGColorSpace(name: colorSpaceName as CFString)
			}
			
			focalLength = getDouble(EXIF, kCGImagePropertyExifFocalLength)
			focalLength35mm = getDouble(EXIF, kCGImagePropertyExifFocalLenIn35mmFilm)
			
			if let ISOs = EXIF[kCGImagePropertyExifISOSpeedRatings as String]
			{
				let ISOArray = NSArray(array: ISOs as! CFArray)
				if ISOArray.count > 0 {
					ISO = (ISOArray[0] as? NSNumber)?.doubleValue
				}
			}
			
			shutterSpeed = getDouble(EXIF, kCGImagePropertyExifExposureTime)
			
			if let w = getDouble(EXIF, kCGImagePropertyExifPixelXDimension) {
				width = CGFloat(w)
			}
			if let h = getDouble(EXIF, kCGImagePropertyExifPixelYDimension) {
				height = CGFloat(h)
			}
			
			
			bodySerialNumber = getString(EXIF, kCGImagePropertyExifBodySerialNumber)
			lensSpecs = getString(EXIF, kCGImagePropertyExifLensSpecification)
			lensMake = getString(EXIF, kCGImagePropertyExifLensMake)
			lensModel = getString(EXIF, kCGImagePropertyExifLensModel)
			lensSerialNumber = getString(EXIF, kCGImagePropertyExifLensSerialNumber)
			
			if originalTimestamp == nil, let dateTimeString = getString(EXIF, kCGImagePropertyExifDateTimeOriginal) {
				originalTimestamp = RAWImageMetadataLoader.EXIFDateFormatter.date(from: dateTimeString)
			}
			
			if digitizedTimestamp == nil, let dateTimeString = getString(EXIF, kCGImagePropertyExifDateTimeDigitized) {
				digitizedTimestamp = RAWImageMetadataLoader.EXIFDateFormatter.date(from: dateTimeString)
			}
			
			subjectDistance = getDouble(EXIF, kCGImagePropertyExifSubjectDistance)
			subjectArea = getArray(EXIF, kCGImagePropertyExifSubjectArea)
			let flashModeInt = getInt(EXIF, kCGImagePropertyExifFlash)
			if (flashModeInt != nil) {
				flashMode = FlashMode(rawValue: flashModeInt!)
			}
			
			/*
			If image dimension didn't appear in metadata (can happen with some RAW files like Nikon NEFs), take one more step:
			open the actual image. This thankfully doesn't appear to immediately load image data.
			*/
			if width == nil || height == nil
			{
				let options: CFDictionary = [String(kCGImageSourceShouldCache): false] as NSDictionary as CFDictionary
				let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options)
				width = CGFloat((image?.width)!)
				height = CGFloat((image?.height)!)
			}
			
			exifMetadata = ExifMetadata(imageId: imageId, bodySerialNumber: bodySerialNumber, lensSpecification: lensSpecs, lensMake: lensMake, lensModel: lensModel, lensSerialNumber: lensSerialNumber, colorSpace: colorSpace, fNumber: fNumber, focalLength: focalLength, focalLength35mmEquivalent: focalLength35mm, iso: ISO, shutterSpeed: shutterSpeed, nativeSize: CGSize(width: width!, height: height!), originalTimestamp: originalTimestamp, digitizedTimestamp: digitizedTimestamp, subjectDistance: subjectDistance, subjectArea: subjectArea, flashMode: flashMode)
		}
		
		// Examine TIFF metadata
		var tiffMetadata: TIFFMetadata? = nil
		if let TIFF = properties[kCGImagePropertyTIFFDictionary as String] as? NSDictionary
		{
			var cameraMaker: String? = nil, cameraModel: String? = nil, orientation: CGImagePropertyOrientation? = nil, timestamp: Date? = nil
			
			cameraMaker = getString(TIFF, kCGImagePropertyTIFFMake)
			cameraModel = getString(TIFF, kCGImagePropertyTIFFModel)
			
			orientation = CGImagePropertyOrientation(rawValue: (TIFF[kCGImagePropertyTIFFOrientation as String] as? NSNumber)?.uint32Value ?? CGImagePropertyOrientation.up.rawValue)
			
			if timestamp == nil, let dateTimeString = getString(TIFF, kCGImagePropertyTIFFDateTime) {
				timestamp = RAWImageMetadataLoader.EXIFDateFormatter.date(from: dateTimeString)
			}
			
			tiffMetadata = TIFFMetadata(cameraMaker: cameraMaker, cameraModel: cameraModel, nativeOrientation: (orientation)!, timestamp: timestamp)
		}
		
		// Examine GPS metadata
		var gpsMetadata: GpsMetadata? = nil
		if let GPS = properties[kCGImagePropertyGPSDictionary as String] as? NSDictionary
		{
			let gpsVersion: String? = getString(GPS, kCGImagePropertyGPSVersion)
			let latitudeRef: LatitudeRef? = getEnum(GPS,  kCGImagePropertyGPSLatitudeRef, ["N": LatitudeRef.north, "S": LatitudeRef.south])
			let latitude: Double? = getDouble(GPS, kCGImagePropertyGPSLatitude)
			let longtitudeRef: LongtitudeRef? = getEnum(GPS,  kCGImagePropertyGPSLongitudeRef, ["E": LongtitudeRef.east, "W": LongtitudeRef.west])
			let longtitude: Double? = getDouble(GPS, kCGImagePropertyGPSLongitude)
			let altitudeRef: AltitudeRef? = getEnum(GPS,  kCGImagePropertyGPSAltitudeRef, [0: AltitudeRef.aboveSeaLevel, 1: AltitudeRef.belowSeaLevel])
			let altitude: Double? = getDouble(GPS,  kCGImagePropertyGPSAltitude)
			var gpsTimestamp: Date? = nil
			if gpsTimestamp == nil, let dateTimeString = getString(GPS, kCGImagePropertyGPSTimeStamp) {
				gpsTimestamp = RAWImageMetadataLoader.EXIFDateFormatter.date(from: dateTimeString)
			}
			let imgDirection: String? = getString(GPS,  kCGImagePropertyGPSImgDirection)
			
			gpsMetadata = GpsMetadata(gpsVersion: gpsVersion, latitudeRef: latitudeRef, latitude: latitude, longtitudeRef: longtitudeRef, longtitude: longtitude, altitudeRef: altitudeRef, altitude: altitude, timestamp: gpsTimestamp, imgDirection: imgDirection)
		}
		
        let metadata = ImageMetadata(exif: exifMetadata!, tiff: tiffMetadata, gps: gpsMetadata)
		return metadata
	}
}
