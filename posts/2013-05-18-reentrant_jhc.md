---
title: (作成中) Shape reentrant on Ajhc.
description: 再入可能を実現せよ。でゲソ!
tags: jhc, ajhc, reentrant, interrupt, lock
---

いきなりAjhcの吐くコードを並列実行可能にすることはハードルが高すぎるでゲソ。
まず再入可能を実現しなイカ？

## スナッチ対象を決めるでゲソ

再入可能を実現するにあたって、何かアプリケーション例があった方が良いでゲソ。
[Cortex-M3向けデモ](https://github.com/ajhc/demo-cortex-m3)
の中にイカのようなコードがあるでゲソ。

~~~ {.gnuassembler}
/* File: demo-cortex-m3/stm32f3-discovery/Device/startup_stm32f30x.s */
 	.section	.isr_vector,"a",%progbits
	.type	g_pfnVectors, %object
	.size	g_pfnVectors, .-g_pfnVectors

g_pfnVectors:
	.word	_estack
	.word	Reset_Handler
/* snip */
	.word	PendSV_Handler
	.word	SysTick_Handler
~~~

~~~ {.c}
// File: demo-cortex-m3/stm32f3-discovery/src/main.c
__IO uint32_t TimingDelay = 0;

void SysTick_Handler(void)
{
  TimingDelay_Decrement();
}

void TimingDelay_Decrement(void)
{
  if (TimingDelay != 0x00)
  { 
    TimingDelay--;
  }
}

void Delay(__IO uint32_t nTime)
{
  TimingDelay = nTime;

  while(TimingDelay != 0);
}
~~~

このしくみはDelay関数による指定時間待ち合わせを実現するために、イカのような動作を期待しているでゲソ。

1. Delay関数呼び出し
2. Delay関数はグローバル変数TimingDelayに待ち時間を代入
3. Delay関数はそのままTimingDelayが0になるのを待つ
4. クロック割り込みでSysTick_Handler関数が起動される
5. SysTick_Handler関数はTimingDelayを1減ずる
6. 4と5が繰り返されるとそのうちTimingDelayが0になる
7. 3の待ちが解除される

上記コードをHaskell化してみなイカ？

## 設計方針

設計の方針に大きく影響するのはHaskellヒープの確保でゲソ。これは大きく2つの案に分かれるでゲソ。

* A. 実行バイナリの中でHaskellヒープは唯一一つだけ確保する
    * メリット: STMなどコンテキスト間での状態共有を実装しやすい
    * デメリット: ミューテターのクリティカルリージョン保護を実装する必要がある。場合によってはjgcの抜本的見直しが必要
* B. Haskellヒープをコンテキスト毎に分割して持つ
    * メリット: jgcのGCスタックをそのまま適用できる。GCコストがコンテキストの規模に比例する
    * デメリット: コンテキスト間での状態共有には完全に正格なデータでなければならないなど制限がかる

通常はAの方が良い案でゲソ。GHCも案Aを採用しているじゃなイカ。
しかしAjhcではミューテターが生C言語である関係上、
明示的なコンテキストスイッチをミューテター側から判断させるのかきびしいでゲソ。
さらに将来NetBSD kernelをスナッチすることも考えると、
RTSを頻繁に呼び出すような息継ぎをミューテターにさせるのはナンセンスとしか思えないでゲソ。

案Bに関して考えると思わぬメリットあり、
それはコンテキスト間でGC関連の処理を完全に分離できるということでゲソ。
つまり並列にGCさせることももちろんできるでゲソ。
さらにHaskellヒープをどれぐらい汚すかはコンテキストによって決まるので、
ヒープを汚したコンテキストが自分でお掃除する責務を負うのでコンテキスト毎のGC負荷が予測しやすいでゲソ。
kernelのほとんどの部分はイベントドリブンであることを考えると、
世代別GCを作らなくても乗り切れるかもしれないじゃなイカ。

案Bの問題はコンテキスト間の状態共有でゲソが、
プリミティブ型へのPtr型を使う分には何も問題にはならないでゲソ。
STMのような複雑な状態共有方法については別途考えるとして、
案Aより案Bの方が実装コストが低いことは容易に想像できるので、
まずは案Bで実装してみなイカ？

というわけで設計方針はなんとなくイカに分解できそうでゲソ。

* TimingDelay変数はPtr Word32型に
* SysTick_Handler関数はforeign export ccall SysTick_Handler :: IO ()
* foreign exportな関数は呼び出される度にGCスタックを別途割り当て
* GCスタック毎に別々のHaskellヒープを持つ
* GC関連関数の実行を排他するためのロックプリミティブ

それぞれについて実施できそうか調べてみようじゃなイカ。

## foreign exportは(A)jhcでも使えるか

Main.main関数がないとコンパイルエラーになるでゲソが、いちおう使えるでゲソ。
[SlimHaskell/FibHs_ajhc](https://github.com/master-q/SlimHaskell/tree/master/FibHs_ajhc)
にソースコードとコンパイル済みバイナリを置いたでゲソ。

~~~
$ size */FibHs | sort -n -k 6
   text    data     bss     dec     hex filename
  13527    1224     712   15463    3c67 FibHs_ajhc/FibHs
 285321   11048   26088  322457   4eb99 FibHs13/FibHs
 303321   12416   26088  341825   53741 FibHs12/FibHs
 415297   27152   26080  468529   72631 FibHs11/FibHs
 719915   73896   26080  819891   c82b3 FibHs10/FibHs
 809675   81128   26080  916883   dfd93 FibHs9/FibHs
1102459  108864   26080 1237403  12e19b FibHs8/FibHs
1316273  128520   26496 1471289  167339 FibHs7/FibHs
1662383  134296   42880 1839559  1c11c7 FibHs6/FibHs
1704127  134856   44088 1883071  1cbbbf FibHs5/FibHs
2503048  266320   44088 2813456  2aee10 FibHs4/FibHs
2523847  266616   44088 2834551  2b4077 FibHs3/FibHs
2719976  282776   44088 3046840  2e7db8 FibHs2/FibHs
2780783  290568   45592 3116943  2f8f8f FibHs1/FibHs
2784294  290592   47960 3122846  2fa69e FibHs0/FibHs
~~~

ところでjhcの威力はすごいでゲソ。
[簡約! λカ娘(4)](http://www.paraiso-lang.org/ikmsm/books/c83.html)
でGHCあれだけがんばったサイズ削減結果よりはるかに小さいバイナリを吐くでゲソ。
すごいじゃなイカ!

## GCスタックとHaskellヒープのコンテキストへの割り当てと解放

### コンパイルパイプラインを修正してforeign exportの入口/出口でGCスタックとHaskellヒープの割り当て/解放
### 使用済みGCスタックとHaskellヒープを次回確保用にプール

xxx

## 排他制御とは何か

Cortex-M3ぐらいの小さなCPUではロックを作らなくても、割り込み禁止でいいんじゃなイカ？
とはいえユーザ空間でも動かせるように排他制御を抽象化しておいた方がいいでゲソ。
排他したいモノは...

* mallocヒープへの操作
* GCスタックとHaskellヒープの管理プールへの操作

排他の実現手段は...

* pthread_mutex_lock
* NetBSD mutex_enter
* 割り込み禁止 (今はCortex-M3のみ)
* ノーガード戦法

条件変数が将来必要になることはないのかちょっと予測しきれないでゲソ...

xxx
