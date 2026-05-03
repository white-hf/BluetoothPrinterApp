import SwiftUI

struct AppLogoView: View {
    var size: CGFloat = 200
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0, green: 0.48, blue: 1), Color(red: 0, green: 0.35, blue: 0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            VStack(alignment: .trailing, spacing: size * 0.1) {
                RoundedRectangle(cornerRadius: size * 0.05)
                    .fill(.white)
                    .frame(width: size * 0.5, height: size * 0.06)
                
                RoundedRectangle(cornerRadius: size * 0.05)
                    .fill(.white)
                    .frame(width: size * 0.6, height: size * 0.09)
                
                RoundedRectangle(cornerRadius: size * 0.05)
                    .fill(.white)
                    .frame(width: size * 0.5, height: size * 0.12)
            }
            .offset(x: size * 0.05)
            
            Circle()
                .fill(.white.opacity(0.6))
                .frame(width: size * 0.2, height: size * 0.2)
                .offset(x: -size * 0.3)
        }
        .frame(width: size, height: size)
    }
}

struct AppLogoView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            AppLogoView(size: 100)
            AppLogoView(size: 200)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
