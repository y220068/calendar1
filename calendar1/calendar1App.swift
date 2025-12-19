//
//  calendar1App.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/05/10.
//

import SwiftUI

// アプリのエントリポイント（説明）
// - ここはアプリが起動したときに最初に呼ばれる場所です。
// - `@main` が付いた構造体（`calendar1App`）がアプリのルートになります。
// - `body` の中で表示する最初のビュー（ここでは `ContentView()`）を指定します。
// - 初心者向け：このファイルを修正するとアプリ全体の開始画面を変えられます。通常は変更する必要はほとんどありません。

@main
struct calendar1App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
