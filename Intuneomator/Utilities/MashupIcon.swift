//
//  MashupIcon.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/28/25.
//

import SwiftUI

struct MashupIcon: View {
    var body: some View {
        ZStack {
            // Background: Rounded rectangle with a blue gradient (Intune style)
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(red: 0.0, green: 0.45, blue: 0.8), Color(red: 0.0, green: 0.3, blue: 0.6)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
            
            // Foreground: A gear shape (Installomator nod)
            GearShape()
                .fill(Color.white)
                .frame(width: 60, height: 60)
                .shadow(radius: 5)
        }
    }
}

// Custom gear shape drawing a simple gear with multiple teeth
struct GearShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let numTeeth = 8
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.7
        let toothAngle = .pi / Double(numTeeth) // half tooth angle
        
        for i in 0..<numTeeth {
            let angle = Double(i) * (2 * .pi / Double(numTeeth))
            
            // Points for each tooth
            let p1 = CGPoint(
                x: center.x + CGFloat(cos(angle - toothAngle)) * innerRadius,
                y: center.y + CGFloat(sin(angle - toothAngle)) * innerRadius
            )
            let p2 = CGPoint(
                x: center.x + CGFloat(cos(angle)) * outerRadius,
                y: center.y + CGFloat(sin(angle)) * outerRadius
            )
            let p3 = CGPoint(
                x: center.x + CGFloat(cos(angle + toothAngle)) * innerRadius,
                y: center.y + CGFloat(sin(angle + toothAngle)) * innerRadius
            )
            
            if i == 0 {
                path.move(to: p1)
            }
            path.addLine(to: p1)
            path.addLine(to: p2)
            path.addLine(to: p3)
        }
        path.closeSubpath()
        return path
    }
}

struct MashupIcon_Previews: PreviewProvider {
    static var previews: some View {
        MashupIcon()
    }
}
