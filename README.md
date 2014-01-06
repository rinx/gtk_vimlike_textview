# これはなに？
mikutterの投稿ボックスにVimっぽいキーバインドを追加します．
比較的頻繁に利用すると思われるキーバインドは実装してありますが，
すべてのキーバインドやその他の機能が利用できるわけではありません．

現在はNORMALモード，INSERTモード，VISUALモードが存在しており，
それぞれのモードにおいて，テキストボックスの背景色が白，黄，ピンクになります．

# mikutterで使うには
**gtksourceview2** が必要ですのでインストールしましょう．

    gem install gtksourceview2

インストールできたら，git cloneします．

    mkdir -p ~/.mikutter/plugin
    cd ~/.mikutter/plugin
	git clone https://github.com/penguin2716/gtk_vimlike_textview

あとはmikutterを再起動すれば使えると思います．
