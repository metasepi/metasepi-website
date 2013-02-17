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

~~~ {.haskell}
-- Grin --
-- Functions
b_main :: () -> ()
b_main  = do
  ftheMain
~~~

~~~ {.c}
/* C言語 */
void
_amain(void)
{
        return (void)b__main(saved_gc);
}

static void A_STD
b__main(gc_t gc)
{
        return ftheMain(gc);
}
~~~

うむ。これはなんかそのままでゲソ。
あえて違うところを挙げるとするならsaved_gcを引数で取り回すということでゲソ。
saved_gcはjgcの機能なので、別のGCを選択した場合には当然この出力も変化するはずでゲソ。

### 3. Func: fW@.fJhc.Inst.Show.showWord :: (bits32,I) -> (N)

~~~ {.haskell}
-- Grin --
fW@.fJhc.Inst.Show.showWord :: (bits32,I) -> (N)
fW@.fJhc.Inst.Show.showWord w1540496947 ni1826240557 = do
  let
      fW@.fR@.fJhc.Inst.Show.showWord w80100072 ni196335308 = do
        w40405746 <- w80100072 / 10
        w253468956 <- w80100072 % 10
        bm124940226 <- (bits<max>)ConvOp Zx bits32 w253468956
        w132127022 <- (bits32)ConvOp Lobits bits<max> bm124940226
        w26031830 <- 48 + w132127022
        w260152044 <- (bits32)ConvOp B2B bits32 w26031830
        withRoots(ni196335308)
          nd122 <- dstore (CJhc.Type.Basic.Char w260152044)
          ni55102202 <- demote nd122
          case w40405746 of
            0 -> withRoots(ni55102202)
              dstore (CJhc.Prim.Prim.: ni55102202 ni196335308)
            w0 -> withRoots(ni55102202)
              nd15 <- dstore (CJhc.Prim.Prim.: ni55102202 ni196335308)
              ni1829124143 <- demote nd15
              fW@.fR@.fJhc.Inst.Show.showWord w40405746 ni1829124143
   in
    fW@.fR@.fJhc.Inst.Show.showWord w1540496947 ni1826240557
~~~

~~~ {.c}
/* C言語 */
static wptr_t A_STD A_MALLOC
fW$__fJhc_Inst_Show_showWord(gc_t gc,uint32_t v1540496947,sptr_t v1826240557)
{
        sptr_t v196335308;
        uint32_t v80100072;
        // let fW@.fR@.fJhc.Inst.Show.showWord w80100072 ni196335308 = do
        // fW@.fR@.fJhc.Inst.Show.showWord w1540496947 ni1826240557
        v80100072 = v1540496947;
        v196335308 = v1826240557;
        fW$__fR$__fJhc_Inst_Show_showWord__2:;
        {   uint32_t v40405746 = (v80100072 / 10); // w40405746 <- w80100072 / 10
            uint32_t v253468956 = (v80100072 % 10); // w253468956 <- w80100072 % 10
            uintmax_t v124940226 = ((uintmax_t)v253468956); // bm124940226 <- (bits<max>)ConvOp Zx bits32 w253468956
            uint32_t v132127022 = ((uint32_t)v124940226); // w132127022 <- (bits32)ConvOp Lobits bits<max> bm124940226
            uint32_t v26031830 = (48 + v132127022); // w26031830 <- 48 + w132127022
            uint32_t v260152044 = v26031830; // w260152044 <- (bits32)ConvOp B2B bits32 w26031830
            {   gc_frame0(gc,1,v196335308);
                wptr_t v122 = RAW_SET_UF(v260152044); // nd122 <- dstore (CJhc.Type.Basic.Char w260152044)
                sptr_t v55102202 = demote(v122); // ni55102202 <- demote nd122
                if (0 == v40405746) { // case w40405746 of 0 ->
                    {   gc_frame0(gc,1,v55102202);
                        wptr_t x3 = s_alloc(gc,cCJhc_Prim_Prim_$x3a); // dstore (CJhc.Prim.Prim.: ni55102202 ni196335308)
                        ((struct sCJhc_Prim_Prim_$x3a*)x3)->a1 = v55102202;
                        ((struct sCJhc_Prim_Prim_$x3a*)x3)->a2 = v196335308;
                        return x3;
                    }
                } else { // w0 ->
                    {   gc_frame0(gc,1,v55102202);
                        wptr_t x4 = s_alloc(gc,cCJhc_Prim_Prim_$x3a); // nd15 <- dstore (CJhc.Prim.Prim.: ni55102202 ni196335308)
                        ((struct sCJhc_Prim_Prim_$x3a*)x4)->a1 = v55102202;
                        ((struct sCJhc_Prim_Prim_$x3a*)x4)->a2 = v196335308;
                        wptr_t v15 = x4;
                        sptr_t v1829124143 = demote(v15); // ni1829124143 <- demote nd15
                        v80100072 = v40405746; // fW@.fR@.fJhc.Inst.Show.showWord w40405746 ni1829124143
                        v196335308 = v1829124143;
                        goto fW$__fR$__fJhc_Inst_Show_showWord__2;
                    }
                }
            }
        }
}
~~~

