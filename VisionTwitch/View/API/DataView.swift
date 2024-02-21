//
//  DataView.swift
//  VisionTwitch
//
//  Created by Adam Gastineau on 2/17/24.
//

import SwiftUI
import Twitch

struct DataView<T, E: Error, Content: View, Loading: View, ErrorView: View>: View {
    private let taskClosure: (_: Helix) -> Task<T, E>

    private let content: (_: T) -> Content
    private let loading: (_: T?) -> Loading
    private let error: (_: E) -> ErrorView

    private let requiresAuth: Bool

    @State private var state: DataProvider<T, E>?
    @State private var hasRendered = false

    init(taskClosure: @escaping (_: Helix) -> Task<T, E>, @ViewBuilder content: @escaping (_: T) -> Content, @ViewBuilder loading: @escaping (_: T?) -> Loading, @ViewBuilder error: @escaping (_: E) -> ErrorView, requiresAuth: Bool) {
        self.taskClosure = taskClosure

        self.content = content
        self.loading = loading
        self.error = error

        self.requiresAuth = requiresAuth
    }

    var body: some View {
        // TODO: Remove ZStack
        ZStack {
            if let data = self.state?.data {
                switch data {
                case .success(let data):
                    self.content(data)
                case .failure(let error):
                    self.error(error)
                case .loading(let data):
                    self.loading(data)
                case .noData:
                    Text("no data")
                }
            } else {
                // Do nothing
            }
        }
        .onAppear {
            // Subscribe to auth updates
            self.state?.register()

            if self.hasRendered {
                if let lastFetchToken = self.state?.lastFetchToken, lastFetchToken != AuthController.shared.currentToken {
                    // Token has changed since we were last rendered, refetch
                    self.state?.reload()
                } else {
                    // If we we had no data, or error, refetch
                    switch self.state?.data {
                    case .noData, .failure:
                        self.state?.reload()
                    default:
                        break
                    }
                }

                return
            }

            self.hasRendered = true

            self.state = DataProvider(taskClosure: taskClosure, requiresAuth: self.requiresAuth)

            if !self.requiresAuth || AuthController.shared.isAuthorized {
                self.state?.reload()
            }
        }
        .onDisappear {
            self.state?.cancel()
        }
    }
}

extension DataView where Loading == CustomProgressView {
    init(taskClosure: @escaping (_: Helix) -> Task<T, E>, @ViewBuilder content: @escaping (_: T) -> Content, @ViewBuilder error: @escaping (_: E) -> ErrorView, requiresAuth: Bool) {
        self.init(taskClosure: taskClosure, content: content, loading: { _ in
            CustomProgressView()
        }, error: error, requiresAuth: requiresAuth)
    }
}

struct CustomProgressView: View {
    var body: some View {
        ProgressView()
    }
}
