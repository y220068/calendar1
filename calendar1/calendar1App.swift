//
//  calendar1App.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/05/10.
//

// アプリ起動時に最初に実行されるファイルです。
// ここではアプリ全体の入口（エントリポイント）を用意し、最初に表示する画面を決めます。
// 「App」プロトコルに従った構造体で、WindowGroup の中に一番最初に表示する SwiftUI の View を置きます。
// コードが読めない人向けのやさしい説明：
// - これはアプリをスタートするための「スイッチ」です。
// - スイッチを入れると `ContentView()`（アプリのメイン画面）が表示されます。

import SwiftUI

@main
struct calendar1App: App {
    var body: some Scene {
        WindowGroup {
            // ここでアプリの最初の画面（メイン画面）を指定しています。
            // 画面の中身は `ContentView` に書かれています。
            ContentView()
        }
    }
}
