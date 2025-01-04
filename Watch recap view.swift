import FirebaseFirestore
import SwiftUI
import AVKit
import FirebaseAuth


@MainActor
struct WatchRecapView: View {
    let recaps: [Recap]
    @StateObject var viewModel = RecapViewModel()
    @State private var currentRecapIndex: Int = 0
    @State private var isPlaying: Bool = false
    @State private var countdown: CGFloat = 60
    @State private var isCountdownActive: Bool = true
    @State private var player: AVPlayer?
    @State private var isExiting: Bool = false
    @StateObject var likeRecapsModel: LikeRecapsModel
    @State private var isProfileViewPresented: Bool = false
    @State private var isProfilePrivate: Bool = false
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode

    let screenWidth: CGFloat
    
    private var user: User? {
        return UserService.shared.currentUser
    }
    
    init(recaps: [Recap], likeRecapsModel: LikeRecapsModel, screenWidth: CGFloat) {
        self.recaps = recaps
        _likeRecapsModel = StateObject(wrappedValue: likeRecapsModel)
        self.screenWidth = screenWidth
    }

    var body: some View {
          GeometryReader { screenGeometry in
              ZStack {
                  Color.black
                      .ignoresSafeArea() // Ensures the background fills the screen
                  
                  if !recaps.isEmpty {
                      let currentRecap = recaps[currentRecapIndex]
                      
                      VStack(spacing: 0) {
                          ForEach(recaps.indices, id: \.self) { index in
                              ZStack {
                                  if recaps[index].mediaType == .video,
                                     let mediaURLString = recaps[index].mediaURL,
                                     let mediaURL = URL(string: mediaURLString) {
                                      VideoPlayer(player: player)
                                          .onAppear {
                                              if index == currentRecapIndex {
                                                  setupPlayer(for: recaps[index])
                                                  player?.play()
                                              }
                                          }
                                          .onDisappear {
                                              player?.pause()
                                          }
                                          .aspectRatio(contentMode: .fill) // Fill screen proportionally
                                          .frame(width: screenGeometry.size.width, height: screenGeometry.size.height)
                                          .clipped() // Prevents overflow beyond the screen size
                                  } else if recaps[index].mediaType == .image,
                                            let mediaURLString = recaps[index].mediaURL,
                                            let mediaURL = URL(string: mediaURLString) {
                                      AsyncImage(url: mediaURL) { image in
                                          image
                                              .resizable()
                                              .scaledToFill() // Ensure it fills proportionally
                                              .frame(width: screenGeometry.size.width, height: screenGeometry.size.height)
                                              .clipped() // Prevent overflow
                                      } placeholder: {
                                          ProgressView()
                                              .frame(maxWidth: .infinity, maxHeight: .infinity)
                                      }
                                  } else {
                                      // Placeholder for missing media
                                      Text("Media not available")
                                          .foregroundColor(.white)
                                          .frame(width: screenGeometry.size.width, height: screenGeometry.size.height)
                                  }
                              }
                              .frame(width: screenGeometry.size.width, height: screenGeometry.size.height)
                          }
                      }
                    
                    // Dynamic Recap Indicators
                      VStack {
                              Spacer() // Pushes the overlay to the bottom
                              
                              VStack(alignment: .leading, spacing: 8) {
                                  // Profile and Username Section
                                  HStack(alignment: .center, spacing: 12) {
                                      if let user = viewModel.users[currentRecap.id] {
                                          // Profile Button
                                          Button(action: {
                                              observeUserProfilePrivacy(uid: user.id) {
                                                  isProfileViewPresented = true
                                              }
                                          }) {
                                              CircularProfileImageView(user: user, size: .small)
                                          }
                                          .sheet(isPresented: $isProfileViewPresented) {
                                              profileDestination(for: user)
                                          }
                                          
                                          // Username
                                          Text(user.username)
                                              .foregroundColor(.white)
                                              .font(.headline)
                                              .lineLimit(1)
                                      }
                                  }
                                  
                                  // Description Section
                                  if let description = currentRecap.description, !description.isEmpty {
                                      Text(description)
                                          .foregroundColor(.white)
                                          .font(.subheadline)
                                          .lineLimit(3)
                                          .padding(.top, 4)
                                  }
                                  
                                  // Views Section
                                  HStack {
                                      Spacer()
                                      HStack {
                                          Image(systemName: "eye")
                                              .foregroundColor(.white)
                                          Text(formattedViewCount(currentRecap.views))
                                              .foregroundColor(.white)
                                              .font(.caption)
                                      }
                                  }
                              }
                              .padding()
                              .frame(width: screenWidth - 32) // Keeps content within safe bounds
                              .background(
                                  ZStack {
                                      // Custom BlurView with extra intensity
                                      EnhancedBlurView(style: .systemMaterialDark, intensity: 0.5)
                                          .cornerRadius(16)
                                          .opacity(0.9) // Adjust for subtle appearance

                                      // Ultra-light semi-transparent black overlay
                                      Color.black.opacity(0.01) // Very low opacity for minimal tint
                                          .cornerRadius(16)
                                      
                                      // Optional gradient for dynamic look
                                      LinearGradient(
                                          gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.03)]),
                                          startPoint: .top,
                                          endPoint: .bottom
                                      )
                                      .cornerRadius(16)
                                  }
                              )
                              .padding(.horizontal, 16)
                              .padding(.bottom, 5) // Adds spacing at the bottom
                          }
                          .onAppear {
                              Task {
                                  do {
                                      let user = try await UserService.fetchUser(withUid: currentRecap.userId)
                                      viewModel.updateRecapUser(recapId: currentRecap.id, user: user)
                                  } catch {
                                      print("Error fetching user: \(error.localizedDescription)")
                                  }
                              }
                          }
                      
                    
                    VStack {
                        Spacer()
                        
                        // Expandable Menu
                        HStack {
                            Spacer()
                            ExpandableMenuView3(
                                recap: currentRecap,
                                recaps: recaps,
                                currentRecapIndex: currentRecapIndex,
                                currentUser: UserService.shared.currentUser ?? User.default(),
                                currentUserRecap: User(id: "", email: "", username: "")
                            )
                        }
                        
                        
                    }
                }
            }
            .onDisappear {
                player?.pause()
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Helper Methods
    struct EnhancedBlurView: UIViewRepresentable {
        let style: UIBlurEffect.Style
        let intensity: CGFloat

        func makeUIView(context: Context) -> UIVisualEffectView {
            let blurEffect = UIBlurEffect(style: style)
            let blurEffectView = UIVisualEffectView(effect: blurEffect)
            blurEffectView.alpha = intensity
            return blurEffectView
        }

        func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
            uiView.alpha = intensity // Dynamically adjust blur intensity
        }
    }
      private func setupPlayer(for recap: Recap) {
          guard let mediaURLString = recap.mediaURL, let mediaURL = URL(string: mediaURLString) else { return }
          player = AVPlayer(url: mediaURL)
      }
      
      private func togglePlayback() {
          guard let player = player else { return }
          if isPlaying {
              player.pause()
          } else {
              player.play()
          }
          isPlaying.toggle()
      }
      
      private func isRecapInsideDesignatedArea(recapFrame: CGRect, screenFrame: CGRect) -> Bool {
          let threshold: CGFloat = 50
          return recapFrame.midY >= screenFrame.minY + threshold && recapFrame.midY <= screenFrame.maxY - threshold
      }
      
      private func handlePlayback(for index: Int, isInside: Bool) {
          if index == currentRecapIndex {
              if isInside {
                  player?.play()
                  isPlaying = true
              } else {
                  player?.pause()
                  isPlaying = false
              }
          }
      }
    
    private func observeUserProfilePrivacy(uid: String, completion: @escaping () -> Void) {
        UserService.shared.observePrivateProfile(uid: uid) { isPrivate in
            DispatchQueue.main.async {
                self.isProfilePrivate = isPrivate
                completion()
            }
        }
    }
    private func formattedViewCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
    
    
    @ViewBuilder
    private func profileDestination(for user: User) -> some View {
        if isProfilePrivate {
            PrivateProfileView(user: user)
        } else {
            UserProfileView(user: user)
        }
    }
}

