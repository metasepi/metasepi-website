---
title: Ajhcプロジェクトはじめよう
description: リポジトリを用意してjhcを改造しまくるでゲッソ!
tags: haskell, compiler, jhc, ajhc
---

これまで
[jhc](http://repetae.net/computer/jhc/)
のソースコードを読みながら少しずつ改造をして遊んでいたでゲソが、
そろそろpatchが増えてきてまっとうなリポジトリを用意しないと破綻しそうでゲソ。
できればpatchをjhc本家に取り込んでもらいたいところでゲソ。
ところが原作者の[John](http://repetae.net/pictures/pirate1.jpg)がどうも忙しいらしく、なかなかmergeしてくれないでゲソ...
^[[Ajhcのファーストリリース](http://www.haskell.org/pipermail/haskell-cafe/2013-March/107013.html)
をしたら
[全部merge](http://repetae.net/dw/darcsweb.cgi?r=jhc)してくれたでゲソ。
[Johnはやる気になればデキる男](http://repetae.net/pictures/cso/john_cso2_small.jpg)なんでゲソ!]

あまりプロジェクトのforkをしたくないところでゲソが、
このままでは作業が進まないのでjhc向けpatchを貯めるだけのプロジェクトを作ったでゲソ。
その名も
[Ajhc - arafura-jhc](http://ajhc.masterq.net/)
^[もしくは単に"A fork of jhc"を略して"Ajhc"]
でゲッソ!

## まず最初の改造は？

とはいえ改造にあたって何かテーマを決めたいでゲソ。
jhcは小さなバイナリを吐けるのだから、小さなマイコンでHaskellコードを動かすとかどうでゲソ？
例えば以下のようなマイコンであればある程度メモリもあるのでなんとなるんじゃなイカ？JTAGも付いてるのでgdbでデバッグもできるでゲソ。
しかも秋月価格で[￥950(税込)](http://akizukidenshi.com/catalog/g/gM-06268/)
と無茶苦茶安いでゲソ。
ところでこの挑発的な価格はいったいなんなんでゲソ...
ST、怒らせると怖い子でゲソ...

[![](https://raw.github.com/ajhc/demo-cortex-m3/master/img/stm32f3-discovery.jpg)](http://www.st.com/web/en/catalog/tools/FM116/SC959/SS1532/PF254044)

* Name: [STM32F3DISCOVERY](http://www.st.com/web/en/catalog/tools/FM116/SC959/SS1532/PF254044)
* CPU: STM32F303VCT6
* ROM: 256kB
* RAM: 48kB

ぐぬぬぬ...ということで
[移植できたでゲソ](https://github.com/ajhc/demo-cortex-m3)!
ちゃんとHaskellヒープも使えてGCも動くでゲソ。
RAMは28kBしか使っていないでゲッソ!!!

    $ pwd
    /home/kiwamu/src/demo-cortex-m3/stm32f3-discovery
    $ make
    $ arm-none-eabi-size main.elf
       text    data     bss     dec     hex filename
      15796    1160   26876   43832    ab38 main.elf

<script type="text/javascript" src="http://ext.nicovideo.jp/thumb_watch/sm20336813"></script><noscript><a href="http://www.nicovideo.jp/watch/sm20336813">【ニコニコ動画】STM32の上でモールス信号をパタパタしてみた。もちろんHaskellで</a></noscript>

## どこらへんを修正したの？

Ajhcへの変更は
[このpatch](https://github.com/ajhc/ajhc/commit/3167551530b0576cf1f42f928865868ce9aa0b50)
だけでゲソ。
修正内容を解説するでゲソー。

1. BLOCK_SIZEとMEGABLOCK_SIZEをMakefileから調整できるように
2. MEGABLOCKを唯一1つだけ使い、動的確保しないように
3. Cortex-M3では関数ポインタジャンプのアドレスbit0を1立てる
   ([詳細](http://communities.mentor.com/community/cs/archives/arm-gnu/msg01904.html))
4. BLOCKが不足したら即時GCするNaive GCフラグ
5. GCスタックの成長幅をMakefileから調整できるように

このpatchのあたったAjhcを使って、
[いろいろこねくりまわせ](https://github.com/ajhc/demo-cortex-m3#porting-the-demo-to-a-new-platform)
ば
[こんなの](https://github.com/ajhc/demo-cortex-m3/tree/master/stm32f3-discovery)
ができるんでゲソ。

## Ajhcプロジェクトはどこへ向かうの？

完全にjhcをforkして一人歩きする予定はAjhcプロジェクトにはないでゲソ。
Ajhcはあくまでjhcにmergeされていないpatchをためておくための器にすぎないのでゲソ。
そのため有用なpatchは
[jhcメーリングリスト](http://www.haskell.org/mailman/listinfo/jhc)
にて協議の上
[jhcにmerge](https://github.com/ajhc/ajhc#for-developing)
してもらわなければならないでゲソ。
在りし日の
[EGCS (Experimental/Enhanced GNU Compiler System)](http://ja.wikipedia.org/wiki/GNU%E3%82%B3%E3%83%B3%E3%83%91%E3%82%A4%E3%83%A9%E3%82%B3%E3%83%AC%E3%82%AF%E3%82%B7%E3%83%A7%E3%83%B3#EGCS)
のように、jhc本体の活動が活発になったらAjhcは消滅すべきプロジェクトでゲソ。

Ajhcプロジェクトの
[ロードマップ的なにか](https://github.com/ajhc/ajhc#future-plan)
を書いてみたでゲソが、予定は未定。どーなるかわからないでゲソ。
