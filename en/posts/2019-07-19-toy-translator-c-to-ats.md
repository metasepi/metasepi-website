---
title: A toy translator C to ATS
description: Try to translate IDIOMATIC C code into human readable ATS code.
tags: ats, idiomaticca, haskell, c, translator
---

## TL;DR

We can translate a simple `for` and `while` loop in C language into a recursive function in ATS language, using the [idiomaticca](https://github.com/metasepi/idiomaticca) tool.

## Why difficult to make real products in ATS language?

We believe [ATS language](http://www.ats-lang.org/) is a better choice than C language.
Because it can:

* prove simple invariant,
* safely use pointer,
* support some rich types such as tuple,
* support template,

But there are following barriers to make real products in ATS:

1. Hard to learn ATS language.
2. Hard to reuse existing programs and libraries written in C.

## Why is c2ats not useful?

We have already create [c2ats](https://github.com/metasepi/c2ats) to fix above barriers.
But people should write own ATS code side of existing C code,
because the c2ats only translate C function signature into ATS.
It can't translate C function body.

Please imagine that someone tries to translate [a file system driver](https://www.netbsd.org/docs/internals/en/chap-file-system.html) using c2ats:

1. Choose [target files](https://github.com/NetBSD/src/tree/trunk/sys/ufs/ffs) to be translated.
2. Translate headers included by the target files into ATS using c2ats.
3. Manually re-write the target files by ATS

Undoubtedly, the step 3 requires more man-hours, and is sometimes unrealistic.

## Let's start to create new translator C to ATS

If so, how about translate __both__ function signature and function body into ATS?
The translator may fix:

* the barrier 1, because programmer learn ATS with codes translated from their C code,
* the barrier 2, because manually re-writing is not needed.

Of course, we know it seems like a crazy attempt.
Let's try to create a toy translator C to ATS.
We call it [idiomaticca](https://github.com/metasepi/idiomaticca).

## How to install

```shell
$ git clone https://github.com/metasepi/idiomaticca.git -b v0.1.0.0
$ cd idiomaticca
$ make install
$ which idiomaticca
/home/YourName/.local/bin/idiomaticca
```

## Some examples

### `while` loop in C

```shell
$ vi loop_while.c
```
```c
int fib(int n) {
	int f0 = 0, f1 = 1;

	while (n-- > 0) {
		int tmp = f1;
		f1 = f0 + f1;
		f0 = tmp;
	}

	return f0;
}

int main() {
	return fib(10);
}
```
```shell
$ gcc loop_while.c
$ ./a.out
$ echo $?
55
$ idiomaticca trans loop_while.c > loop_while.dats
$ cat loop_while.dats
```
```ats
#include "share/atspre_staload.hats"

staload UN = "prelude/SATS/unsafe.sats"

fun fib(n : int) : int =
  let
    var n: int = n
  in
    let
      var f0: int = 0
      var f1: int = 1
      
      fun loop_while(f0 : int, f1 : int, n : int) : (int, int, int) =
        let
          var f0: int = f0
          var f1: int = f1
          var n: int = n
        in
          if n > 0 then
            let
              val () = n := n - 1
              var tmp: int = f1
              val () = f1 := f0 + f1
              val () = f0 := tmp
            in
              loop_while(f0, f1, n)
            end
          else
            (f0, f1, n)
        end
      
      val (i9a_f0, i9a_f1, i9a_n) = loop_while(f0, f1, n)
      val () = f0 := i9a_f0
      val () = f1 := i9a_f1
      val () = n := i9a_n
    in
      f0
    end
  end

implement main () =
  fib(10)
```
```shell
$ patscc loop_while.dats
$ ./a.out
$ echo $?
55
```

### `for` loop in C

```shell
$ vi loop_for.c
```
```c
int sum(int n) {
	int i, sum = 0;

	for (i = 1; i <= n; i++) {
		sum = sum + i;
	}

	return sum;
}

int main() {
	return sum(5);
}
```
```shell
$ gcc loop_for.c
$ ./a.out
$ echo $?
15
$ idiomaticca trans loop_for.c > loop_for.dats
$ cat loop_for.dats
```
```ats
#include "share/atspre_staload.hats"

staload UN = "prelude/SATS/unsafe.sats"

fun sum(n : int) : int =
  let
    var n: int = n
  in
    let
      var i: int
      var sum: int = 0

      fun loop_for(i : int, n : int, sum : int) : (int, int, int) =
        let
          var i: int = i
          var n: int = n
          var sum: int = sum
        in
          if i <= n then
            let
              val () = sum := sum + i
              val () = i := i + 1
            in
              loop_for(i, n, sum)
            end
          else
            (i, n, sum)
        end

      val () = i := 1
      val (i9a_i, i9a_n, i9a_sum) = loop_for(i, n, sum)
      val () = i := i9a_i
      val () = n := i9a_n
      val () = sum := i9a_sum
    in
      sum
    end
  end

implement main () =
  sum(5)
```
```shell
$ patscc loop_for.dats
$ ./a.out
$ echo $?
15
```

### the others

Please see [regress tests](https://github.com/metasepi/idiomaticca/tree/master/regress).

## Next?

* Support `break`, `continue`, and `goto`. (Should use some kind of CFG?)
* Support pointers using at-view.
* Support C headers using `.sats` files.
* Use `val` instead of `var`.
* Simplify ATS code. Example: reduce multiple `let`.
* Support ATS3.
* And more...

## Acknowledgements

* This translator is inspired by Jamey Sharp's [Corrode](https://github.com/jameysharp/corrode) translator.
* This translator is using Vanessa McHale's [language-ats](http://hackage.haskell.org/package/language-ats) library.