struct WatchRecapView_Previews: PreviewProvider {
    static var previews: some View {
        // Create sample recaps
        let sampleRecaps = [
            Recap(
                id: "1",
                userId: "123",
                photoUrl: "https://example.com/image1.jpg",
                timestamp: Date(),
                mediaURL: "https://example.com/video1.mp4",
                mediaType: .video,
                views: 0,
                description: "Sample video description",
                username: "User1",
                profileImageUrl: "https://example.com/user1.jpg",
                likes: 0,
                comments: 0
            ),
            Recap(
                id: "2",
                userId: "456",
                photoUrl: "https://example.com/image2.jpg",
                timestamp: Date(),
                mediaURL: "https://example.com/image2.jpg",
                mediaType: .image,
                views: 0,
                description: "Sample image description",
                username: "User2",
                profileImageUrl: "https://example.com/user2.jpg",
                likes: 0,
                comments: 0
            )
        ]
        
        // Create a sample instance of LikeRecapsModel using the first recap
        let sampleLikeRecapsModel = LikeRecapsModel(recap: sampleRecaps[0]) // Pass the first Recap

        // Pass the sample recaps and the like recaps model to WatchRecapView
        WatchRecapView(
            recaps: sampleRecaps,
            likeRecapsModel: sampleLikeRecapsModel,
            screenWidth: UIScreen.main.bounds.width // Use screen width
        )
        .previewLayout(.device) // Optional: Show it as a full device screen in the preview
    }
}

extension User {
    static func `default`() -> User {
        return User(id: "", email: "", username: "") // Provide other required default values
    }
}

extension Color {
    func interpolate(to color: Color, fraction: CGFloat) -> Color {
        let fromComponents = UIColor(self).cgColor.components ?? [0, 0, 0, 0]
        let toComponents = UIColor(color).cgColor.components ?? [0, 0, 0, 0]

        let red = fromComponents[0] + fraction * (toComponents[0] - fromComponents[0])
        let green = fromComponents[1] + fraction * (toComponents[1] - fromComponents[1])
        let blue = fromComponents[2] + fraction * (toComponents[2] - fromComponents[2])
        let alpha = fromComponents[3] + fraction * (toComponents[3] - fromComponents[3])

        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
