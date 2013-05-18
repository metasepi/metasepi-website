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

このコードをHaskell化してみなイカ？
実現方法でゲソがなんとなくイカに分解できそうでゲソ。

* TimingDelay変数はPtr Word32型
* SysTick_Handler関数はforeign export ccall func :: IO ()
* SysTick_Handler関数専用にGCスタックを別に用意
* GC関連関数の実行を排他するためのロックプリミティブ

## foreign exportは(A)jhcでも使えるか

Main.main関数がないとコンパイルエラーになるでゲソが、いちおう使えるでゲソ。
[SlimHaskell/FibHs_ajhc](https://github.com/master-q/SlimHaskell/tree/master/FibHs_ajhc)

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

## 排他制御とは何か
