import SwiftUI

struct ExpandableMenu: View {
    @State private var isExpanded: Bool = false
    
    var body: some View {
        Button {
//            if !isExpanded {
//                isExpanded = true
//            }
            isExpanded.toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.8))
                    )
                    .frame(width: isExpanded ? 100 : 40, height: isExpanded ? 100 : 60)
                
                if !isExpanded {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.white)
                        .imageScale(.medium)
                        .transition(.scale)
                } else {
                    VStack(spacing: 16) {
                        VStack(spacing: 16) {
                            HStack {
                                Button {
                                    print("like")
                                } label: {
                                    Image(systemName:"heart")
                                        .foregroundColor(.white)
                                }
                                
                                Text("12")
                                    .foregroundColor(.white)
                            }
                            .padding(.vertical, 10)
                            
                            HStack {
                                Button {
                                    print("Comment")
                                } label: {
                                    Image(systemName: "bubble.left")
                                        .foregroundColor(.white)
                                        .padding(.vertical, 5)
                                }
                                Text("15")
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 100)
                        .transition(.opacity)
                    }
                }
            }
        }
    }
}

#Preview {
    ExpandableMenu()
}
