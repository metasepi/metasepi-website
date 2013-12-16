---
title: 簡約!? λカ娘 Rock!の紹介とHaskell製Androidアプリの解説
description: NDKでHaskellも動くでゲソー
tags: haskell, book, android, ajhc
---

![](http://www.paraiso-lang.org/ikmsm/images/c85-cover-s.jpg)

この記事は
[Android Advent Calendar 2013 - Qiita [キータ]](http://qiita.com/advent-calendar/2013/android)
の12/17(火曜)分じゃなイカ。

だいぶ息切れしてきた関数型プログラミングの本
[簡約!? λカ娘 Rock!](http://www.paraiso-lang.org/ikmsm/books/c85.html)
がコミックマーケット85
[3日目 西地区 す-03a](http://twitcmap.jp/?id=0085-3-SUh-03-a)
で出るでゲソ。みんな買ってほしいでゲソ!

* 第1章 λカ娘探索2?
* 第2章 僕のカノジョはスナッチャー # <= コレ書いた

がもくじで、
[@master_q](https://twitter.com/master_q)
は第2章を書いたらしいでゲソ。
この記事では
[Android NDK](http://developer.android.com/tools/sdk/ndk/index.html)
に付属しているnative-activityサンプルアプリケーションをHaskell化するでゲソ。
当然native-activityはC言語で書かれているので、いきなり全部をHaskell化できないじゃなイカ。
そこで
[スナッチ設計](http://www.slideshare.net/master_q/20131020-osc-tokyoajhc)
という手法を使って動作可能なまま少しずつHaskellで設計置換していくんでゲソ。

記事が気になったら是非
[サンプル版pdf](http://www.paraiso-lang.org/ikmsm/books/c85-sample.pdf)
を読んでみてほしいでゲッソ!


## 
