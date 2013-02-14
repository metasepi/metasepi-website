---
title: (作成中) jhcコンパイルパイプライン: Grin => C
description: jhcコンパイルパイプラインを後段から順番に読んでいかなイカ？
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

1. Caf:  v-930757141
2. Func: b_main :: () -> ()
3. Func: fW@.fJhc.Inst.Show.showWord :: (bits32,I) -> (N)
4. Func: fJhc.Show.shows :: (I,I) -> (N)
5. Func: fR@.fJhc.Show.11_showl :: (I,N) -> (N)
6. Func: ftheMain$2 :: (I,I) -> (N)
7. Func: fR@.fJhc.Basics.++ :: (I,N) -> (N)
8. Func: ftheMain$3 :: () -> (N)
9. Func: fR@.fJhc.Basics.zipWith :: (I,I) -> (N)
10. Func: fW@.fR@.fJhc.List.387_f :: (bits32,I) -> (N)
11. Func: ftheMain :: () -> ()

また、上記の関数は-dgrin-graphが吐いた図によるとイカのような関係にあるらしいでゲソ。

[![](https://gitorious.org/metasepi/jhc-arafura/blobs/raw/4c932225363068e235d211ad9340c94d2be45907/metasepi-arafura/misc/jhc_dump_fib/hs.out_grin.dot.png)](https://gitorious.org/metasepi/jhc-arafura/blobs/raw/4c932225363068e235d211ad9340c94d2be45907/metasepi-arafura/misc/jhc_dump_fib/hs.out_grin.dot.png)

これらがどのようにC言語に写像されているか、
また逆にC言語ソースコードで上記由来ではない部分が存在するかどうかチェックしてみなイカ？

## ダンプ解析 (例による理解)

### 1. Caf:  v-930757141

~~~ {.haskell}
-- Grin --
-- Cafs
v-930757141 := (FtheMain$3)
~~~

~~~ {.c}
/* C言語 */
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

これを図にまとめると、イカのようになるでゲソ。
CAF(Constant Applicative Form) というのは
「一度実行したら、その結果をメモ化して使いまわせるもの」のことでゲソ。
^[[簡約!? λカ娘(算) - 参照透明な海を守る会](http://www.paraiso-lang.org/ikmsm/books/c82.html) を参照]
ということはg930757141というのは未評価のサンクで、
このサンクの値を評価して確定させるためにはCode pointerの先にある
E__ftheMain$d3()関数を実行する必要があるということが予想できるじゃなイカ。

![](/draw/2013-02-14-jhc_grin_to_c_1_v-930757141.png)

ではこのサンクg930757141はどのように使われるんでゲソ？

~~~ {.c}
const void * const nh_stuff[] = {
&_g930757141, &_c1, &_c2, &_c3, NULL
};
~~~

まずnh_stuff配列から参照されているでゲソ。
これはGCルートのようでゲソ。
グローバルから見えるサンクは当然解放することができないので、
GCルートになるはずでゲソ。

~~~ {.c}
ftheMain
=> eval(gc,g930757141)
   void *ds = FROM_SPTR(g930757141); // (uintptr_t)(x) & ~0x3)
   sptr_t h = (sptr_t)(GETHEAD(ds)); // ((node_t *)(x))->head
   eval_fn fn = (eval_fn)FROM_SPTR(h);
   => wptr_t r =  E__ftheMain$d3(gc,_g930757141); // (*fn)(gc,NODEP(ds));
      => wptr_t r2 = ftheMain$d3(gc);
         => return fR$__fJhc_Basics_$pp(gc,c2,SET_RAW_TAG(CJhc_Prim_Prim_$BE));
      => update(_g930757141,r2);
         GETHEAD(_g930757141) = (fptr_t)r2;
      gc_add_root(gc,(sptr_t)r2);
      return r2;
   return r;
~~~

さらg930757141はevel()関数を通して評価され、
最終的に_g930757141のheadメンバーをftheMain$d3()関数の実行結果で上書きしているでゲソ。
結局eval()関数を通したことで、g930757141は未評価サンクから評価済みサンクに変化したんでゲソ。
このeval()関数、場合によってはさらにその子供のサンクを評価するために一度実行に入ると長い時間滞留する可能性があるでゲソ。
jhcのコンパイル結果にeval()を使っている箇所があったら注意して確認する必要があるということになるでゲソ。

### 2. Func: b_main :: () -> ()
### 3. Func: fW@.fJhc.Inst.Show.showWord :: (bits32,I) -> (N)
### 4. Func: fJhc.Show.shows :: (I,I) -> (N)
### 5. Func: fR@.fJhc.Show.11_showl :: (I,N) -> (N)
### 6. Func: ftheMain$2 :: (I,I) -> (N)
### 7. Func: fR@.fJhc.Basics.++ :: (I,N) -> (N)
### 8. Func: ftheMain$3 :: () -> (N)
### 9. Func: fR@.fJhc.Basics.zipWith :: (I,I) -> (N)
### 10. Func: fW@.fR@.fJhc.List.387_f :: (bits32,I) -> (N)
### 11. Func: ftheMain :: () -> ()

xxxxxxxx

## ソースコード分析 (実装からの理解)

うん。なんとなくGrin=>Cがどんな変換なのかイメージがつかめたでゲソ。
そろそろ例による理解ではなく、jhcのソースコードそのものを理解することもできるんじゃなイカ？
読んでみるでゲッソ!

xxxxxxxx