C言語側にGrinコード断片をコメントで入れてみたでゲソ。
だいたい1対1に対応が取れているじゃなイカ。
ここではGrinとC言語の違いに着目して、そのしくみを詳しく見てみるでゲソ。

まず第一にdstore (CJhc.Type.Basic.Char,x)がRAW_SET_UF(x)になることがあるでゲソ。
このRAW_SET_UF()はイカのような定義で、即値のWHNFに変換してくれるでゲソ。
CJhc.Type.Basic.Charは即値なので、RAW_SET_UF()を使ってスマートポインタに埋め込まれるんじゃなイカ。

~~~ {.c}
#define RAW_SET_UF(n)  ((wptr_t)(((uintptr_t)(n) << 2) | P_VALUE))
~~~

ところがdstore (CJhc.Prim.Prim.: x y)
のような場合にはイカのようにs_alloc()でヒープへのスマートポインタを作って、
格納するでゲソ。
これはHaskellの(:)演算子を思いうかべればすぐわかるでゲソ。
(:)演算子は2つの要素をconsし、
そのconsした結果がstruct sCJhc_Prim_Prim_$x3aなんでゲソ。
つまりconsする旅にヒープの領域を消費するということでゲソ。

~~~ {.c}
struct sCJhc_Prim_Prim_$x3a {
    sptr_t a1;
    sptr_t a2;
};

wptr_t x4 = s_alloc(gc,cCJhc_Prim_Prim_$x3a);
((struct sCJhc_Prim_Prim_$x3a*)x4)->a1 = x;
((struct sCJhc_Prim_Prim_$x3a*)x4)->a2 = y;
~~~

最後にfW@.fR@.fJhc.Inst.Show.showWord関数の再帰がgotoループになっているでゲソ。
たまたまこの関数の例はすぐにループ化できる再帰だから良かったでゲソ。
しかし、原理的に全ての再帰がループ化されるのカ？少し不安でゲソ...

### 4. Func: fJhc.Show.shows :: (I,I) -> (N)

~~~ {.haskell}
-- Grin --
fJhc.Show.shows :: (I,I) -> (N)
fJhc.Show.shows ni29375120 ni44000678 = do
  withRoots(ni44000678)
    nd100038 <- eval ni29375120
    (CJhc.Type.Word.Int w216085094) <- return nd100038
    h100040 <- 0 `Gt` w216085094
    case h100040 of
      1 -> do
        w196289068 <- (bits32)Neg w216085094
        bm253468954 <- (bits<max>)ConvOp Sx bits32 w196289068
        w124235152 <- (bits32)ConvOp Lobits bits<max> bm253468954
        ni244126258 <- istore (FW@.fJhc.Inst.Show.showWord w124235152 ni44000678)
        withRoots(ni244126258)
          dstore (CJhc.Prim.Prim.: &(CJhc.Type.Basic.Char 45) ni244126258)
      0 -> do
        bm220263214 <- (bits<max>)ConvOp Sx bits32 w216085094
        w110207578 <- (bits32)ConvOp Lobits bits<max> bm220263214
        fW@.fJhc.Inst.Show.showWord w110207578 ni44000678
~~~

