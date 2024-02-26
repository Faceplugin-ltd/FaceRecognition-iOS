import UIKit

class FaceView: UIView {

    var faceBoxes: NSMutableArray? = nil
    var frameSize: CGSize?
    
    public func setFaceBoxes(faceBoxes: NSMutableArray) {
        self.faceBoxes = faceBoxes
        setNeedsDisplay()
    }

    public func setFrameSize(frameSize: CGSize) {
        self.frameSize = frameSize
    }

    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        let defaults = UserDefaults.standard
        let livenessThreshold = defaults.float(forKey: "liveness_threshold")

        if(self.frameSize != nil) {
            context.beginPath()

            let x_scale = self.frameSize!.width / self.bounds.width
            let y_scale = self.frameSize!.height / self.bounds.height

            for faceBox in (faceBoxes! as NSArray as! [FaceBox]) {
                var color = UIColor.green
                var string = "REAL " + String(format: "%.3f", faceBox.liveness)
                if(faceBox.liveness < livenessThreshold) {
                    color = UIColor.red
                    string = "SPOOF " + String(format: "%.3f", faceBox.liveness)
                }
                
                context.setStrokeColor(color.cgColor)
                context.setLineWidth(2.0)
                
                let scaledRect = CGRect(x: Int(CGFloat(faceBox.x1) / x_scale), y: Int(CGFloat(faceBox.y1) / y_scale), width: Int(CGFloat(faceBox.x2 - faceBox.x1 + 1) / x_scale), height: Int(CGFloat(faceBox.y2 - faceBox.y1 + 1) / y_scale))
                context.addRect(scaledRect)

                let attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 20),
                                  NSAttributedString.Key.foregroundColor: color]
                string.draw(at: CGPoint(x: CGFloat(scaledRect.minX + 5), y: CGFloat(scaledRect.minY - 25)), withAttributes: attributes)

                context.strokePath()
            }
        }
    }
}
