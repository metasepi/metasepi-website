---
title: Shape reentrant on Ajhc.
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
    * メリット: jgcのGCスタックをそのまま適用できる。GCコストがコンテキストの規模に比例する。並列実行できる
    * デメリット: コンテキスト間での状態共有には完全に正格なデータでなければならないなど制限がかる。設計者が意図しない所でサンクが共有されてしまう可能性

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
もちろんサンクが知らぬ間にコンテキスト間で共有されてしまうケースも考えられるでゲソ。
さらにSTMような複雑な状態共有方法についてはどうすれば解決するのか検討もつかないじゃなイカ。
しかし案Aより案Bの方が実装コストが低いことは容易に想像できるので、
まずは案Bで実装してみなイカ？
実装してみてgrinコードを眺めてみればまたアイデアがわくかもしれないでゲソ。

というわけで設計方針はなんとなくイカに分解できそうでゲソ。

* TimingDelay変数はPtr Word32型に
* SysTick_Handler関数はforeign export ccall SysTick_Handler :: IO ()
* foreign export ccallな関数は呼び出される度にGCスタックとヒープを割り当て
* foreign export ccallな関数が終了したら自GCスタックとヒープを解放
* GCスタック毎に別々のHaskellヒープを持つ
* s_alloc関数はコンテキストによって使うヒープを切り換え
* GC関連関数の実行を排他するためのロックプリミティブ

それぞれについて実施できそうか調べてみようじゃなイカ。

## foreign export ccallは(A)jhcでも使えるか

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

### コンパイルパイプラインを修正してforeign export ccallの入口/出口でGCスタックとHaskellヒープの割り当て/解放

