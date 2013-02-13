---
title: (作成中) jhc: Grin => C
description: jhcは
tags: compiler, jhc, c, grin
---

お待ちかねでゲソ!
jhcのコンパイルパイプラインを詳細に調査してみようと思うでゲッソ。

~~~
$ cat Fib.hs
fibonacci :: [Int]
fibonacci = 1:1:zipWith (+) fibonacci (tail fibonacci)
main :: IO ()
main = print $ take 40 fibonacci
$ make
sh jhc_dump_code.sh Fib.hs > jhc_dump_code.log 2>&1
dot -Tpng hs.out_grin.dot > hs.out_grin.dot.png
~~~

この簡単なフィボナッチ数列を出力するだけのプログラムをjhcでコンパイルして、
[そのダンプ](https://gitorious.org/metasepi/jhc-arafura/trees/arafura/metasepi-arafura/misc/jhc_dump_fib)
を取ったでゲソ。
今回はその中でイカの2つを比較することで、GrinからC言語への変換がどのようになっているのか調査してみようと思うでゲッソ。

* [hs.out_final.grin](https://gitorious.org/metasepi/jhc-arafura/blobs/arafura/metasepi-arafura/misc/jhc_dump_fib/hs.out_final.grin) - C言語への変換直前のGrin
* [hs.out_code.c](https://gitorious.org/metasepi/jhc-arafura/blobs/arafura/metasepi-arafura/misc/jhc_dump_fib/hs.out_code.c) - 最終的なC言語ソース

一応、上記のダンプが所望のものかどうかjhc本体のソースコードでチェックしてきるでゲソ。

~~~ {.haskell}
-- jhc/src/Grin/Main.hs
compileToGrin prog = do
    stats <- Stats.new
    putProgressLn "Converting to Grin..."
-- snip --
    x <- storeAnalyze x
    => dumpFinalGrin x
       writeFile (outputName ++ "_grin.dot") (graphGrin grin)
       dumpGrin "final" grin
    compileGrinToC x
~~~

うん。ちゃんとC言語に変換する直前のダンプでゲソ。
先のhs.out_final.grinを見てみるとグローバルから辿れる要素はイカのようでゲソ。

* Caf:  v-930757141
* Func: b_main :: () -> ()
* Func: fW@.fJhc.Inst.Show.showWord :: (bits32,I) -> (N)
* Func: fJhc.Show.shows :: (I,I) -> (N)
* Func: fR@.fJhc.Show.11_showl :: (I,N) -> (N)
* Func: ftheMain$2 :: (I,I) -> (N)
* Func: fR@.fJhc.Basics.++ :: (I,N) -> (N)
* Func: ftheMain$3 :: () -> (N)
* Func: fR@.fJhc.Basics.zipWith :: (I,I) -> (N)
* Func: fW@.fR@.fJhc.List.387_f :: (bits32,I) -> (N)
* Func: ftheMain :: () -> ()

上記の関数は-dgrin-graphが吐いた図によるとイカのような関係にあるらしいでゲソ。

[![](https://gitorious.org/metasepi/jhc-arafura/blobs/raw/4c932225363068e235d211ad9340c94d2be45907/metasepi-arafura/misc/jhc_dump_fib/hs.out_grin.dot.png)](https://gitorious.org/metasepi/jhc-arafura/blobs/raw/4c932225363068e235d211ad9340c94d2be45907/metasepi-arafura/misc/jhc_dump_fib/hs.out_grin.dot.png)

これらがどのようにC言語に写像されているか、
また逆にC言語ソースコードで上記由来ではない部分が存在するかどうけチェックしてみなイカ？


## ダンプ解析

### Caf:  v-930757141

~~~ {.haskell}
-- Cafs
v-930757141 := (FtheMain$3)
~~~

~~~ {.c}
typedef struct fptr * fptr_t;
typedef struct sptr * sptr_t;
typedef struct node {
        fptr_t head;
        sptr_t rest[];
} A_MAYALIAS node_t;

#define P_WHNF  0x0
#define P_LAZY  0x1
#define P_VALUE 0x2
#define P_FUNC  0x3
#define TO_SPTR_C(t,x) (typeof (x))((uintptr_t)(x) + (t))
        // attach a ptype to a smart pointer, suitable for use by constant initialializers
#define TO_FPTR(fn)   TO_SPTR_C(P_FUNC,(fptr_t)fn)
#define MKLAZY_C(fn)  TO_SPTR_C(P_LAZY,(sptr_t)fn)

/* CAFS */
/* v-930757141 = (FtheMain$3)*/
static node_t _g930757141 = { .head = TO_FPTR(&E__ftheMain$d3) };
#define g930757141 (MKLAZY_C(&_g930757141))
~~~

### Func: b_main :: () -> ()
### Func: fW@.fJhc.Inst.Show.showWord :: (bits32,I) -> (N)
### Func: fJhc.Show.shows :: (I,I) -> (N)
### Func: fR@.fJhc.Show.11_showl :: (I,N) -> (N)
### Func: ftheMain$2 :: (I,I) -> (N)
### Func: fR@.fJhc.Basics.++ :: (I,N) -> (N)
### Func: ftheMain$3 :: () -> (N)
### Func: fR@.fJhc.Basics.zipWith :: (I,I) -> (N)
### Func: fW@.fR@.fJhc.List.387_f :: (bits32,I) -> (N)
### Func: ftheMain :: () -> ()
