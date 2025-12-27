//
//  GoogleLogoView.swift
//  ANITA
//
//  Google logo SVG view for sign-in buttons
//

import SwiftUI

struct GoogleLogoView: View {
    var size: CGFloat = 20
    
    var body: some View {
        Canvas { context, size in
            let scale = size.width / 24.0
            
            // Blue section (top right) - #4285F4
            var bluePath = Path()
            bluePath.move(to: CGPoint(x: 22.56 * scale, y: 12.25 * scale))
            bluePath.addLine(to: CGPoint(x: 22.36 * scale, y: 10.0 * scale))
            bluePath.addLine(to: CGPoint(x: 12.0 * scale, y: 10.0 * scale))
            bluePath.addLine(to: CGPoint(x: 12.0 * scale, y: 14.26 * scale))
            bluePath.addLine(to: CGPoint(x: 17.92 * scale, y: 14.26 * scale))
            bluePath.addCurve(to: CGPoint(x: 20.13 * scale, y: 17.57 * scale), 
                             control1: CGPoint(x: 18.66 * scale, y: 15.59 * scale), 
                             control2: CGPoint(x: 19.39 * scale, y: 16.55 * scale))
            bluePath.addCurve(to: CGPoint(x: 22.56 * scale, y: 12.25 * scale), 
                             control1: CGPoint(x: 20.88 * scale, y: 15.8 * scale), 
                             control2: CGPoint(x: 21.72 * scale, y: 14.02 * scale))
            bluePath.closeSubpath()
            context.fill(bluePath, with: .color(Color(red: 66/255.0, green: 133/255.0, blue: 244/255.0)))
            
            // Green section (bottom right) - #34A853
            var greenPath = Path()
            greenPath.move(to: CGPoint(x: 12.0 * scale, y: 23.0 * scale))
            greenPath.addLine(to: CGPoint(x: 19.28 * scale, y: 20.34 * scale))
            greenPath.addLine(to: CGPoint(x: 15.71 * scale, y: 17.57 * scale))
            greenPath.addCurve(to: CGPoint(x: 12.0 * scale, y: 18.63 * scale), 
                             control1: CGPoint(x: 14.5 * scale, y: 18.13 * scale), 
                             control2: CGPoint(x: 13.23 * scale, y: 18.63 * scale))
            greenPath.addCurve(to: CGPoint(x: 5.84 * scale, y: 14.09 * scale), 
                             control1: CGPoint(x: 9.14 * scale, y: 18.63 * scale), 
                             control2: CGPoint(x: 6.71 * scale, y: 16.7 * scale))
            greenPath.addLine(to: CGPoint(x: 2.18 * scale, y: 16.93 * scale))
            greenPath.addCurve(to: CGPoint(x: 12.0 * scale, y: 23.0 * scale), 
                             control1: CGPoint(x: 3.99 * scale, y: 20.53 * scale), 
                             control2: CGPoint(x: 7.7 * scale, y: 23.0 * scale))
            greenPath.closeSubpath()
            context.fill(greenPath, with: .color(Color(red: 52/255.0, green: 168/255.0, blue: 83/255.0)))
            
            // Yellow section (bottom left) - #FBBC05
            var yellowPath = Path()
            yellowPath.move(to: CGPoint(x: 5.84 * scale, y: 14.09 * scale))
            yellowPath.addLine(to: CGPoint(x: 5.49 * scale, y: 12.0 * scale))
            yellowPath.addLine(to: CGPoint(x: 5.49 * scale, y: 9.91 * scale))
            yellowPath.addLine(to: CGPoint(x: 2.18 * scale, y: 7.07 * scale))
            yellowPath.addCurve(to: CGPoint(x: 1.0 * scale, y: 12.0 * scale), 
                             control1: CGPoint(x: 1.43 * scale, y: 8.55 * scale), 
                             control2: CGPoint(x: 1.0 * scale, y: 10.22 * scale))
            yellowPath.addCurve(to: CGPoint(x: 1.18 * scale, y: 16.93 * scale), 
                             control1: CGPoint(x: 1.0 * scale, y: 13.45 * scale), 
                             control2: CGPoint(x: 1.43 * scale, y: 15.45 * scale))
            yellowPath.addLine(to: CGPoint(x: 5.84 * scale, y: 14.09 * scale))
            yellowPath.closeSubpath()
            context.fill(yellowPath, with: .color(Color(red: 251/255.0, green: 188/255.0, blue: 5/255.0)))
            
            // Red section (top left) - #EA4335
            var redPath = Path()
            redPath.move(to: CGPoint(x: 12.0 * scale, y: 5.38 * scale))
            redPath.addLine(to: CGPoint(x: 16.21 * scale, y: 7.02 * scale))
            redPath.addLine(to: CGPoint(x: 19.36 * scale, y: 3.87 * scale))
            redPath.addCurve(to: CGPoint(x: 12.0 * scale, y: 1.0 * scale), 
                             control1: CGPoint(x: 17.45 * scale, y: 2.09 * scale), 
                             control2: CGPoint(x: 14.97 * scale, y: 1.0 * scale))
            redPath.addCurve(to: CGPoint(x: 2.18 * scale, y: 7.07 * scale), 
                             control1: CGPoint(x: 7.7 * scale, y: 1.0 * scale), 
                             control2: CGPoint(x: 3.99 * scale, y: 3.47 * scale))
            redPath.addLine(to: CGPoint(x: 5.84 * scale, y: 9.91 * scale))
            redPath.addCurve(to: CGPoint(x: 12.0 * scale, y: 5.38 * scale), 
                             control1: CGPoint(x: 6.71 * scale, y: 7.31 * scale), 
                             control2: CGPoint(x: 9.14 * scale, y: 5.38 * scale))
            redPath.closeSubpath()
            context.fill(redPath, with: .color(Color(red: 234/255.0, green: 67/255.0, blue: 53/255.0)))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    GoogleLogoView()
        .padding()
        .background(Color.black)
}

