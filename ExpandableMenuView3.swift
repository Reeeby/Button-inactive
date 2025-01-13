//
//  SwiftUIView.swift
//  Reeeby
//
//  Created by LN1800 on 12/3/24.
//

import SwiftUI


struct ExpandableMenuView3: View {
    @State private var isExpanded: Bool = false
    @State private var showCommentsSheet = false
    @State private var showReportSheet = false
    @State private var showLikedUsersSheet = false
    @State private var showDeleteAlert = false // State to show delete confirmation alert
    @State private var timer: Timer? // Timer for auto-closing the menu

    @StateObject private var likeRecapsModel: LikeRecapsModel
    @StateObject private var commentsViewModel: CommentsViewModel<Recap>
    @Environment(\.presentationMode) private var presentationMode // Access to the presentation mode

    let recaps: [Recap]
    let currentRecapIndex: Int
    let currentUser: User
    let currentUserRecap: User

    init(recap: Recap, recaps: [Recap], currentRecapIndex: Int, currentUser: User, currentUserRecap: User) {
        _likeRecapsModel = StateObject(wrappedValue: LikeRecapsModel(recap: recap))
        self.recaps = recaps
        self.currentRecapIndex = currentRecapIndex
        self.currentUser = currentUser
        self.currentUserRecap = currentUserRecap

        let currentRecap = recaps[currentRecapIndex]
        _commentsViewModel = StateObject(wrappedValue: CommentsViewModel(entity: currentRecap))
    }

    var body: some View {
        let currentRecap = recaps[currentRecapIndex]

        VStack {
            GeometryReader { geometry in
                HStack {
                    Spacer()

                    VStack {
                        Spacer()

                        Button {
                            if !isExpanded {
                                isExpanded = true
                                resetTimer()  // Start the timer when expanded
                            }
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
                                        ScrollView {
                                            VStack(spacing: 16) {
                                                HStack {
                                                    if !recaps.isEmpty {
                                                        Button(action: {
                                                            Task {
                                                            await likeRecapsModel.toggleLike()
                                                        }
                                                    }) {
                                                        Image(systemName: likeRecapsModel.isLiked ? "heart.fill" : "heart")
                                                            .foregroundColor(likeRecapsModel.isLiked ? .red : .white)
                                                    }
                                                    Text("\(likeRecapsModel.recap.likes ?? 0)")
                                                        .foregroundColor(.white)
                                                    }
                                                }
                                                .padding(.vertical, 10)

                                                HStack {
                                                    Button(action: {
                                                        showCommentsSheet.toggle()
                                                    }) {
                                                        Image(systemName: "bubble.left")
                                                            .foregroundColor(.white)
                                                            .padding(.vertical, 5)
                                                    }
                                                    Text("\(commentsViewModel.commentsCount)")
                                                        .foregroundColor(.white)
                                                }

                                                Button(action: {
                                                    showLikedUsersSheet.toggle()
                                                }) {
                                                    Image(systemName: "person.3.fill")
                                                        .foregroundColor(.white)
                                                }
                                                .padding(.vertical, 5)

                                                Button(action: {
                                                    showReportSheet.toggle()
                                                }) {
                                                    Image(systemName: "flag")
                                                        .foregroundColor(.white)
                                                }
                                                .padding(.vertical, 5)

                                                if currentUser.id == currentRecap.userId {
                                                    Button(action: {
                                                        showDeleteAlert = true
                                                    }) {
                                                        Image(systemName: "trash")
                                                            .foregroundColor(.red)
                                                    }
                                                    .padding(.vertical)
                                                }
                                            }
                                            .padding(.vertical)
                                        }
                                        .frame(width: 100)
                                        .transition(.opacity)
                                    }
                                    .scrollIndicators(.hidden)
                                }
                            }
                        }
                        .frame(width: isExpanded ? 100 : 60, height: isExpanded ? 100 : 60)
                        .animation(.spring(), value: isExpanded)

                        Spacer()
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .sheet(isPresented: $showCommentsSheet) {
            CommentsView(entity: currentRecap)
        }
        .sheet(isPresented: $showReportSheet) {
            ReportUserView(
                user: currentUserRecap,
                reportedItemLink: "link_to_reported_item",
                reportedItemType: .recap,
                reportedItemId: currentRecap.id
            )
        }
        .sheet(isPresented: $showLikedUsersSheet) {
            UserWhoLikedRecap(recap: currentRecap)
        }
        .alert("Delete Recap", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("OK", role: .destructive) {
                Task {
                    await likeRecapsModel.deleteRecap()
                    presentationMode.wrappedValue.dismiss() // Dismiss the view
                }
            }
        } message: {
            Text("Are you sure you want to delete this recap? This action cannot be undone.")
        }
    }

    private func resetTimer() {
        // Invalidate any existing timer
        timer?.invalidate()

        // Create a new timer to hide the menu after 15 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { _ in
            withAnimation {
                isExpanded = false
            }
        }
    }
}
