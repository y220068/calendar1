//
//  calendar1App.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/05/10.
//

import SwiftUI

// @main を付けた型がアプリ起動時に最初に呼ばれる構造体です。
// ここでは SwiftUI の App プロトコルに準拠し、最初の画面として ContentView を表示します。
@main
struct calendar1App: App {
    // Scene を返す computed property
    var body: some Scene {
        WindowGroup {
            // アプリ起動時に最初に表示するビュー
            ContentView()
        }
    }
}
