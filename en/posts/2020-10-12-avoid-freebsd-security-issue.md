---
title: ATS2 and VeriFast avoid some of vulnerabilities on FreeBSD
description: Vulnerabilities may be avoided, if it is written by ATS2 or verified by VeriFast.
tags: ats, verifast, security, vulnerability, freebsd, kernel, postmortem
---

## TL;DR

After investigating latest 50 of the FreeBSD vulnerabilities, 8 of them could be avoided by the [ATS2 language](http://www.ats-lang.org/), and 5 of them could be avoided by the [VeriFast verifier](https://github.com/verifast/verifast).

## Introduction

There are many vulnerabilities on software.
Operating systems such as Linux and *BSD are no exception.
It undoubtedly causes bad impact on human society, because such software have become infrastructure of that.
On the other hand, there are many solution, such as new language and verifier.
They claim that they can avoid some of the bugs.

So, is it true? In this blog post, let's pick up some of vulnerabilities, apply some solutions, and know how to avoid the vulnerabilities.

## Vulnerabilities

Firstly, we need concrete vulnerabilities to be avoided.
At first glance, [Common Vulnerabilities and Exposures (CVE)](https://cve.mitre.org/) seem like a promising option.
But the CVE often doesn't provide:

* a patch to fix the vulnerability
* the reason why it happened
* the background

Then we choose [FreeBSD Security Advisories](https://www.freebsd.org/security/advisories.html) which provide above.
And also we chose only kernel vulnerabilities, because we are focusing kernel development.
The latest 50 of vulnerabilities are chosen on [a git repository](https://github.com/metasepi/postmortem).

```
$ git clone git@github.com:metasepi/postmortem.git
$ ls postmortem/Security-Advisory/FreeBSD-kernel/ | grep FreeBSD | wc -l
50
$ ls postmortem/Security-Advisory/FreeBSD-kernel/ | grep FreeBSD
FreeBSD-SA-17:09.shm/
FreeBSD-SA-17:10.kldstat/
FreeBSD-SA-18:01.ipsec/
--snip--
FreeBSD-SA-20:27.ure/
FreeBSD-SA-20:28.bhyve_vmcs/
FreeBSD-SA-20:29.bhyve_svm/
```

After carefully reading patches of then, we found following could be easily avoided by some solutions:

* [FreeBSD-SA-17:10.kldstat](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-17:10.kldstat)
* [FreeBSD-SA-19:02.fd](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-19:02.fd)
* [FreeBSD-SA-19:14.freebsd32](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-19:14.freebsd32)
* [FreeBSD-SA-19:15.mqueuefs](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-19:15.mqueuefs)
* [FreeBSD-SA-19:24.mqueuefs](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-19:24.mqueuefs)
* [FreeBSD-SA-20:03.thrmisc](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-20:03.thrmisc)
* [FreeBSD-SA-20:14.sctp](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-20:14.sctp)
* [FreeBSD-SA-20:20.ipv6](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-20:20.ipv6)

## Solutions

We have two options to avoid bugs such as vulnerabilities.

### ATS2 language

[ATS2](http://www.ats-lang.org/) is a statically typed programming language which provides both dependent types and linear types.
The latter is effective for safe memory usage.

### VeriFast verifier

[VeriFast](https://github.com/verifast/verifast) is a tool for modular formal verification of correctness properties of C programs annotated with preconditions and postconditions written in separation logic.
The annotation enforces safe memory usage.

## How to avoid vulnerabilities

Instead of re-writing real kernel code, we wrote pseudo codes to establish that the solutions can avoid the vulnerabilities.
The vulnerabilities avoided by the solutions are classified into the following four categories.

### Category A: forget to free memory

The following are in this category:

* [FreeBSD-SA-19:02.fd](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-19:02.fd)
* [FreeBSD-SA-19:15.mqueuefs](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-19:15.mqueuefs)
* [FreeBSD-SA-19:24.mqueuefs](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-19:24.mqueuefs)

xxx Explain it

This category could be avoided by both ATS2 and VeriFast.

### Category B: forget to lock before using structure

The following are in this category:

* [FreeBSD-SA-20:20.ipv6](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-20:20.ipv6)

xxx Explain it

This category could be avoided by both ATS2 and VeriFast.

### Category C: miss-use reference counting

The following are in this category:

* [FreeBSD-SA-20:14.sctp](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-20:14.sctp)

xxx Explain it

This category could be avoided by both ATS2 and VeriFast.

### Category D: return uninitialized value

The following are in this category:

* [FreeBSD-SA-17:10.kldstat](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-17:10.kldstat)
* [FreeBSD-SA-19:14.freebsd32](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-19:14.freebsd32)
* [FreeBSD-SA-20:03.thrmisc](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-20:03.thrmisc)

xxx Explain it

This category could be only avoided by ATS2.
[VeriFast has not yet avoided these.](https://groups.google.com/g/verifast/c/vJUViRAQbkI/m/1uSJJ-VOBAAJ)

And ATS2 also has a limitation that can't capture error on polymorphic function such as following:

```ats
typedef elf_thrmisc_t = @{ pr_tname = char, _pad = uint }

fun bzero {a:vt@ype}{l:addr} (pf: !a? @ l >> a @ l | p: ptr l): void =
  undefined()

fun sbuf_bcat {a:vt@ype}{l:addr} (pf: !a @ l | p: ptr l): void =
  undefined()

fun sbuf_bcat_thrmisc {l:addr} (pf: !elf_thrmisc_t @ l | p: ptr l): void =
  sbuf_bcat(pf | p)

fun note_thrmisc(): void = {
  var thrmisc: elf_thrmisc_t
  prval pf_thrmisc_pad = view@thrmisc._pad
  val addr_thrmisc_pad = addr@thrmisc._pad
  val () = bzero(pf_thrmisc_pad | addr_thrmisc_pad) // Initialize only `_pad` member
  prval () = view@thrmisc._pad := pf_thrmisc_pad

  prval pf_thrmisc = view@thrmisc
  val addr_thrmisc = addr@thrmisc
  val () = sbuf_bcat(pf_thrmisc | addr_thrmisc) // <= Not cause compile error
  prval () = view@thrmisc:= pf_thrmisc
}
```

It causes compile error, if you use `sbuf_bcat_thrmis` function instead of `sbuf_bcat`.
This limitation is to be fixed on future, because there are many system calls to read from kernel space.
As an example, please imagine [read(2)](https://www.freebsd.org/cgi/man.cgi?query=read&sektion=2), which should only return initialized values from any device.

## Conclusion

xxx

## Future works

* xxx Choose Rust as solution
* xxx Take more vulnerabilities of FreeBSD

## Acknowledgements

* This post was supported by [advisers](https://github.com/metasepi/postmortem/blob/master/Adviser.md).
* This post was strongly inspired by [Chris's blog post](https://bluishcoder.co.nz/2014/04/11/preventing-heartbleed-bugs-with-safe-languages.html).
