---
title: (作成中) Detail of the jgc garbage collector
description: 再入を実現する前によくGCを観察してみるでゲソ!
tags: jhc, jgc, gc, haskell
---

AjhcのデフォルトのGCはjgcでゲソ。
このjgcについての解説は
[@dec9ue](https://twitter.com/dec9ue)
氏のプレゼン資料が詳しかったでゲソ。

<iframe src="http://www.slideshare.net/slideshow/embed_code/16298437" width="427" height="356" frameborder="0" marginwidth="0" marginheight="0" scrolling="no" style="border:1px solid #CCC;border-width:1px 1px 0;margin-bottom:5px" allowfullscreen webkitallowfullscreen mozallowfullscreen> </iframe> <div style="margin-bottom:5px"> <strong> <a href="http://www.slideshare.net/dec9ue/gc-16298437" title="小二病でもGCやりたい" target="_blank">小二病でもGCやりたい</a> </strong> from <strong><a href="http://www.slideshare.net/dec9ue" target="_blank">dec9ue</a></strong> </div>

これからAjhcを使って以下を実現したいでゲソ。

* クリティカルリージョンの保護
* 割り込みコンテキストをHaskellで記述
* 並列実行
* GCの中断と再開

とすると、jgcに対してもう少し突っ込んだ理解を今しておいた方が良さそうでゲソ。

## GCのルート

gc_perform_gc関数の前半でヒープにマーキングしているはずなので、読めばわかるはずじゃなイカ。

~~~ {.c}
void A_STD
gc_perform_gc(gc_t gc)
{
        profile_push(&gc_gc_time);
        arena->number_gcs++;

        unsigned number_redirects = 0;
        unsigned number_stack = 0;
        unsigned number_ptr = 0;
        struct stack stack = EMPTY_STACK;

        clear_used_bits(arena);

        debugf("Setting Roots:");
        stack_check(&stack, root_stack.ptr);
        for(unsigned i = 0; i < root_stack.ptr; i++) {
                gc_add_grey(&stack, root_stack.stack[i]);
                debugf(" %p", root_stack.stack[i]);
        }
        debugf(" # ");
        struct StablePtr *sp;
        LIST_FOREACH(sp, &root_StablePtrs, link) {
            gc_add_grey(&stack, (entry_t *)sp);
            debugf(" %p", root_stack.stack[i]);
        }
~~~

gc_perform_gc関数が開始すると...

1. stack一時変数を初期化
2. arenaの中身のused_bitを一般0クリア
3. stack_check関数を呼び出してstack一時変数がroot_stack.ptr個分のエントリを格納できるか調べ
4. stack一時変数のサイズが足りなければstack_grow関数でreallocを呼び出し拡張
5. root_stack.stack配列の要素を一つずつgc_add_grey関数に食わせる
6. gc_add_grey関数はroot_stack.stack配列の要素がヒープ中かどうかチェックする。nh_stuff配列の中にある要素は静的確保されたもの
7. さらにgc_add_grey関数はroot_stack.stack配列の要素にused_bitが立ってないことを確認してから立てる
8. 6と7に成功したらstack->stack配列に当該root_stack.stack配列の要素を積む
9. BSDリストであるroot_StablePtrsを順番に辿る
10. 6と7と同様にしてgc_add_grey関数でチェックした後stack->stack配列にroot_StablePtrsの要素を積む

ということはroot_stackとroot_StablePtrsの2つがGCルートということになるでゲソ。

ところでちょっと気になるんでゲソが、
root_StablePtrsをgc_add_grey関数にかける前にstack_checkをもう一度呼び出してstack一時変数のサイズが足りてるかチェックした方がいいんじゃなイカ...
このままだとStablePtrの個数が多い場合にはふっとぶ気がするでゲソ。

### root_stackとは何か

これはふつーのプログラムでは使われないようでゲソ。
jhcのGrinがgc_add_root関数を使うコード吐き出すことがあるようでゲソ。

~~~ {.haskell}
-- File: ajhc/src/C/FromGrin2.hs
declareEvalFunc isCAF n = do
    fn <- tagToFunction n
    grin <- asks rGrin
    declareStruct n
    nt <- nodeType n
    let ts = runIdentity $ findArgs (grinTypeEnv grin) n
        fname = toName $ "E_" ++ show fn
        aname = name "arg"
        rvar = localVariable wptr_t (name "r")
        atype = ptrType nt
        body = rvar =* functionCall (toName (show $ fn)) (mgc [ project' (arg i) (variable aname) | _ <- ts | i <- [(1 :: Int) .. ] ])
        update =  f_update (variable aname) rvar
        addroot =  if isCAF && fopts FO.Jgc then f_gc_add_root (cast sptr_t rvar) else emptyExpression
        body' = if not isCAF && fopts FO.Jgc then subBlock (gc_roots [f_MKLAZY(variable aname)] & rest) else rest
        rest = body & update & addroot & creturn rvar
    tellFunctions [function fname wptr_t (mgct [(aname,atype)]) [a_STD, a_FALIGNED] body']
    return fname
~~~

ちょっとコードの意図が取りにくいでゲソが"E\_"ではじまる関数はサンクの評価関数であるはずなので、
スタティックサンクだとGCルートになるんじゃなイカ？
その時に"E\_"ではじまる評価関数の中にgc_add_root関数が埋め込まれるはずでゲソ。
...でもなんかそのケースは稀な気がするでゲソ。
grinの最適化の中でほとんどのスタティックサンクは使用元の関数の中に展開されてしまいそうでゲソ。
簡単な例を作ってみてもgc_add_root関数が埋め込まれたC言語コードをajhcは吐き出さないようでゲソ。
まぁここではこんなものがGCルートになる可能性があるよ、ということでいいんじゃなイカ？

### root_StablePtrsとは何か

[Foreign.StablePtr.newStablePtr(これはGHCのAPI)](http://www.haskell.org/ghc/docs/latest/html/libraries/base/Foreign-StablePtr.html#v:newStablePtr)
をHaskellコードから呼ぶとstruct StablePtrがstableptr.cでmalloc確保されて、
root_StablePtrsに繋がれるんでゲソ。
つまりStablePtrを保管する器ということじゃなイカ。リストより木構造の方が良い気もするでゲソ...

~~~ {.haskell}
-- | newStablePtr will seq its argument to get rid of nasty GC issues and be
-- compatible with FFI calling conventions, if this is an issue, you can put an
-- extra box around it.
newStablePtr :: a -> IO (StablePtr a)
newStablePtr x = do
    fromUIO $ \w -> case c_newStablePtr (toBang_ x) w of
        (# w', s #) -> (# w', fromBang_ s #)
~~~

~~~ {.c}
wptr_t c_newStablePtr(sptr_t c) {
    struct StablePtr* sp = malloc(sizeof(struct StablePtr));
    sp->contents = c;
    LIST_INSERT_HEAD(&root_StablePtrs, sp, link);
    assert(GET_PTYPE(sp) == 0);
    return (wptr_t)TO_SPTR(P_VALUE,(wptr_t)sp);
}
~~~

### 他にGCルートになるものは？

さすがに上の2つだけがGCルートのはずないでゲソ。根っこがスカスカじゃなイカ。
もう一つGCルートがあり、それはC言語のスタックでゲソ。
gc_perform_gc関数の続きを読むと...

~~~ {.c}
        stack_check(&stack, gc - gc_stack_base);
        number_stack = gc - gc_stack_base;
        for(unsigned i = 0; i < number_stack; i++) {
                debugf(" |");
                // TODO - short circuit redirects on stack
                sptr_t ptr = gc_stack_base[i];
                if(1 && (IS_LAZY(ptr))) {
                        assert(GET_PTYPE(ptr) == P_LAZY);
                        VALGRIND_MAKE_MEM_DEFINED(FROM_SPTR(ptr), sizeof(uintptr_t));
                        if(!IS_LAZY(GETHEAD(FROM_SPTR(ptr)))) {
                                void *gptr = TO_GCPTR(ptr);
                                if(gc_check_heap(gptr))
                                        s_set_used_bit(gptr);
                                number_redirects++;
                                debugf(" *");
                                ptr = (sptr_t)GETHEAD(FROM_SPTR(ptr));
                        }
                }
                if(__predict_false(!IS_PTR(ptr))) {
                        debugf(" -");
                        continue;
                }
                number_ptr++;
                entry_t *e = TO_GCPTR(ptr);
                debugf(" %p",(void *)e);
                gc_add_grey(&stack, e);
        }
~~~

このコードはgcからgc_stack_baseまでの領域の差す先を
entry_tポインタとしてgc_add_grey関数に食わせるでゲソ。
gcとgc_stack_baseはプログラム起動時には同じ場所を指しているでゲソ。

~~~ {.c}
void
jhc_alloc_init(void) {
        VALGRIND_PRINTF("Jhc-Valgrind mode active.\n");
#ifdef _JHC_JGC_FIXED_MEGABLOCK
        saved_gc = gc_stack_base = (void *) gc_stack_base_area;
#else
        saved_gc = gc_stack_base = malloc((1UL << 18)*sizeof(gc_stack_base[0]));
#endif
        arena = new_arena();
~~~

ところがミューテターの中にgc_frame0関数というのがよくあらわれるでゲソ。

~~~ {.c}
static wptr_t A_STD A_MALLOC
fR$__fJhc_Basics_$pp(gc_t gc,sptr_t v80776080,sptr_t v58800110)
{
        {   gc_frame0(gc,1,v58800110); // <= GCルートにv58800110を登録
            wptr_t v100444 = eval(gc,v80776080);
            if (SET_RAW_TAG(CJhc_Prim_Prim_$BE) == v100444) {
                return eval(gc,v58800110);
            } else {
                sptr_t v106;
                sptr_t v108;
                /* ("CJhc.Prim.Prim.:" ni106 ni108) */
                v106 = ((struct sCJhc_Prim_Prim_$x3a*)v100444)->a1;
                v108 = ((struct sCJhc_Prim_Prim_$x3a*)v100444)->a2;
                {   gc_frame0(gc,2,v106,v108); // <= GCルートにv106とv108を登録
                    sptr_t x7 = s_alloc(gc,cFR$__fJhc_Basics_$pp);
                    ((struct sFR$__fJhc_Basics_$pp*)x7)->head = TO_FPTR(&E__fR$__fJhc_Basics_$pp);
                    ((struct sFR$__fJhc_Basics_$pp*)x7)->a1 = v108;
                    ((struct sFR$__fJhc_Basics_$pp*)x7)->a2 = v58800110;
                    sptr_t v69834446 = MKLAZY(x7);
                    {   gc_frame0(gc,1,v69834446); // <= GCルートにv69834446を登録
                        wptr_t x8 = s_alloc(gc,cCJhc_Prim_Prim_$x3a);
                        ((struct sCJhc_Prim_Prim_$x3a*)x8)->a1 = v106;
                        ((struct sCJhc_Prim_Prim_$x3a*)x8)->a2 = v69834446;
                        return x8;
                    }
                }
            }
        }
}
~~~

このgc_frame0関数はイカのような実装で、つまり上のミューテターはGCルートに

* v58800110: 関数の引数の一つ
* v106とv108: v100444のメンバー。v100444自体はGCルートに登録されない
* v69834446: s_alloc関数で確保したx7スマートポインタに遅延ビットを立てたもの

の4つを登録しているでゲソ。

~~~ {.c}
#define gc_frame0(gc,n,...) void *ptrs[n] = { __VA_ARGS__ }; \
        for(int i = 0; i < n; i++) gc[i] = (sptr_t)ptrs[i]; \
        gc_t sgc = gc;  gc_t gc = sgc + n;
~~~

どーせs_alloc関数を呼ばないかぎりはGCは走らないので、
GCルートに追加するタイミングはs_alloc関数の直前まではあんまり厳密にしなくても良いはずでゲソ。
また、eval関数はサンクの評価を行なう可能性があり、その中でs_alloc関数を呼び出す可能性があるので、
その直前でGCルートを最新の情報に更新しておく必要があるはずでゲソ。

ミューテターをC言語で書いていても、コンパイルパイプラインで自動生成するようにすれば、
gc_frame0関数の挿入のようなアイデアも実装漏れが起きることを気にしないで実現できるでゲソ。
いいじゃなイカ!

xxxxx

## C言語スタックとGCスタックの関係

* gc引数って何？
* saved_gcって何？
* gc_stack_baseって何？

## ミューテターにとってのクリティカルリージョンは？

## 参照はループになるか？