~~~ {.c}
/* C言語 */
static wptr_t A_STD A_MALLOC
fJhc_Show_shows(gc_t gc,sptr_t v29375120,sptr_t v44000678)
{
        {   uint32_t v216085094;
            gc_frame0(gc,1,v44000678); // withRoots(ni44000678)
            wptr_t v100038 = eval(gc,v29375120); // nd100038 <- eval ni29375120
            v216085094 = ((struct sCJhc_Type_Word_Int*)v100038)->a1; // (CJhc.Type.Word.Int w216085094) <- return nd100038
            uint16_t v100040 = (((int32_t)0) > ((int32_t)v216085094)); // h100040 <- 0 `Gt` w216085094
            if (0 == v100040) { // case h100040 of 0 -> do
                uintmax_t v220263214 = ((intmax_t)((int32_t)v216085094)); // bm220263214 <- (bits<max>)ConvOp Sx bits32 w216085094
                uint32_t v110207578 = ((uint32_t)v220263214); // w110207578 <- (bits32)ConvOp Lobits bits<max> bm220263214
                return fW$__fJhc_Inst_Show_showWord(gc,v110207578,v44000678); // fW@.fJhc.Inst.Show.showWord w110207578 ni44000678
            } else { // 1 -> do
                /* 1 */
                assert(1 == v100040);
                uint32_t v196289068 = (-((int32_t)v216085094)); // w196289068 <- (bits32)Neg w216085094
                uintmax_t v253468954 = ((intmax_t)((int32_t)v196289068)); // bm253468954 <- (bits<max>)ConvOp Sx bits32 w196289068
                uint32_t v124235152 = ((uint32_t)v253468954); // w124235152 <- (bits32)ConvOp Lobits bits<max> bm253468954
                sptr_t x5 = s_alloc(gc,cFW$__fJhc_Inst_Show_showWord); // ni244126258 <- istore (FW@.fJhc.Inst.Show.showWord w124235152 ni44000678)
                ((struct sFW$__fJhc_Inst_Show_showWord*)x5)->head = TO_FPTR(&E__fW$__fJhc_Inst_Show_showWord);
                ((struct sFW$__fJhc_Inst_Show_showWord*)x5)->a1 = v124235152;
                ((struct sFW$__fJhc_Inst_Show_showWord*)x5)->a2 = v44000678;
                sptr_t v244126258 = MKLAZY(x5);
                {   gc_frame0(gc,1,v244126258); // withRoots(ni244126258)
                    wptr_t x6 = s_alloc(gc,cCJhc_Prim_Prim_$x3a); // dstore (CJhc.Prim.Prim.: &(CJhc.Type.Basic.Char 45) ni244126258)
                    ((struct sCJhc_Prim_Prim_$x3a*)x6)->a1 = ((sptr_t)RAW_SET_UF('-'));
                    ((struct sCJhc_Prim_Prim_$x3a*)x6)->a2 = v244126258;
                    return x6;
                }
            }
        }
}
~~~

これもほぼ1対1に対応しているでゲソが、唯一の例外が
istore (FW@.fJhc.Inst.Show.showWord x y)
がs_alloc()によるヒープの確保に化けることでゲソ。

~~~ {.c}
struct sFW$__fJhc_Inst_Show_showWord {
    fptr_t head;
    sptr_t a2;
    uint32_t a1;
};

sptr_t x5 = s_alloc(gc,cFW$__fJhc_Inst_Show_showWord);
((struct sFW$__fJhc_Inst_Show_showWord*)x5)->head = TO_FPTR(&E__fW$__fJhc_Inst_Show_showWord);
((struct sFW$__fJhc_Inst_Show_showWord*)x5)->a1 = x;
((struct sFW$__fJhc_Inst_Show_showWord*)x5)->a2 = y;
sptr_t v244126258 = MKLAZY(x5);
~~~

この謎はjhcのjhcライブラリのソース見れば理解できるでゲソ。
showWord関数はイカのように通常のLazyな関数じゃなイカ。
ということはここでは未評価サンクだけ作り後で誰かがforceしてくれるのを待てばいいんでゲソ。
ここで作成する未評価サンクの実体がstruct sFW$__fJhc_Inst_Show_showWordで、
やはりヒープに確保されるでゲソ。

