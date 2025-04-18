//
//  main.swift
//  qr
//
//  Created by Kota on 4/18/R7.
//
import class Foundation.FileHandle
import CoreImage.CIFilterBuiltins
enum Error: Swift.Error {
	case arguments(String)
	case input
	case image
	case scale
	case output
}
enum Correction: String {
	case H
	case Q
	case M
	case L
}
enum Format: String {
	case heif
	case tiff
	case jpeg
	case exr
	case png
}
do {
	let option = try CommandLine.arguments.dropFirst(1).reduce(([
		"c": Correction.Q,
		"t": Format.png,
		"s": 1.0 as Float64
	] as Dictionary<String, Any>, "")) { a, x in
		switch a.1 {
		case "c":
			if let digest = Correction(rawValue: x.uppercased()) {
				(a.0.merging([a.1: digest]) { $1 }, "")
			} else {
				throw Error.arguments(x)
			}
		case "t":
			if let format = Format(rawValue: x.lowercased()) {
				(a.0.merging([a.1: format]) { $1 }, "")
			} else {
				throw Error.arguments(x)
			}
		case "s":
			if let factor = Float64(x) {
				(a.0.merging([a.1: factor]) { $1 }, "")
			} else {
				throw Error.arguments(x)
			}
		default:
			switch x {
			case "-c":
				(a.0, "c")
			case "-t":
				(a.0, "t")
			case "-s":
				(a.0, "s")
			default:
				throw Error.arguments(x)
			}
		}
	}.0
	guard let input = try FileHandle.standardInput.readToEnd() else { throw Error.input }
	let colorSpace = CGColorSpaceCreateDeviceRGB()
	let context = CIContext(options: [.outputColorSpace: colorSpace])
	let generator = CIFilter.qrCodeGenerator()
	generator.message = input
	generator.correctionLevel = (option["c"] as?Correction).map(\.rawValue).unsafelyUnwrapped
	guard let image = generator.outputImage else { throw Error.image }
	guard let scale = (option["s"] as?Float64).flatMap(CGFloat.init(exactly:)) else { throw Error.scale }
	let factor = image.transformed(by: .init(scaleX: scale, y: scale))
	let output = switch option["t"] as?Format {
	case.some(.heif):
		context.heifRepresentation(of: factor, format: .BGRA8, colorSpace: colorSpace)
	case.some(.tiff):
		context.tiffRepresentation(of: factor, format: .BGRA8, colorSpace: colorSpace)
	case.some(.jpeg):
		context.jpegRepresentation(of: factor, colorSpace: colorSpace)
	case.some(.png):
		context.pngRepresentation(of: factor, format: .BGRA8, colorSpace: colorSpace)
	case.some(.exr):
		try context.openEXRRepresentation(of: factor)
	case.none:
		.none
	} as Optional<Data>
	guard let output else { throw Error.output }
	try FileHandle.standardOutput.write(contentsOf: output)
} catch {
	try?"""
Error \(error)
 
A command-line tool to generate a QR code image.
Reads a message from stdin and outputs the generated image to stdout.
options:
 -c L/M/Q/H                : Correction level (Default: Q)
 -t heif/tiff/jpeg/exr/png : Image format     (Default: PNG)
 -s Number                 : Scaling factor   (Default: 1.0)

""".data(using: .utf8).map(FileHandle.standardError.write(contentsOf:))
}
