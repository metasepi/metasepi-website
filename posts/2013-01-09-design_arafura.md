---
title: デザインArafura
description: Metasepiの最初のアーキティクチャを決めるでゲソ!
tags: haskell, design, specification, bootloader
---

調査を繰り返していても、設計は進まないでゲソ。
まずは第一歩、なにか作ってみればわかることもあるんじゃなイカ？
まずコードを書く前におおざっぱな設計を決めるでゲソ。
このエントリは何度も書き直すかもしれないでゲソ。

## 最初のデザイン

[Haskell/OCaml製のOSって何があるんでゲソ？](2012-08-18-haskell-or-ocaml-os.html)
でも書いたでゲソが、短時間でドッグフード可能
^[開発対象のkernelの上で当該kernelの開発/コンパイルができるようになること]
なkernelを得るには、関数型言語としてキレイな設計を考えている時間はないでゲソ。
むしろ純朴な実装で良いから、モノリシックkernelを関数型言語の設計に写像してしまった方が良いのではなイカ？

ここでは写像するモノリシックkernelとしてNetBSDを選定するでゲソ。
ソースコードが読みやすい、などの理由があるでゲソが、単にワシの趣味でゲソ。

このC言語で書かれたNetBSD kernelをいきなり型付き言語でスクラッチから書き直すのもやはりシンドイでゲソ。
もう少し楽できなイカ？
そこでいきなり全部ではなく、コンパイル可能/実行可能な状態を保ちながら少しずつ型付き言語で同じ機能を再実装するでゲソ。
少しずつ型をつけていけば、
いつかは全てのコードが型付き言語で動くようになるんじゃなイカ？

![](/draw/2012-12-27-arafura_design.png)

この「NetBSD kernelを型付き言語で少しずつ [スナッチ](http://ja.wikipedia.org/wiki/%E3%82%B9%E3%83%8A%E3%83%83%E3%83%81%E3%83%A3%E3%83%BC)
する」というデザインを
[アラフラ](http://ja.wikipedia.org/wiki/%E3%82%A2%E3%83%A9%E3%83%95%E3%83%A9%E6%B5%B7)
([Arafura](http://en.wikipedia.org/wiki/Arafura_Sea))と呼ぼうと思うでゲソ。
"A"からはじまる海の名前、最初の船出にはぴったりじゃなイカ!
^[また、コウイカの一種で色を変える小さなイカ
[Metasepia pfefferi](http://en.wikipedia.org/wiki/Metasepia_pfefferi)
が住んでいて、アラフラは「自由人」を意味するポルトガル語の古語に由来そうでゲソ。
でも"珊瑚礁からなる浅瀬が多く、航行の障害となる箇所も多数ある"そうでゲソ...]
もしこの海で航海に失敗しても、今度は"B"で始まる海(デザイン)を選べばいいんでゲソ。
合言葉は"ネバーギブアップ"でゲッソ!!!

## やってみよう!

これまでの調査でjhcがMetasepiの設計に使えそうなことが判明したでゲソ。
NetBSD kernelは割り込みハンドラを作ったりしなければならないので、
もっと簡単なNetBSD bootloaderを手始めにjhcを使ってスナッチしてみるでゲソ。
何事もトレーニングでゲッソ。

![](/draw/2012-12-27-loader.png)

NetBSD bootloaderのモジュールの構造は上図のようになっているでゲソ。
とりあえずboot2.cの中にあるコマンドラインループをjhcを使って書いてみたでゲソ。
^[[元ソース](https://gitorious.org/metasepi/netbsd-arafura/blobs/52c9e9c31425bdf983d0850b4e503c899a511edc/metasepi-arafura/sys/arch/i386/stand/boot/Boot2Ara.hs)]

~~~ {.haskell}
import Control.Monad
import Data.Maybe
import Data.Map (Map)
import qualified Data.Map as Map
import Foreign.C.Types
import Foreign.Ptr

foreign import ccall "glue_netbsdstand.h command_boot" c_command_boot :: Ptr a -> IO ()

commands :: Map String (IO ())
commands = Map.fromList [("help", command_help),
                         ("?", command_help),
                         ("boot", c_command_boot nullPtr)]

command_help :: IO ()
command_help = putStr $ "\
\commands are:\n\
\boot [xdNx:][filename] [-12acdqsvxz]\n\
\     (ex. \"hd0a:netbsd.old -s\"\n\
--snip--
\help|?\n\
\quit\n"

main :: IO ()
main = do
  putStrLn "Haskell bootmenu"
  forever $ do
    putStr "> "
    s <- getLine
    fromMaybe (putStr s) $ Map.lookup s commands
~~~

helpの表示はまぁいいとして、
kernelの読み込み+起動は既存コードにFFIで丸投げでゲソ。
このソースコードをイカのような方法でコンパイルしてみるでゲソ。

![](/draw/2012-12-27-compile.png)

ほいでもってコンパイルして生成されたbootloaderバイナリをqemuで動かしてみるでゲッソ!
(動画だと2:15ぐらいからMetasepi arafura版bootloaderをqemu上で起動しているでゲソ。)

<script type="text/javascript" src="http://ext.nicovideo.jp/thumb_watch/sm19788831"></script><noscript><a href="http://www.nicovideo.jp/watch/sm19788831">【ニコニコ動画】Metasepi arafura first boot.</a></noscript>

うん、helpの表示とkernelの起動はできているようでゲソ。まずは実験成功でゲソ!
ところでくれぐれも勘違いしてほしくないのは、
今回作ったbootloaderの99%はまだC言語製だということでゲソ。
このbootloaderの動きをシーケンス図で描いてみるとイカのようになるでゲソ。

![](/draw/2013-01-09-sequence_diagram.png)

なんと残念!かんじんの部分は既存のC言語ソースコードのままでゲソ。
でもこれから少しずつスナッチを繰り返すことで、
上図のシーケンスの多くの部分をHaskellのような型付き言語で記述することも夢ではないんじゃなイカ？

## 今見えている課題

まだbootloaderのスナッチははじまったばかりでゲソ。
kernelのことはまぁ置いといて、こんな小さなモジュールをスナッチしてみるだけでも色々な課題が見えてくるでゲソ。

a. コマンドライン引数を扱えるように
b. カスタムRTSに起因する問題が頻発している。ユーザ空間でカスタムRTSをデバッグできた方がいい
c. GCの使うヒープをallocで確保するのをやめて固定値に^[最悪1MB以降のメモリをヒープのために使っても良いが、他への応用を考えるとコンベンショナルメモリだけで挑戦する価値はある]
d. bootloaderのヒープをRTSのヒープと共用すると、RTSがヒープを圧迫する。分割管理すべき

今年いっぱいはjhc本体の調査と平行して、
このbootloaderのスナッチは継続してやってみると色々な問題を洗い出せて面白いかもしれないでゲソ。