foreign export ccallがgrinの中でどう扱われているのか気になったので、
foreign export ccallを使うHaskellコードを[ダンプしてみた](https://github.com/ajhc/ajhc-dumpyard/tree/master/use_foreign_export)でゲソ。
このダンプの中にあるgrinコード
[hs_main.c_final.grin](https://github.com/ajhc/ajhc-dumpyard/blob/master/use_foreign_export/hs_main.c_final.grin)

~~~
fFE@.CCall.fib :: (bits32) -> (bits32)
fFE@.CCall.fib w8 = do
  h100016 <- 0 `Lte` w8
  nd68 <- case h100016 of
    0 -> return (CJhc.Type.Word.Int 0)
    1 -> do
      h100018 <- 40 `Gte` w8
      case h100018 of
        1 -> do
~~~

と出力されたC言語コード
[hs_main.c](https://github.com/ajhc/ajhc-dumpyard/blob/master/use_foreign_export/hs_main.c)

~~~ {.c}
static uint32_t A_STD
fFE$__CCall_fib(gc_t gc,uint32_t v8)
{
        wptr_t v68;
        uint32_t v35;
        uint16_t v100016 = (((int32_t)0) <= ((int32_t)v8));
        if (0 == v100016) {
/* --snip-- */
int 
fib(int x11)
{
        return (int)fFE$__CCall_fib(saved_gc,(uint32_t)x11);
}
~~~

を見比べると、どうやら"fFE$__CCall_fib"という関数がforeign export ccallした関数のようでゲソ。
また
[hs_main.c_final.datalog](https://github.com/ajhc/ajhc-dumpyard/blob/master/use_foreign_export/hs_main.c_final.datalog)
を読むとイカのように型の定義まであるじゃなイカ。

~~~
% functions
-- snip --
func('fFE@.CCall.fib',1).
perform(assign,'v8','fFE@.CCall.fib@arg@0').
what('fFE@.CCall.fib@arg@0',funarg).
typeof('fFE@.CCall.fib@arg@0','bits32').
typeof('v8','bits32').
what('fFE@.CCall.fib@ret@0',funret).
typeof('fFE@.CCall.fib@ret@0','bits32').
-- snip --
subfunc('fW@.fR@.fJhc.List.243_sub','fFE@.CCall.fib').
-- snip --
perform(assign,'fFE@.CCall.fib@ret@0','v35').
~~~

このforeign export ccallな関数はgrinの中ではそのまんまCCallという型で表現されているでゲソ。
ということはイカのconvertFunc関数を修正すれば、
GCスタックとHaskellヒープの割り当て/解放処理をforeign export ccallな関数に注入できそうじゃなイカ。

~~~ {.haskell}
-- ajhc/src/C/FFI.hs
data FfiExport = FfiExport {
    ffiExportCName    :: CName,
    ffiExportSafety   :: Safety,
    ffiExportCallConv :: CallConv,
    ffiExportArgTypes :: [ExtType],
    ffiExportRetType  :: ExtType
    }
 deriving(Eq,Ord,Show,Typeable)
-- ajhc/src/C/Prims.hs
data CallConv = CCall | StdCall | CApi | Primitive | DotNet
    deriving(Eq,Ord,Show)
-- ajhc/src/C/FromGrin2.hs
convertFunc :: Maybe FfiExport -> (Atom,Lam) -> C [Function]
convertFunc ffie (n,as :-> body) = do
--snip--
        mstub <- case ffie of
                Nothing -> return []
                Just ~(FfiExport cn Safe CCall argTys retTy) -> do
                    newVars <- mapM (liftM (name . show) . newVar . basicType') argTys

                    let fnname2 = name cn
                        as2 = zip (newVars) (map basicType' argTys)
                        fr2 = basicType' retTy

                    return [function fnname2 fr2 as2 [Public]
                                     (creturn $ cast fr2 $ functionCall fnname $ (if fopts FO.Jgc then (variable (name "saved_gc"):) else id) $
                                      zipWith cast (map snd as')
                                                   (map variable newVars))]

        return (function fnname fr (mgct as') ats s : mstub)
~~~

### 使用済みGCスタックとHaskellヒープを次回確保用にプール

今のAjhcは通常イカのようにGCスタックとHaskellヒープを管理しているでゲソ。

* GCスタック: mallocで確保。サイズは1<<18エントリ
* Haskellヒープ: 1MBずつmegablockが補給される

"_JHC_JGC_FIXED_MEGABLOCK" defineが有効な場合、
GCスタックとHaskellヒープはどちらも固定サイズで唯一一つだけ確保されるのだったでゲソ。
少し冗長になるでゲソが、Cortex-M4に対応するにはイカのコンパイルフラグが必要になりそうでゲソ。

* "_JHC_JGC_GCSTACK_SIZE": GCスタックのサイズ指定
* "_JHC_JGC_FIXEDNUM_GCSTACK": GCスタックの個数(個数限定)
* "_JHC_JGC_MEGABLOCK_SHIFT": megablockのサイズ指定
* "_JHC_JGC_BLOCK_SHIFT": blockのサイズ指定
* "_JHC_JGC_FIXEDNUM_MEGABLOCK": megablockの個数(個数限定)

"_JHC_JGC_FIXED_MEGABLOCK"フラグは意味が変更になってしまうので撤廃するでゲソ。

また、GCスタックとHaskellヒープを動的に確保する場合も固定で確保する場合も
Ajhcランタイム内部のリストにプールしておき、
要求された時にmallocを呼ばずにミューテターに渡せるようにしたいでゲソ。
GCスタックもmegablockも一つのエントリは固定サイズなので、
見分けがつかないはずでゲソ。

### ランタイムのAPI修正

今回の変更でstruct s_arenaを文脈毎に分割して持つことになるでゲソ。
そこで、AjhcランタイムのAPIもそれに合わせて修正が必要になるでゲソ。

* struct s_arenaを全ての関数の第二引数でひきまわす (第一引数はGCスタックへのポインタ)
* struct s_arenaにgc_stack_baseメンバーを追加 (saved_gcメンバーも必要？)
* ミューテターから呼び出される関数の引数にstruct s_arenaを追加、そのような関数は...
    * eval
    * gc_add_root
    * gc_alloc
    * gc_array_alloc
    * gc_array_alloc_atomic
    * gc_perform_gc
    * s_alloc

gc_new_foreignptrとかは対応しなくていいんだろうかちょっと不安でゲソ

~~~ {.haskell}
-- File: ajhc/lib/jhc/Jhc/ForeignPtr.hs
foreign import safe ccall gc_malloc_foreignptr
    :: Word     -- alignment in words
    -> Word     -- size in words
    -> Bool     -- false for plain foreignptrs, true for ones with finalizers.
    -> UIO (Bang_ (ForeignPtr a))

foreign import safe ccall gc_new_foreignptr ::
    Ptr a -> UIO (Bang_ (ForeignPtr a))

foreign import unsafe ccall gc_add_foreignptr_finalizer
    :: Bang_ (ForeignPtr a)
    -> FinalizerPtr a
    -> IO ()
~~~

と、GCスタックへのポインタを渡していないライブラリがあるでゲソ。
そしてランタイムのGC側ではグローバル変数saved_gcからGCスタックを取り出しているでゲソ。

~~~ {.c}
/* File: ajhc/rts/rts/gc_jgc.c */
heap_t A_STD
gc_new_foreignptr(HsPtr ptr) {
        HsPtr *res = gc_array_alloc_atomic(saved_gc, 2, SLAB_FLAG_FINALIZER);
        res[0] = ptr;
        res[1] = NULL;
        return TO_SPTR(P_WHNF, res);
}
~~~

このように一旦GCスタックへのポインタの受け渡しが途切れる箇所がいくつかあり、それは

* gc_malloc_foreignptr
* gc_new_foreignptr
* hs_perform_gc
* jhc_alloc_init

の4つのようでゲソ。これはまずいでゲソ...
なんとかstruct arenaとGCスタックへのポインタを渡せるようにすべきでゲソ。
もっと踏み込むと"foreign import ccall"にGCスタックを渡すことを指定する修飾子が必要でゲソ。

## Ajhcに求められる排他制御とは何か

Cortex-M3ぐらいの小さなCPUではロックを作らなくても、割り込み禁止でいいんじゃなイカ？
とはいえユーザ空間でも動かせるように排他制御を抽象化しておいた方がいいでゲソ。
現時点での排他したいモノは...

* mallocヒープへの操作
* GCスタックとHaskellヒープの管理プールへの操作

排他の実現手段は...

* [pthread_mutex_lock](http://netbsd.gw.com/cgi-bin/man-cgi?pthread_mutex_lock++NetBSD-current)
* [NetBSD mutex_enter](http://netbsd.gw.com/cgi-bin/man-cgi?mutex_enter++NetBSD-current)
* CASを使ったシンプルなロック
* 割り込み禁止 (今はCortex-M3のみ)
* ノーガード戦法

条件変数
([pthread_cond_wait](http://netbsd.gw.com/cgi-bin/man-cgi?pthread_cond_wait++NetBSD-current)
や
[NetBSD cv_wait](http://netbsd.gw.com/cgi-bin/man-cgi?condvar++NetBSD-current))
が将来必要になることはないのかちょっと予測しきれないでゲソ...
不要ということおそらくないのでAPIの名前空間としては使用可能にした方がいいんじゃなイカ？
具体的なインターフェイスはイカの3つで今回のケースは充足するでゲソ。

* ロックの初期化
* lock
* unlock

ロックの解放はむつかしい問題でゲソが、今回はロックの解放はプロセスの終了と同時で問題ないでゲソ。

### グローバルサンクの評価での排他とBLACKHOLE

アドレスnh_startからnh_endまでの領域にはグローバルサンクが配置されているでゲソ。
少なくともグローバルサンクは複数のコンテキストで共有するので、なにか排他をするべきじゃなイカ？

### シグナルハンドラはsigwaitで取り扱う

mutex\_enterはkernelの割り込みハンドラから使用可能でゲソが、
pthread\_mutex\_lockはシグナルハンドラから使用することができないでゲソ。
そこで、POSIXのmutexを使う場合にはシグナル処理専用のスレッドを起こして、
sigwaitループさせた方が良さそうでゲソ。

## モジュール分割

先に見た通り、ロックを提供する手段にはいろいろあるでゲソ。
どの手段が最適ということはなく、Ajhcを適用するドメイン毎にロックの実現手段は選択できた方が良いでゲソ。
そこで、ロック関連の機能を提供するモジュールをHaskellライブラリ化して、
そのモジュールのAPIをHaskell側とランタイム側双方から使うようにするでゲソ。
そのライブラリの種別はイカの3つにするでゲソ。

* 空実装 (デフォルト)
* pthreadによる実装
* 実装なし (コンパイラ使用者が独自に実装)

このモジュールの公開APIを考えてみるでゲッソ!
ところでajhc/src/StringTable/StringTable\_cbits.cにpthread\_mutex\_lock
が入っているでゲソが、USE_THREADSが0になっていて殺されているでゲソ...
今回コイツも復活させてやった方がいいんじゃなイカ？
SelfTestがたまに失敗する原因はこいつなような気がしてきたでゲッソ。

### GHCで該当するAPI

せっかくAPIを切るのだからGHCと同じ名前にしておいた方が後々楽ができるんじゃなイカ？

* type Signal = CInt
* setHandler :: Signal -> Maybe (HandlerFun, Dynamic) -> IO (Maybe (HandlerFun, Dynamic))
* int stg_sig_install(int sig, int spi, void *mask)
* forkOS :: IO () -> IO ThreadId
* int forkOS_createThread ( HsStablePtr entry )
* typedef pthread_mutex_t Mutex
* void initMutex ( Mutex* pMut )
* \#define ACQUIRE_LOCK(mutex) foreign "C" pthread_mutex_lock(mutex)
* \#define RELEASE_LOCK(mutex) foreign "C" pthread_mutex_unlock(mutex)

書きだしたけれど、とりあえず今はスレッドが扱えれば良いので、シグナルの抽象化はやめておこうと思うでゲソ。
ということでこのGHCのAPIを真似てAjhcでの公開APIを決めるでゲソ〜。

### Haskell側に公開するAPI

* data ThreadId
* forkOS :: IO () -> IO ThreadId

### ランタイム側で準備するAPI

* typedef pthread_t jhc_threadid_t
* typedef pthread_mutex_t jhc_mutex_t
* void jhc_mutex_init(jhc_mutex_t *mutex)
* void jhc_mutex_lock(jhc_mutex_t *mutex)
* void jhc_mutex_unlock(jhc_mutex_t *mutex)
* jhc_threadid_t forkOS_createThread(void *(*wrapper) (void *), void *entry, int *err);
* void jhc_conc_init(void);
* void jhc_rts_lock(void);
* void jhc_rts_unlock(void);

## あとは実装するだけじゃなイカ!

これまではgcが全ての関数の第一引数になっていたじゃなイカ。
さらに
[arenaを全ての関数の第二引数に追加](https://github.com/ajhc/ajhc/commit/4f8a185bace5562e16fb9fb803a8db9d43578d54)
したでゲソ。
この対応でgcとarenaをコンテキスト毎に別々に取ることができ、GCをコンテキストローカルで実行できるようになったでゲソ。

またsaved_gcというグローバル変数でFFIによるC言語関数実行の前にgcの中断をメモしていたでゲソが、
イカの3つの関数だけgcとarenaを直接RTSに渡すようにすればこのsaved_gcは不要になるはずでゲソ。

~~~
$ git grep import lib|grep " safe"
lib/jhc/Jhc/ForeignPtr.hs:foreign import safe ccall gc_malloc_foreignptr
lib/jhc/Jhc/ForeignPtr.hs:foreign import safe ccall gc_new_foreignptr ::
lib/jhc/System/Mem.hs:foreign import ccall safe "hs_perform_gc" performGC :: IO ()
~~~

[foreign import jhc_context ccall](https://github.com/ajhc/ajhc/commit/889d2cf5d557b9d5b41a318efa8237d487de4142)
というAjhc専用のimport種別を作成して、この種別が有効な場合にはC言語の関数にgcとarenaを引数渡しするようになったでゲソ。

ところで
[Haskell 2010: 8 Foreign Function Interface](http://www.haskell.org/onlinereport/haskell2010/haskellch8.html)
によると、hs\_perform\_gc関数には引数を取れない決まりでゲソ。
するとRTSをロックして次回s_alloc時にGCを実行するようなフラグをarenaに立ててやる必要がありそうでゲソ。
とりあえず生存しているコンテキストに対応するarenaに対して
[次回s\_alloc呼び出しの際に強制GC実行](https://github.com/ajhc/ajhc/commit/fe31a9dd047ed0a564955a51ff51582f05f08b1f#L1L715)
するようにしてみたでゲソ。

さらにs\_cacheがグローバル管理されているのもなんとかしたいでゲソ。
s\_cacheの定義を新規structにまとめて、arenaの下にそのstructを配置すればなんとかなりそうじゃなイカ。

~~~ {.c}
/* File: ajhc/rts/rts/gc_jgc_internal.h */
struct s_cache {
        SLIST_ENTRY(s_cache) next;
        SLIST_HEAD(,s_block) blocks;
        SLIST_HEAD(,s_block) full_blocks;
        unsigned char color;
        unsigned char size;
        unsigned char num_ptrs;
        unsigned char flags;
        unsigned short num_entries;
        struct s_arena *arena;
#if _JHC_PROFILE
        unsigned allocations;
#endif
};

/* File: hs_main.c */
#include "jhc_rts_header.h"
static struct s_cache *cCJhc_Prim_Prim_$x3a;
static struct s_cache *cCJhc_Type_Basic_Just;
/* snip */
void 
jhc_hs_init(void)
{
        find_cache(&cCJhc_Prim_Prim_$x3a,saved_arena,TO_BLOCKS(sizeof(struct sCJhc_Prim_Prim_$x3a)),2);
        find_cache(&cCJhc_Type_Basic_Just,saved_arena,TO_BLOCKS(sizeof(struct sCJhc_Type_Basic_Just)),1);
/* snip */
                    sptr_t v69834446 = MKLAZY(x6);
                    {   gc_frame0(gc,1,v69834446);
                        wptr_t x7 = s_alloc(gc,arena,cCJhc_Prim_Prim_$x3a);
                        ((struct sCJhc_Prim_Prim_$x3a*)x7)->a1 = v106;
                        ((struct sCJhc_Prim_Prim_$x3a*)x7)->a2 = v69834446;
                        return x7;
~~~

同様にランタイムにあるグローバルs\_cacheも
[arenaの下に移動](https://github.com/ajhc/ajhc/commit/2c898ff294f93a6bbd6ad58c7dc26ab2aa87d8d4)
したでゲソ。

~~~ {.c}
/* File: ajhc/rts/rts/gc_jgc.c */
// 7 to share caches with the first 7 tuples
#define GC_STATIC_ARRAY_NUM 7
#define GC_MAX_BLOCK_ENTRIES 150

static struct s_cache *array_caches[GC_STATIC_ARRAY_NUM];
static struct s_cache *array_caches_atomic[GC_STATIC_ARRAY_NUM];
~~~

## 実験: pthreadを使ってTimingDelayをエミュレートしてみる

ハードウェア割り込みのエミュレートなので、forkOSは使わないでゲソがとにかくやってみるでゲソ。
...んんーーー [完成でゲソー!](https://github.com/ajhc/ajhc-dumpyard/tree/master/emulateTimingDelay)

このプログラムはTimingとDelayの2つのスレッドが動作して、
Delayスレッドの待ち合わせをTimingスレッドが解除するでゲソ。
実行してみると3秒毎に経過時間がコンソールに印字されるはずでゲソ。

まずC言語側から説明するでゲソ。
main関数はHaskellコードを実行する前にrun_timingDelayDecrement関数を新しいスレッドとして実行するでゲソ。
run_timingDelayDecrement関数は100ミリ秒毎にHaskellのtimingDelayDecrement関数を呼び出すでゲソ。
つまりこのスレッドはタイマー割り込みをエミュレーションしていることになるでゲソ。

~~~ {.c}
// main.c
static uint32_t TimingDelay = 0;

uint32_t *
getTimingDelay()
{
        return &TimingDelay;
}

void *run_timingDelayDecrement(void *p)
{
	for (;;) {
#define MILLI_SEC(N)  ((N) * 1000)
		usleep(MILLI_SEC(100));
		timingDelayDecrement();
	}
	/* NOTREACHED */
	return NULL;
}

int
main(int argc, char *argv[])
{
	int err;

        hs_init(&argc,&argv);
        if (jhc_setjmp(&jhc_uncaught)) {
                jhc_error("Uncaught Exception");
        } else {
		forkOS_createThread(&run_timingDelayDecrement, NULL, &err);
                _amain();
	}
        hs_exit();
        return 0;
}
~~~

今度はHaskell側でゲソ。
先のrun_timingDelayDecrementスレッドから呼び出されるtimingDelayDecrement関数は単にポインタの先にある
uint32_tの値を減算するだけでゲソ。
一方、Haskellのmain関数はmyDelay関数を繰り返し呼び出していて、
さっきのuint32_tに待ち合わせ時間を書き込んだ後、その値が0になるのをループで待ち合わせるでゲソ。

~~~ {.haskell}
{-# LANGUAGE ForeignFunctionInterface #-}
import Data.Word
import Control.Monad
import Foreign.Ptr
import Foreign.Storable

-- Timing
foreign import ccall "c_extern.h getTimingDelay" c_gettimingDelay :: IO (Ptr Word32)

timingDelayDecrement :: IO ()
timingDelayDecrement = do
  p <- c_gettimingDelay
  i <- peek p
  when (i >= 0) $ poke p (i - 1)

foreign export ccall "timingDelayDecrement" timingDelayDecrement :: IO ()

-- Delay
myDelay :: Word32 -> IO ()
myDelay nTime = do
  p <- c_gettimingDelay
  poke p nTime
  let while :: IO ()
      while = do
        p' <- c_gettimingDelay
        i <- peek p'
        if (i > 0) then while else return ()
  while

foreign import ccall "c_extern.h getTime" c_getTime :: IO Word64
~~~

これでスレッドの波をすいーいすいーじゃなイカー。
