//
//  IceBreakManagerView.swift
//  IceTime
//
//  Created by Lemine Mo El Agheb on 27.02.24.
//


import SwiftUI
import CoreImage.CIFilterBuiltins
import AVFoundation

struct IceBreakManagerView: View {
    @State private var selectedHour: Int = Calendar.current.component(.hour, from: Date())
    @State private var selectedMinute: Int = Calendar.current.component(.minute, from: Date())
    @State private var iceBreakTimes: [String] = []
    @State private var qrCodeImage: UIImage? = nil
    @State private var showErrorMessage = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var timer: Timer?
    @State private var isScanning = false
    @State private var scannedIceBreakTimes: [String] = []

    var body: some View {
        VStack {
            HStack {
                Picker("Stunde", selection: $selectedHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text("\(hour)")
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 100)
                .background(Color(.systemBackground))

                Picker("Minute", selection: $selectedMinute) {
                    ForEach(0..<60, id: \.self) { minute in
                        Text("\(minute)")
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 100)
                .background(Color(.systemBackground))
            }
            .padding()

            Button(action: {
                let formattedTime = String(format: "%02d:%02d", selectedHour, selectedMinute)
                iceBreakTimes.append(formattedTime)
                iceBreakTimes.sort()
                showErrorMessage = false
            }) {
                Text("Eispause hinzufügen")
                    .padding()
                    .background(Color(.systemBlue))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            Button(action: {
                print("QR-Code generieren")
                if iceBreakTimes.count >= 3 {
                    generateQRCode(from: iceBreakTimes)
                    showErrorMessage = false
                    scheduleIceBreakSound()
                } else {
                    showErrorMessage = true
                    return
                }
            }) {
                Text("QR-Code generieren")
                    .padding()
                    .background(Color(.systemBlue))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()

            Button(action: {
                isScanning.toggle()
            }) {
                Text(isScanning ? "Scanning beenden" : " QR-Code scannen")
                    .padding()
                    .background(Color(.systemBlue))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()

            if showErrorMessage {
                Text("Es müssen mindestens drei Eispausen eingetragen sein, damit ein QR-Code generiert werden kann.")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color(.systemBackground))
            }

            if let qrCodeImage = qrCodeImage {
                Image(uiImage: qrCodeImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                    .padding()
            }

            List(iceBreakTimes.indices, id: \.self) { index in
                Text("Pause \(index + 1): \(iceBreakTimes[index])")
                    .foregroundColor(Color(.label))
            }

            if isScanning {
                QRCodeScannerView(scannedIceBreakTimes: $scannedIceBreakTimes)
                    .edgesIgnoringSafeArea(.all)
            }

            List(scannedIceBreakTimes.indices, id: \.self) { index in
                Text("Gescannte Pause \(index + 1): \(scannedIceBreakTimes[index])")
                    .foregroundColor(Color(.label))
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private func playSound() {
        guard let url = Bundle.main.url(forResource: "break_sound", withExtension: "mp3") else {
            print("Error: break_sound.mp3 not found")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()

            timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
                self.stop()
            }
        } catch {
            print("Error playing sound: \(error)")
        }
    }

    private func stop() {
        audioPlayer?.stop()
        timer?.invalidate()
    }

    private func scheduleIceBreakSound() {
           timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
               let currentDate = Date()
               let systemTimeZone = TimeZone.current
               let calendar = Calendar.current

               for iceBreakTime in iceBreakTimes {
                   let dateFormatter = DateFormatter()
                   dateFormatter.dateFormat = "HH:mm"
                   dateFormatter.timeZone = systemTimeZone

                   guard let iceBreakDate = dateFormatter.date(from: iceBreakTime) else {
                       continue
                   }

                   let currentDateComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
                   var iceBreakDateComponents = calendar.dateComponents([.hour, .minute], from: iceBreakDate)
                   iceBreakDateComponents.year = currentDateComponents.year
                   iceBreakDateComponents.month = currentDateComponents.month
                   iceBreakDateComponents.day = currentDateComponents.day

                   guard let adjustedIceBreakDate = calendar.date(from: iceBreakDateComponents) else {
                       continue
                   }

                   let timeDifference = adjustedIceBreakDate.timeIntervalSince(currentDate)

                   if 0..<60 ~= timeDifference {
                       playSound()
                       break
                   }
               }
           }
       }

    private func generateQRCode(from times: [String]) {
            do {
                let jsonData = try JSONEncoder().encode(times)
                guard let qrFilter = CIFilter(name: "CIQRCodeGenerator") else {
                    print("Error creating CIQRCodeGenerator filter")
                    return
                }
                qrFilter.setValue(jsonData, forKey: "inputMessage")

                guard let qrCode = qrFilter.outputImage else {
                    print("Error getting output image from QR filter")
                    return
                }

                if let cgImage = CIContext().createCGImage(qrCode, from: qrCode.extent) {
                    qrCodeImage = UIImage(cgImage: cgImage)
                } else {
                    print("Error creating CGImage from QR code")
                }

            } catch {
                print("Error generating QR Code: \(error)")
            }
        }
    }

struct QRCodeScannerView: UIViewControllerRepresentable {
    @Binding var scannedIceBreakTimes: [String]

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: QRCodeScannerView

        init(parent: QRCodeScannerView) {
            self.parent = parent
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                guard let stringValue = readableObject.stringValue else { return }

                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                parent.scannedIceBreakTimes.append(stringValue)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return viewController }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return viewController
        }

        if (session.canAddInput(videoInput)) {
            session.addInput(videoInput)
        } else {
            return viewController
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if (session.canAddOutput(metadataOutput)) {
            session.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return viewController
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = viewController.view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        viewController.view.layer.addSublayer(previewLayer)

        session.startRunning()

        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

extension IceBreakManagerView {
    func didFindIceBreakTimes(_ scannedString: String) {
        if let data = scannedString.data(using: .utf8),
           let scannedTimes = try? JSONDecoder().decode([String].self, from: data) {
            scannedIceBreakTimes.append(contentsOf: scannedTimes)
        }
    }
}

struct IceBreakManagerView_Previews: PreviewProvider {
    static var previews: some View {
        IceBreakManagerView()
    }
}
