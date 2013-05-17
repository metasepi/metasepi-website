---
title: (作成中) Shape reentrant on Ajhc.
description: 再入可能を実現せよ。でゲソ!
tags: jhc, ajhc, reentrant, interrupt, lock
---


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

## ロックとは何か