~~~ {.haskell}
-- jhc/lib/jhc/Jhc/Inst/Show.hs
showWord :: Word -> String -> String
showWord w rest = w `seq` case quotRem w 10 of
    (n',d) -> n' `seq` d `seq` rest' `seq` if n' == 0 then rest' else showWord n' rest'
        where rest' = chr (fromIntegral d + ord '0') : rest
~~~

### 5. Func: fR@.fJhc.Show.11_showl :: (I,N) -> (N)

~~~ {.haskell}
-- Grin --
fR@.fJhc.Show.11_showl :: (I,N) -> (N)
fR@.fJhc.Show.11_showl ni108431528 nd267777212 = do
  ni267777293 <- demote nd267777212
  withRoots(nd267777212,ni267777293)
    nd100036 <- eval ni108431528
    (ni126,ni95) <- case nd100036 of
      (CJhc.Prim.Prim.: ni26 ni67) -> withRoots(ni26,ni67)
        ni110947984 <- istore (FR@.fJhc.Show.11_showl ni67 nd267777212)
        withRoots(ni110947984)
          ni215884490 <- istore (FJhc.Show.shows ni26 ni110947984)
          return (&(CJhc.Type.Basic.Char 44),ni215884490)
      [] -> return (&(CJhc.Type.Basic.Char 93),ni267777293)
    withRoots(ni95,ni126)
      dstore (CJhc.Prim.Prim.: ni126 ni95)
~~~

~~~ {.c}
/* C言語 */
static wptr_t A_STD A_MALLOC
fR$__fJhc_Show_11__showl(gc_t gc,sptr_t v108431528,wptr_t v267777212)
{
        sptr_t v267777293 = demote(v267777212); // ni267777293 <- demote nd267777212
        {   sptr_t v126;
            sptr_t v95;
            struct tup1 x7;
            gc_frame0(gc,2,v267777212,v267777293); // withRoots(nd267777212,ni267777293)
            wptr_t v100036 = eval(gc,v108431528); // nd100036 <- eval ni108431528
            if (SET_RAW_TAG(CJhc_Prim_Prim_$BE) == v100036) { // case nd100036 of [] ->
                x7.t0 = ((sptr_t)RAW_SET_UF(']')); // return (&(CJhc.Type.Basic.Char 93),ni267777293)
                x7.t1 = v267777293;
            } else { // (CJhc.Prim.Prim.: ni26 ni67) ->
                sptr_t v26;
                sptr_t v67;
                /* ("CJhc.Prim.Prim.:" ni26 ni67) パターンマッチ */
                v26 = ((struct sCJhc_Prim_Prim_$x3a*)v100036)->a1;
                v67 = ((struct sCJhc_Prim_Prim_$x3a*)v100036)->a2;
                {   gc_frame0(gc,2,v26,v67); // withRoots(ni26,ni67)
                    sptr_t x8 = s_alloc(gc,cFR$__fJhc_Show_11__showl); // ni110947984 <- istore (FR@.fJhc.Show.11_showl ni67 nd267777212)
                    ((struct sFR$__fJhc_Show_11__showl*)x8)->head = TO_FPTR(&E__fR$__fJhc_Show_11__showl);
                    ((struct sFR$__fJhc_Show_11__showl*)x8)->a1 = v67;
                    ((struct sFR$__fJhc_Show_11__showl*)x8)->a2 = v267777212;
                    sptr_t v110947984 = MKLAZY(x8);
                    {   gc_frame0(gc,1,v110947984); // withRoots(ni110947984)
                        sptr_t x9 = s_alloc(gc,cFJhc_Show_shows); // ni215884490 <- istore (FJhc.Show.shows ni26 ni110947984)
                        ((struct sFJhc_Show_shows*)x9)->head = TO_FPTR(&E__fJhc_Show_shows);
                        ((struct sFJhc_Show_shows*)x9)->a1 = v26;
                        ((struct sFJhc_Show_shows*)x9)->a2 = v110947984;
                        sptr_t v215884490 = MKLAZY(x9);
                        x7.t0 = ((sptr_t)RAW_SET_UF(',')); // return (&(CJhc.Type.Basic.Char 44),ni215884490)
                        x7.t1 = v215884490;
                    }
                }
            }
            v126 = x7.t0; // (ni126,ni95) <-
            v95 = x7.t1;
            {   gc_frame0(gc,2,v95,v126); // withRoots(ni95,ni126)
                wptr_t x10 = s_alloc(gc,cCJhc_Prim_Prim_$x3a); // dstore (CJhc.Prim.Prim.: ni126 ni95)
                ((struct sCJhc_Prim_Prim_$x3a*)x10)->a1 = v126;
                ((struct sCJhc_Prim_Prim_$x3a*)x10)->a2 = v95;
                return x10;
            }
        }
}
~~~

ここまで来るとほぼこれまで仕入れた知識で読めるでゲソ!
新しく出てきた表現をあえて挙げるならタプルでゲソ。

~~~ {.c}
struct tup1 {
    sptr_t t0;
    sptr_t t1;
};
~~~

これはもう見たままでゲソ。タプルじゃなイカ。
ところでなんでいきなりタプルを使うことになったんでゲソ？

この関数はjhcライブラリのshowList関数の中にあるshowlローカル関数に由来しているでゲソ。
どうもShowS型の合成を (文字,サンク) というタプルでの表現に変換しているようじゃなイカ。
コンパイルパイプラインの最適化のどこでこの変換が行なわれるのか興味が出てきたでゲソ。

~~~ {.haskell}
-- jhc/lib/jhc/Jhc/Show.hs
type  ShowS    = String -> String

class  Show a  where
-- snip --
    showList         :: [a] -> ShowS
-- snip --
    showList []       = showString "[]"
    showList (x:xs)   = showChar '[' . shows x . showl xs
                        where showl []     = showChar ']'
                              showl (x:xs) = showChar ',' . shows x .
                                             showl xs
~~~

### 6. Func: ftheMain$2 :: (I,I) -> (N)

~~~ {.haskell}
-- Grin --
ftheMain$2 :: (I,I) -> (N)
ftheMain$2 ni38 ni42 = do
  withRoots(ni42)
    nd100032 <- eval ni38
    withRoots(nd100032)
      nd100092 <- eval ni42
      (CJhc.Type.Word.Int w239029634) <- return nd100032
      (CJhc.Type.Word.Int w242159974) <- return nd100092
      w215350916 <- w239029634 + w242159974
      dstore (CJhc.Type.Word.Int w215350916)
~~~

~~~ {.c}
/* C言語 */
static wptr_t A_STD A_MALLOC
ftheMain$d2(gc_t gc,sptr_t v38,sptr_t v42)
{
        {   gc_frame0(gc,1,v42);
            wptr_t v100032 = eval(gc,v38);
            {   uint32_t v239029634;
                uint32_t v242159974;
                gc_frame0(gc,1,v100032);
                wptr_t v100092 = eval(gc,v42);
                v239029634 = ((struct sCJhc_Type_Word_Int*)v100032)->a1;
                v242159974 = ((struct sCJhc_Type_Word_Int*)v100092)->a1;
                uint32_t v215350916 = (v239029634 + v242159974);
                wptr_t x11 = s_alloc(gc,cCJhc_Type_Word_Int);
                ((struct sCJhc_Type_Word_Int*)x11)->a1 = v215350916;
                return x11;
            }
        }
}
~~~

### 7. Func: fR@.fJhc.Basics.++ :: (I,N) -> (N)

~~~ {.haskell}
-- Grin --
fR@.fJhc.Basics.++ :: (I,N) -> (N)
fR@.fJhc.Basics.++ ni29534742 nd29534740 = do
  withRoots(nd29534740)
    nd100000 <- eval ni29534742
    case nd100000 of
      (CJhc.Prim.Prim.: ni106 ni108) -> withRoots(ni106,ni108)
        ni69834446 <- istore (FR@.fJhc.Basics.++ ni108 nd29534740)
        withRoots(ni69834446)
          dstore (CJhc.Prim.Prim.: ni106 ni69834446)
      [] -> return nd29534740
~~~

~~~ {.c}
/* C言語 */
static wptr_t A_STD A_MALLOC
fR$__fJhc_Basics_$pp(gc_t gc,sptr_t v29534742,wptr_t v29534740)
{
        {   gc_frame0(gc,1,v29534740);
            wptr_t v100000 = eval(gc,v29534742);
            if (SET_RAW_TAG(CJhc_Prim_Prim_$BE) == v100000) {
                return v29534740;
            } else {
                sptr_t v106;
                sptr_t v108;
                /* ("CJhc.Prim.Prim.:" ni106 ni108) */
                v106 = ((struct sCJhc_Prim_Prim_$x3a*)v100000)->a1;
                v108 = ((struct sCJhc_Prim_Prim_$x3a*)v100000)->a2;
                {   gc_frame0(gc,2,v106,v108);
                    sptr_t x12 = s_alloc(gc,cFR$__fJhc_Basics_$pp);
                    ((struct sFR$__fJhc_Basics_$pp*)x12)->head = TO_FPTR(&E__fR$__fJhc_Basics_$pp);
                    ((struct sFR$__fJhc_Basics_$pp*)x12)->a1 = v108;
                    ((struct sFR$__fJhc_Basics_$pp*)x12)->a2 = v29534740;
                    sptr_t v69834446 = MKLAZY(x12);
                    {   gc_frame0(gc,1,v69834446);
                        wptr_t x13 = s_alloc(gc,cCJhc_Prim_Prim_$x3a);
                        ((struct sCJhc_Prim_Prim_$x3a*)x13)->a1 = v106;
                        ((struct sCJhc_Prim_Prim_$x3a*)x13)->a2 = v69834446;
                        return x13;
                    }
                }
            }
        }
}
~~~

### 8. Func: ftheMain$3 :: () -> (N)

~~~ {.haskell}
-- Grin --
ftheMain$3 :: () -> (N)
ftheMain$3  = do
  fR@.fJhc.Basics.++ &"[]" []
~~~

~~~ {.c}
/* C言語 */
static wptr_t A_STD A_MALLOC
ftheMain$d3(gc_t gc)
{
        return fR$__fJhc_Basics_$pp(gc,c2,SET_RAW_TAG(CJhc_Prim_Prim_$BE));
}
~~~

### 9. Func: fR@.fJhc.Basics.zipWith :: (I,I) -> (N)

~~~ {.haskell}
-- Grin --
fR@.fJhc.Basics.zipWith :: (I,I) -> (N)
fR@.fJhc.Basics.zipWith ni182639120 ni132127014 = do
  withRoots(ni132127014)
    nd100028 <- eval ni182639120
    case nd100028 of
      (CJhc.Prim.Prim.: ni40405740 ni40) -> withRoots(ni40,ni40405740)
        nd100030 <- eval ni132127014
        case nd100030 of
          (CJhc.Prim.Prim.: ni194635132 ni116) -> withRoots(ni116,ni194635132)
            ni248061794 <- istore (FR@.fJhc.Basics.zipWith ni40 ni116)
            withRoots(ni248061794)
              ni229109160 <- istore (FtheMain$2 ni40405740 ni194635132)
              withRoots(ni229109160)
                dstore (CJhc.Prim.Prim.: ni229109160 ni248061794)
          [] -> return []
      [] -> return []
~~~

~~~ {.c}
/* C言語 */
static wptr_t A_STD A_MALLOC
fR$__fJhc_Basics_zipWith(gc_t gc,sptr_t v182639120,sptr_t v132127014)
{
        {   gc_frame0(gc,1,v132127014);
            wptr_t v100028 = eval(gc,v182639120);
            if (SET_RAW_TAG(CJhc_Prim_Prim_$BE) == v100028) {
                return v100028;
            } else {
                sptr_t v40;
                sptr_t v40405740;
                /* ("CJhc.Prim.Prim.:" ni40405740 ni40) */
                v40405740 = ((struct sCJhc_Prim_Prim_$x3a*)v100028)->a1;
                v40 = ((struct sCJhc_Prim_Prim_$x3a*)v100028)->a2;
                {   gc_frame0(gc,2,v40,v40405740);
                    wptr_t v100030 = eval(gc,v132127014);
                    if (SET_RAW_TAG(CJhc_Prim_Prim_$BE) == v100030) {
                        return v100030;
                    } else {
                        sptr_t v116;
                        sptr_t v194635132;
                        /* ("CJhc.Prim.Prim.:" ni194635132 ni116) */
                        v194635132 = ((struct sCJhc_Prim_Prim_$x3a*)v100030)->a1;
                        v116 = ((struct sCJhc_Prim_Prim_$x3a*)v100030)->a2;
                        {   gc_frame0(gc,2,v116,v194635132);
                            sptr_t x14 = s_alloc(gc,cFR$__fJhc_Basics_zipWith);
                            ((struct sFR$__fJhc_Basics_zipWith*)x14)->head = TO_FPTR(&E__fR$__fJhc_Basics_zipWith);
                            ((struct sFR$__fJhc_Basics_zipWith*)x14)->a1 = v40;
                            ((struct sFR$__fJhc_Basics_zipWith*)x14)->a2 = v116;
                            sptr_t v248061794 = MKLAZY(x14);
                            {   gc_frame0(gc,1,v248061794);
                                sptr_t x15 = s_alloc(gc,cFtheMain$d2);
                                ((struct sFtheMain$d2*)x15)->head = TO_FPTR(&E__ftheMain$d2);
                                ((struct sFtheMain$d2*)x15)->a1 = v40405740;
                                ((struct sFtheMain$d2*)x15)->a2 = v194635132;
                                sptr_t v229109160 = MKLAZY(x15);
                                {   gc_frame0(gc,1,v229109160);
                                    wptr_t x16 = s_alloc(gc,cCJhc_Prim_Prim_$x3a);
                                    ((struct sCJhc_Prim_Prim_$x3a*)x16)->a1 = v229109160;
                                    ((struct sCJhc_Prim_Prim_$x3a*)x16)->a2 = v248061794;
                                    return x16;
                                }
                            }
                        }
                    }
                }
            }
        }
}
~~~

### 10. Func: fW@.fR@.fJhc.List.387_f :: (bits32,I) -> (N)

~~~ {.haskell}
-- Grin --
fW@.fR@.fJhc.List.387_f :: (bits32,I) -> (N)
fW@.fR@.fJhc.List.387_f w115160438 ni124940224 = do
  h100024 <- 0 `Gte` w115160438
  case h100024 of
    1 -> return []
    0 -> do
      nd100026 <- eval ni124940224
      case nd100026 of
        (CJhc.Prim.Prim.: ni304 ni306) -> do
          w194508206 <- w115160438 - 1
          withRoots(ni304,ni306)
            ni131889104 <- istore (FW@.fR@.fJhc.List.387_f w194508206 ni306)
            withRoots(ni131889104)
              dstore (CJhc.Prim.Prim.: ni304 ni131889104)
        [] -> return []
~~~

~~~ {.c}
/* C言語 */
static wptr_t A_STD A_MALLOC
fW$__fR$__fJhc_List_387__f(gc_t gc,uint32_t v115160438,sptr_t v124940224)
{
        uint16_t v100024 = (((int32_t)0) >= ((int32_t)v115160438));
        if (0 == v100024) {
            wptr_t v100026 = eval(gc,v124940224);
            if (SET_RAW_TAG(CJhc_Prim_Prim_$BE) == v100026) {
                return v100026;
            } else {
                sptr_t v304;
                sptr_t v306;
                /* ("CJhc.Prim.Prim.:" ni304 ni306) */
                v304 = ((struct sCJhc_Prim_Prim_$x3a*)v100026)->a1;
                v306 = ((struct sCJhc_Prim_Prim_$x3a*)v100026)->a2;
                uint32_t v194508206 = (v115160438 - 1);
                {   gc_frame0(gc,2,v304,v306);
                    sptr_t x17 = s_alloc(gc,cFW$__fR$__fJhc_List_387__f);
                    ((struct sFW$__fR$__fJhc_List_387__f*)x17)->head = TO_FPTR(&E__fW$__fR$__fJhc_List_387__f);
                    ((struct sFW$__fR$__fJhc_List_387__f*)x17)->a1 = v194508206;
                    ((struct sFW$__fR$__fJhc_List_387__f*)x17)->a2 = v306;
                    sptr_t v131889104 = MKLAZY(x17);
                    {   gc_frame0(gc,1,v131889104);
                        wptr_t x18 = s_alloc(gc,cCJhc_Prim_Prim_$x3a);
                        ((struct sCJhc_Prim_Prim_$x3a*)x18)->a1 = v304;
                        ((struct sCJhc_Prim_Prim_$x3a*)x18)->a2 = v131889104;
                        return x18;
                    }
                }
            }
        } else {
            /* 1 */
            assert(1 == v100024);
            return SET_RAW_TAG(CJhc_Prim_Prim_$BE);
        }
}
~~~

### 11. Func: ftheMain :: () -> ()

~~~ {.haskell}
-- Grin --
ftheMain :: () -> ()
ftheMain  = do
  nd163 <- dstore (CJhc.Prim.Prim.: ?::I ?::I)
  ni856819231 <- demote nd163
  withRoots(ni856819231)
    nd168 <- dstore (CJhc.Prim.Prim.: ?::I ?::I)
    ni220263216 <- demote nd168
    overwrite ni856819231 (CJhc.Prim.Prim.: &(CJhc.Type.Word.Int 1) ni220263216)
    withRoots(ni220263216)
      ni144627460 <- istore (FR@.fJhc.Basics.zipWith ?::I ?::I)
      overwrite ni144627460 (FR@.fJhc.Basics.zipWith ni856819231 ni220263216)
      overwrite ni220263216 (CJhc.Prim.Prim.: &(CJhc.Type.Word.Int 1) ni144627460)
      nd100014 <- fW@.fR@.fJhc.List.387_f 40 ni856819231
      ni78 <- case nd100014 of
        (CJhc.Prim.Prim.: ni129 ni32) -> withRoots(ni32,ni129)
          ni194635134 <- istore (FR@.fJhc.Show.11_showl ni32 [])
          withRoots(ni194635134)
            ni196335306 <- istore (FJhc.Show.shows ni129 ni194635134)
            withRoots(ni196335306)
              nd84 <- dstore (CJhc.Prim.Prim.: &(CJhc.Type.Basic.Char 91) ni196335306)
              demote nd84
        [] -> return ni-930757141
      nd100016 <- eval ni78
      ni81465164 <- demote nd100016
      nd0 <- let
          fJhc.Monad.72_go ni10 = do
            nd100020 <- eval ni10
            case nd100020 of
              (CJhc.Prim.Prim.: ni12 ni260952206) -> withRoots(ni260952206)
                nd100022 <- eval ni12
                (CJhc.Type.Basic.Char w216085086) <- return nd100022
                w249143450 <- (bits32)ConvOp B2B bits32 w216085086
                (void)jhc_utf8_putchar(int) w249143450
                fJhc.Monad.72_go ni260952206
              [] -> return (CJhc.Prim.Prim.())
       in
        fJhc.Monad.72_go ni81465164
      (void)jhc_utf8_putchar(int) 10
~~~

~~~ {.c}
/* C言語 */
static void A_STD
ftheMain(gc_t gc)
{
        wptr_t x19 = s_alloc(gc,cCJhc_Prim_Prim_$x3a);
        wptr_t v163 = x19;
        sptr_t v856819231 = demote(v163);
        {   gc_frame0(gc,1,v856819231);
            wptr_t x20 = s_alloc(gc,cCJhc_Prim_Prim_$x3a);
            wptr_t v168 = x20;
            sptr_t v220263216 = demote(v168);
            ((struct sCJhc_Prim_Prim_$x3a*)FROM_SPTR(v856819231))->a1 = c3;
            ((struct sCJhc_Prim_Prim_$x3a*)FROM_SPTR(v856819231))->a2 = v220263216;
            {   sptr_t v10;
                wptr_t v100014;
                sptr_t v78;
                gc_frame0(gc,1,v220263216);
                sptr_t x21 = s_alloc(gc,cFR$__fJhc_Basics_zipWith);
                ((struct sFR$__fJhc_Basics_zipWith*)x21)->head = TO_FPTR(&E__fR$__fJhc_Basics_zipWith);
                sptr_t v144627460 = MKLAZY(x21);
                ((struct sFR$__fJhc_Basics_zipWith*)FROM_SPTR(v144627460))->head = TO_FPTR(&E__fR$__fJhc_Basics_zipWith);
                ((struct sFR$__fJhc_Basics_zipWith*)FROM_SPTR(v144627460))->a1 = v856819231;
                ((struct sFR$__fJhc_Basics_zipWith*)FROM_SPTR(v144627460))->a2 = v220263216;
                ((struct sCJhc_Prim_Prim_$x3a*)FROM_SPTR(v220263216))->a1 = c3;
                ((struct sCJhc_Prim_Prim_$x3a*)FROM_SPTR(v220263216))->a2 = v144627460;
                v100014 = fW$__fR$__fJhc_List_387__f(gc,40,v856819231);
                if (SET_RAW_TAG(CJhc_Prim_Prim_$BE) == v100014) {
                    v78 = g930757141;
                } else {
                    sptr_t v129;
                    sptr_t v32;
                    /* ("CJhc.Prim.Prim.:" ni129 ni32) */
                    v129 = ((struct sCJhc_Prim_Prim_$x3a*)v100014)->a1;
                    v32 = ((struct sCJhc_Prim_Prim_$x3a*)v100014)->a2;
                    {   gc_frame0(gc,2,v32,v129);
                        sptr_t x22 = s_alloc(gc,cFR$__fJhc_Show_11__showl);
                        ((struct sFR$__fJhc_Show_11__showl*)x22)->head = TO_FPTR(&E__fR$__fJhc_Show_11__showl);
                        ((struct sFR$__fJhc_Show_11__showl*)x22)->a1 = v32;
                        ((struct sFR$__fJhc_Show_11__showl*)x22)->a2 = SET_RAW_TAG(CJhc_Prim_Prim_$BE);
                        sptr_t v194635134 = MKLAZY(x22);
                        {   gc_frame0(gc,1,v194635134);
                            sptr_t x23 = s_alloc(gc,cFJhc_Show_shows);
                            ((struct sFJhc_Show_shows*)x23)->head = TO_FPTR(&E__fJhc_Show_shows);
                            ((struct sFJhc_Show_shows*)x23)->a1 = v129;
                            ((struct sFJhc_Show_shows*)x23)->a2 = v194635134;
                            sptr_t v196335306 = MKLAZY(x23);
                            {   gc_frame0(gc,1,v196335306);
                                wptr_t x24 = s_alloc(gc,cCJhc_Prim_Prim_$x3a);
                                ((struct sCJhc_Prim_Prim_$x3a*)x24)->a1 = ((sptr_t)RAW_SET_UF('['));
                                ((struct sCJhc_Prim_Prim_$x3a*)x24)->a2 = v196335306;
                                wptr_t v84 = x24;
                                v78 = demote(v84);
                            }
                        }
                    }
                }
                wptr_t v100016 = eval(gc,v78);
                sptr_t v81465164 = demote(v100016);
                v10 = v81465164;
                fJhc_Monad_72__go__25:;
                {   wptr_t v100020 = eval(gc,v10);
                    if (SET_RAW_TAG(CJhc_Prim_Prim_$BE) == v100020) {
                        SET_RAW_TAG(CJhc_Prim_Prim_$LR);
                    } else {
                        sptr_t v12;
                        sptr_t v260952206;
                        /* ("CJhc.Prim.Prim.:" ni12 ni260952206) */
                        v12 = ((struct sCJhc_Prim_Prim_$x3a*)v100020)->a1;
                        v260952206 = ((struct sCJhc_Prim_Prim_$x3a*)v100020)->a2;
                        {   uint32_t v216085086;
                            gc_frame0(gc,1,v260952206);
                            wptr_t v100022 = eval(gc,v12);
                            v216085086 = ((uint32_t)RAW_GET_UF(v100022));
                            uint32_t v249143450 = v216085086;
                            saved_gc = gc;
                            (void)jhc_utf8_putchar((int)v249143450);
                            v10 = v260952206;
                            goto fJhc_Monad_72__go__25;
                        }
                    }
                }
                saved_gc = gc;
                return (void)jhc_utf8_putchar((int)10);
            }
        }
}
~~~

### Grin由来ではないC言語コード

xxxxxxxx

## ソースコード分析 (実装からの理解)

うん。なんとなくGrin=>Cがどんな変換なのかイメージがつかめたでゲソ。
そろそろ例による理解ではなく、jhcのソースコードそのものを理解することもできるんじゃなイカ？
読んでみるでゲッソ!

xxxxxxxx
