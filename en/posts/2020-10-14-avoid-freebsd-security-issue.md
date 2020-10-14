---
title: ATS2 and VeriFast avoid some of FreeBSD vulnerabilities
description: Mechanically avoid 16% of latest FreeBSD vulnerabilities without code review.
tags: ats, verifast, security, vulnerability, freebsd, kernel, postmortem
---

## TL;DR

After investigating latest 50 of the FreeBSD vulnerabilities, 8 of them could be avoided by the [ATS2 language](http://www.ats-lang.org/), and 5 of them could be avoided by the [VeriFast verifier](https://github.com/verifast/verifast).
It means we can mechanically avoid **16%** of the latest vulnerabilities without human resource such as code review.

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

```shell
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

We have two options to avoid bugs such as vulnerabilities today.

### ATS2 language

[ATS2](http://www.ats-lang.org/) is a statically typed programming language which provides both dependent types and linear types.
The latter is effective for safe memory usage.

### VeriFast verifier

[VeriFast](https://github.com/verifast/verifast) is a tool for modular formal verification of correctness properties of C programs annotated with preconditions and postconditions written in separation logic.
The annotation enforces safe memory usage.

## How to avoid vulnerabilities

Instead of re-writing real kernel code, we wrote pseudo codes to establish that the solutions can avoid the vulnerabilities.
The vulnerabilities avoided by the solutions are classified into the following four patterns.

### Pattern A: forget to free memory

The following are in this pattern:

* [FreeBSD-SA-19:02.fd](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-19:02.fd)
* [FreeBSD-SA-19:15.mqueuefs](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-19:15.mqueuefs)
* [FreeBSD-SA-19:24.mqueuefs](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-19:24.mqueuefs)

This pattern could be avoided by both ATS2 and VeriFast.

Original vulnerabilities in C language are caused with forgetting to free memory such as following:

```c
void
m_dispose_extcontrolm(struct mbuf *m)
{
// --snip--
				while (nfd-- > 0) {
					fd = *fds++;
					error = fget(td, fd, &cap_no_rights,
					    &fp);
					if (error == 0) {
						fdclose(td, fp, fd);
						// fdrop(fp, td); // <= Forget calling
					}
				}
```

Above code causes run-time error, which is hard to be found on coding review.

ATS2 can avoid this vulnerabilities.
If you forget to free memory such as following,

```ats
fun m_dispose_extcontrolm (): int = let
    fun loop {n:int | n >= 0} (nfd: int n): void =
      if nfd <= 0 then ()
      else let
          val (pf_fp | fp, error) = fget()
          val () = if error = 0 then {
              prval Some_v(pf_fp2) = pf_fp
              val () = fdclose(pf_fp2 | fp)
              // val () = fdrop(pf_fp2 | fp) // <= Forget calling
            }
            else {
              prval None_v() = pf_fp
            }
        in
          loop(nfd - 1)
        end
    val fd = 1
    val nfd = 10
  in
    loop 10; 0
  end
```

then ATS2 compiler causes compile error.
It means you can notice this bug before shipping.
You can try to see the compile result on your PC as following:

```shell
$ (cd postmortem/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-19:02.fd/Resolution/ATS2 && make)
```

VeriFast can also avoid this vulnerabilities.
If you forget to free memory such as following,

```c
int m_dispose_extcontrolm()
    //@ requires true;
    //@ ensures true;
{
    int fd = 1;
    int nfd = 10;
    int error;
    while (nfd > 0)
        //@ invariant emp;
    {
        struct file *fp;
        error = fget(&fp);
        if (error == 0) {
            fdclose(fp, fd);
            // fdrop(fp); // <= Forget calling
        }
        nfd--;
    }
    return 0;
}
```

then VeriFast verifier find it on verification.
It means you can notice this bug before shipping.
You can try to see the verification result on your PC as following:

```shell
$ (cd postmortem/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-19:02.fd/Resolution/VeriFast && make)
```

### Pattern B: forget to lock before using structure

The following are in this pattern:

* [FreeBSD-SA-20:20.ipv6](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-20:20.ipv6)

This pattern could be avoided by both ATS2 and VeriFast.

Original vulnerability in C language is caused with forgetting to lock structure such as following:

```c
int
ip6_ctloutput(struct socket *so, struct sockopt *sopt)
{
// --snip--
				INP_WLOCK(inp);
				error = ip6_pcbopts(&inp->in6p_outputopts, m,
				    so, sopt);
				INP_WUNLOCK(inp);
```

Above code causes run-time error, which is hard to be found on coding review.

ATS2 can avoid this vulnerabilities.
If you forget to lock structure such as following,

```ats
implement ip6_ctloutput(sh) = let
    // val (pfl, pf | x) = shared_lock{ip6_pktopts}(sh) // <= Forget calling
    val error = ip6_pcbopts(pf | x)
    // val () = shared_unlock(pfl, pf | sh, x) // <= Forget calling
  in
    error
  end
```

then ATS2 compiler causes compile error.
It means you can notice this bug before shipping.
You can try to see the compile result on your PC as following:

```shell
$ (cd postmortem/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-20:20.ipv6/Resolution/ATS2 && make)
```

VeriFast can also avoid this vulnerabilities.
If you forget to lock structure such as following,

```c
int ip6_ctloutput(struct inpcb *inp)
    //@ requires thread_run_data(ip6_thread)(inp);
    //@ ensures thread_run_data(ip6_thread)(inp);
{
    int error;
    //@ open thread_run_data(ip6_thread)(inp);
    struct mutex *m = inp->mutex;
    // mutex_acquire(m); // <= Forget calling
    // //@ open inpcb(inp)();
    error = ip6_pcbopts(&inp->in6p_outputopts);
    // //@ close inpcb(inp)();
    // mutex_release(m); // <= Forget calling
    //@ close thread_run_data(ip6_thread)(inp);
    return error;
}
```

then VeriFast verifier find it on verification.
It means you can notice this bug before shipping.
You can try to see the verification result on your PC as following:

```shell
$ (cd postmortem/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-20:20.ipv6/Resolution/VeriFast && make)
```

### Pattern C: miss-use reference counting

The following are in this pattern:

* [FreeBSD-SA-20:14.sctp](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-20:14.sctp)

This pattern could be avoided by both ATS2 and VeriFast.

Original vulnerability in C language is caused with freeing when `refcount > 1` such as following:

```c
int
sctp_insert_sharedkey(struct sctp_keyhead *shared_keys,
    sctp_sharedkey_t *new_skey)
{
// --snip--
			if ((skey->deactivated) && (skey->refcount > 1)) {
				SCTPDBG(SCTP_DEBUG_AUTH1,
				    "can't replace shared key id %u\n",
				    new_skey->keyid);
				return (EBUSY);
			}
			SCTPDBG(SCTP_DEBUG_AUTH1,
			    "replacing shared key id %u\n",
			    new_skey->keyid);
			LIST_INSERT_BEFORE(skey, new_skey, next);
			LIST_REMOVE(skey, next);
			sctp_free_sharedkey(skey); // Free `skey` if `refcount > 1`
			return (0);
```

Above code causes run-time error, which is hard to be found on coding review.

ATS2 can avoid this vulnerabilities.
If you try to free `skey` when `refcount > 1` such as following,

```ats
fun sctp_insert_sharedkey {l:addr}{r:int} (pf_skey: !sctp_shared_key(r) @ l >> option_v (sctp_shared_key(r) @ l, n != 0) | skey: ptr l): #[n:int] int n =
  if (!skey.deactivated != 0) * (!skey.refcount > 1) // `*` operator means `&&`
  then let
      prval () = pf_skey := Some_v pf_skey
    in
      EBUSY
    end
  else let
      // Insert new_skey
      val () = sctp_free_sharedkey(pf_skey | skey) // Free `skey` if `refcount > 1`
      prval () = pf_skey := None_v ()
    in
      0
    end
```

then ATS2 compiler causes compile error.
It means you can notice this bug before shipping.
You can try to see the compile result on your PC as following:

```shell
$ (cd postmortem/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-20:14.sctp/Resolution/ATS2 && make)
```

VeriFast can also avoid this vulnerabilities.
If you forget to free `skey` when `refcount > 1` such as following,

```c
int sctp_insert_sharedkey(sctp_sharedkey_t *skey)
    //@ requires malloc_block_sctp_shared_key(skey) &*& skey->refcount |-> _ &*& skey->deactivated |-> _;
    /*@
    ensures
        result == 0 ? // success
           true
        : // failure
           malloc_block_sctp_shared_key(skey) &*& skey->refcount |-> _ &*& skey->deactivated |-> _
        ;
    @*/
{
    if ((skey->deactivated) && (skey->refcount > 1)) {
        return EBUSY;
    }
    // Insert new_skey
    sctp_free_sharedkey(skey); // Free `skey` if `refcount > 1`
    return 0;
}
```

then VeriFast verifier find it on verification.
It means you can notice this bug before shipping.
You can try to see the verification result on your PC as following:

```shell
$ (cd postmortem/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-20:14.sctp/Resolution/VeriFast && make)
```

### Pattern D: return uninitialized value

The following are in this pattern:

* [FreeBSD-SA-17:10.kldstat](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-17:10.kldstat)
* [FreeBSD-SA-19:14.freebsd32](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-19:14.freebsd32)
* [FreeBSD-SA-20:03.thrmisc](https://github.com/metasepi/postmortem/tree/master/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-20:03.thrmisc)

This pattern could be only avoided by ATS2.
[VeriFast does not yet avoided these.](https://groups.google.com/g/verifast/c/vJUViRAQbkI/m/1uSJJ-VOBAAJ)

Original vulnerabilities in C language are caused with returning uninitialized value to user space such as following:

```c
typedef struct thrmisc {
    char	pr_tname[MAXCOMLEN+1]; // <= `bzero` doesn't initialize this
    u_int	_pad;
} thrmisc_t;
typedef thrmisc_t elf_thrmisc_t;

static void
__elfN(note_thrmisc)(void *arg, struct sbuf *sb, size_t *sizep)
{
	struct thread *td;
	elf_thrmisc_t thrmisc; // <= allocate in kernel stack

	td = (struct thread *)arg;
	if (sb != NULL) {
		KASSERT(*sizep == sizeof(thrmisc), ("invalid size"));
		bzero(&thrmisc._pad, sizeof(thrmisc._pad));
		strcpy(thrmisc.pr_tname, td->td_name);
		sbuf_bcat(sb, &thrmisc, sizeof(thrmisc)); // <= return uninitialized value to user space
```

Above code causes run-time error, which is hard to be found on coding review.

ATS2 can avoid this vulnerabilities.
If you forget to return uninitialized value to user space such as following,

```ats
typedef elf_thrmisc_t = @{
  pr_tname = char, // <= `bzero` doesn't initialize this
  _pad = uint
}

fun sbuf_bcat_thrmisc {l:addr} (pf: !elf_thrmisc_t @ l | p: ptr l): void =
  undefined()

fun note_thrmisc(): void = {
  var thrmisc: elf_thrmisc_t
  prval pf_thrmisc_pad = view@thrmisc._pad
  val addr_thrmisc_pad = addr@thrmisc._pad
  val () = bzero(pf_thrmisc_pad | addr_thrmisc_pad)
  prval () = view@thrmisc._pad := pf_thrmisc_pad

  prval pf_thrmisc = view@thrmisc
  val addr_thrmisc = addr@thrmisc
  val () = sbuf_bcat_thrmisc(pf_thrmisc | addr_thrmisc) // <= return uninitialized value to user space
  prval () = view@thrmisc:= pf_thrmisc
}
```

then ATS2 compiler causes compile error.
It means you can notice this bug before shipping.
You can try to see the compile result on your PC as following:

```shell
$ (cd postmortem/Security-Advisory/FreeBSD-kernel/FreeBSD-SA-20:03.thrmisc/Resolution/ATS2 && make)
```

But ATS2 has a limitation that can't capture error on polymorphic function such as following:

```ats
fun sbuf_bcat {a:vt@ype}{l:addr} (pf: !a @ l | p: ptr l): void =
  undefined()

fun note_thrmisc(): void = {
  var thrmisc: elf_thrmisc_t
  prval pf_thrmisc_pad = view@thrmisc._pad
  val addr_thrmisc_pad = addr@thrmisc._pad
  val () = bzero(pf_thrmisc_pad | addr_thrmisc_pad)
  prval () = view@thrmisc._pad := pf_thrmisc_pad

  prval pf_thrmisc = view@thrmisc
  val addr_thrmisc = addr@thrmisc
  val () = sbuf_bcat(pf_thrmisc | addr_thrmisc) // <= Not cause compile error
  prval () = view@thrmisc:= pf_thrmisc
}
```

Above code doesn't cause any compile error.
But it correctly causes compile error, if you use `sbuf_bcat_thrmis` function instead of polymorphic `sbuf_bcat` function.
This limitation should be fixed on future, because there are many system calls to read data from kernel space.
As an example, please imagine [read(2)](https://www.freebsd.org/cgi/man.cgi?query=read&sektion=2) system call,
which is undoubtedly a polymorphic function and should only return initialized values from any device.

## Conclusion and Discussion

After investigating latest 50 of the FreeBSD vulnerabilities, 8 of them could be avoided by the ATS2 language, and 5 of them could be avoided by the VeriFast verifier.
It means we can mechanically avoid **16%** of the latest vulnerabilities without human resource such as code review.
This is a notable amount.

Some of vulnerabilities (which is known Pattern D in this post) are only avoided by ATS2.
VeriFast has not yet avoided that.

We need much experience on real usage for ATS2 and VeriFast to introduce real kernel developments such as Linux and FreeBSD.
Because for that, existing kernel needs be re-written by ATS2,
or it needs so many [pseudo C language headers](/en/posts/2018-11-13-see-you-verifast.html) to be verified by VeriFast.

And we should look for solutions other than ATS2 and VeriFast.

## Future works

We will continue this project to understand the solutions to avoid vulnerabilities.

Firstly, we will choose and compare following solutions instead of ATS2 and VeriFast:

* [KreMLin](https://github.com/FStarLang/kremlin)
* [Rust](https://www.rust-lang.org/)
* [SPARK](https://www.adacore.com/about-spark)
* [Zig](https://ziglang.org/)

Secondly, we will know if formal methods such as model checking avoid vulnerabilities.

Finally, we will take more FreeBSD vulnerabilities.

## Acknowledgements

* This post was supported by [advisers](https://github.com/metasepi/postmortem/blob/master/Adviser.md).
* This post was strongly inspired by [Chris's blog post](https://bluishcoder.co.nz/2014/04/11/preventing-heartbleed-bugs-with-safe-languages.html).
