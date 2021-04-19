---
title: ATS2 can avoid some of FreeBSD Problem Reports
description: Mechanically avoid 12% of latest FreeBSD Problem Reports without code review.
tags: ats, bug, freebsd, kernel, postmortem
---

## TL;DR

The 6 of the 50 arbitrarily selected bugs reported in
[FreeBSD Problem Reports](https://www.freebsd.org/support/bugreports/)
could be prevented by [ATS2](http://www.ats-lang.org/) at compile time.
This means that **12%** of FreeBSD Problem Reports can be avoided at compile time.

## Introduction

In [the previous article](./2020-10-14-avoid-freebsd-security-issue.html), we created some
postmortems for FreeBSD vulnerabilities and presented a solution using
[ATS2](http://www.ats-lang.org/) and [VeriFast](https://github.com/verifast/verifast).
However, kernel bugs are not only reported in the vulnerability report.
There are many bugs that are not vulnerabilities that are discovered after the kernel is
released.

Is it possible to find a way to avoid non-vulnerable bugs by creating a postmortem
for vulnerabilities?
We think no.
The vulnerability report only lists defects that affect security.
Since security is mainly concerned about network defects, non-security related defects
such as a display not appearing are not reported.

## FreeBSD Problem Report (PR)

The [FreeBSD Problem Report (PR)](https://www.freebsd.org/support/bugreports/)
manages bugs that are not such vulnerabilities.
The PR has reported various bugs with the FreeBSD OS.
This time, we selected any 50 cases from PR, wrote a post-mortem, and investigated
whether ATS2 could avoid the problem.

## How to avoid FreeBSD PRs

This time, we chose only ATS2 as a solution to avoid bugs.
The reason is that in the previous article, ATS2 was the most effective in avoiding
vulnerabilities.
Of course, the characteristics of the defect may differ between the vulnerability and PR,
so it is also good to consider another solution such as VeriFast.

### Pattern 1: Panic or KASSERT

The bug is that calling `panic` or `KASSERT` causes the kernel to stop running altogether.
The following seems to be preventable at compile time:

* [253061](https://github.com/metasepi/postmortem/tree/master/PR/FreeBSD-kernel/253061)

### Pattern 2: Mixing different meaning on same type

This bug is that it can be misused by mixing multiple meanings in one type such as `int`.
The following seems to be preventable at compile time:

* [248065](https://github.com/metasepi/postmortem/tree/master/PR/FreeBSD-kernel/248065)

### Pattern 3: Division by zero

This bug is that the execution of the kernel is completely stopped by dividing by zero.
The following seems to be preventable at compile time:

* [252958](https://github.com/metasepi/postmortem/tree/master/PR/FreeBSD-kernel/252958)
* [253511](https://github.com/metasepi/postmortem/tree/master/PR/FreeBSD-kernel/253511)

### Pattern 4: Variable length structure

The bug is that copying the structure fails if someone doesn't consider the size of the
variable length structure.
The following seems to be preventable at compile time:

* [253488](https://github.com/metasepi/postmortem/tree/master/PR/FreeBSD-kernel/253488)

### Pattern 5: Non-recursive mutex

The bug is that the kernel crashes by locking multiple mutexes that should not be
recursively locked.
The following seems to be preventable at compile time:

* [216510](https://github.com/metasepi/postmortem/tree/master/PR/FreeBSD-kernel/216510)

## Conclusion and Discussion

Six of the 50 arbitrarily selected bugs reported in FreeBSD PRs could be avoided by
ATS2 at compile time.
The sample size is small, but it means that 12% of FreeBSD PRs can be avoided at
compile time.
Whether this percentage feels large or small will vary from person to person.

Illegal memory access could not be prevented this time.
This is because ATS2 cannot create a view that contains a view.

We expected that the bug that the kernel would stop due to conditions such as
`panic` and `KASSERT` could be prevented more at compile time.
However, when we actually investigated it, we got the impression that the causes of
`panic` are often dynamic rather than static.
It will be quite difficult to completely remove `panic` and `KASSERT` from the kernel.

We were surprised to find two defects due to division by zero.
Dependent type should be introduced on the right value of division.

Misuse of variable length structures can be a common sensational defect.
There should be many more of this bug.

Overall, the dependent and linear types of ATS2 were very useful.
On the other hand, in ATS2, it is difficult to port C language expressions such as
structures including pointers as they are.
A secure and safe kernel requires something that extends ATS2 to be more C-friendly.
Or we may need to boldly re-write your current C implementation.

## Acknowledgements

* This post was supported by [advisers](https://github.com/metasepi/postmortem/blob/master/Adviser.md).
* This post was strongly inspired by [Chris's blog post](https://bluishcoder.co.nz/2014/04/11/preventing-heartbleed-bugs-with-safe-languages.html).
