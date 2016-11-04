//
//  ImageMetadataLoaderProtocol.swift
//  Carpaccio
//
//  Created by Mikhail Merkulov on 11/4/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation


enum ImageMetadataLoadError: Error {
	
}

public protocol ImageMetadataLoader {
	func loadImageMetadata(imageSource: CGImageSource) throws -> ImageMetadata
	
}

public class RAWImageMetadataLoader: ImageMetadataLoader {
	
	func loadImageMetadata(imageSource: CGImageSource) throws -> ImageMetadata {
		return getImageMetadata(imageSource)
	}
	
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
		
		guard let imageSource = self.imageSource else {
			return nil
		}
		
		guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) else {
			return nil
		}
		
		let properties = NSDictionary(dictionary: imageProperties)
		
		
		// Examine EXIF metadata
		var exifMetadata: ExifMetadata? = nil
		if let EXIF = properties[kCGImagePropertyExifDictionary as String] as? NSDictionary
		{
			var fNumber: Double? = nil, focalLength: Double? = nil, focalLength35mm: Double? = nil, ISO: Double? = nil, shutterSpeed: Double? = nil
			var colorSpace: CGColorSpace? = nil
			var width: CGFloat? = nil, height: CGFloat? = nil
			var timestamp: Date? = nil
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
			
			if let originalDateString = getString(EXIF, kCGImagePropertyExifDateTimeOriginal) {
				timestamp = EXIFDateFormatter.date(from: originalDateString)
			}
			
			bodySerialNumber = getString(EXIF, kCGImagePropertyExifBodySerialNumber)
			lensSpecs = getString(EXIF, kCGImagePropertyExifLensSpecification)
			lensMake = getString(EXIF, kCGImagePropertyExifLensMake)
			lensModel = getString(EXIF, kCGImagePropertyExifLensModel)
			lensSerialNumber = getString(EXIF, kCGImagePropertyExifLensSerialNumber)
			
			if originalTimestamp == nil, let dateTimeString = getString(EXIF, kCGImagePropertyExifDateTimeOriginal) {
				originalTimestamp = EXIFDateFormatter.date(from: dateTimeString)
			}
			
			if digitizedTimestamp == nil, let dateTimeString = getString(EXIF, kCGImagePropertyExifDateTimeDigitized) {
				digitizedTimestamp = EXIFDateFormatter.date(from: dateTimeString)
			}
			
			subjectDistance = getDouble(EXIF, kCGImagePropertyExifSubjectDistance)
			subjectArea = getArray(EXIF, kCGImagePropertyExifSubjectArea)
			var flashModeInt = getInt(EXIF, kCGImagePropertyExifFlash)
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
				timestamp = EXIFDateFormatter.date(from: dateTimeString)
			}
			
			tiffMetadata = TIFFMetadata(cameraMaker: cameraMaker, cameraModel: cameraModel, nativeOrientation: (orientation)!, timestamp: timestamp)
		}
		
		// Examine GPS metadata
		var gpsMetadata: GpsMetadata? = nil
		if let GPS = properties[kCGImagePropertyGPSDictionary as String] as? NSDictionary
		{
			var gpsVersion: String? = getString(GPS, kCGImagePropertyGPSVersion)
			var latitudeRef: LatitudeRef? = getEnum(GPS,  kCGImagePropertyGPSLatitudeRef, ["N": LatitudeRef.north, "S": LatitudeRef.south])
			var latitude: Double? = getDouble(GPS, kCGImagePropertyGPSLatitude)
			var longtitudeRef: LongtitudeRef? = getEnum(GPS,  kCGImagePropertyGPSLongitudeRef, ["E": LongtitudeRef.east, "W": LongtitudeRef.west])
			var longtitude: Double? = getDouble(GPS, kCGImagePropertyGPSLongitude)
			var altitudeRef: AltitudeRef? = getEnum(GPS,  kCGImagePropertyGPSAltitudeRef, [0: AltitudeRef.aboveSeaLevel, 1: AltitudeRef.belowSeaLevel])
			var altitude: Double? = getDouble(GPS,  kCGImagePropertyGPSAltitude)
			var gpsTimestamp: Date? = nil
			if gpsTimestamp == nil, let dateTimeString = getString(GPS, kCGImagePropertyGPSTimeStamp) {
				gpsTimestamp = EXIFDateFormatter.date(from: dateTimeString)
			}
			var imgDirection: String? = getString(GPS,  kCGImagePropertyGPSImgDirection)
			
			gpsMetadata = GpsMetadata(gpsVersion: gpsVersion, latitudeRef: latitudeRef, latitude: latitude, longtitudeRef: longtitudeRef, longtitude: longtitude, altitudeRef: altitudeRef, altitude: altitude, timestamp: gpsTimestamp, imgDirection: imgDirection)
		}
		
		let metadata = ImageMetadata(exif: exifMetadata!, tiff: tiffMetadata)
		return metadata
	}
}
