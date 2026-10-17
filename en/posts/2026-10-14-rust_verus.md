---
title: Survey. An Introduction to OS-Level Verification with Asterinas and Verus
description: A talk about verifying Linux compatible kernel written with Rust
tags: survey, rust, verus, linux, kernel, asterinas
---

I gave a short talk at [Rust、何もわからない… #15](https://estie.connpass.com/event/405217/) about formal verification at the operating-system level. The slides are below.

<div class="slide-deck">
  <iframe src="/doc/talks/2026-10-14-rust_verus/index.html"
          title="An Introduction to OS-Level Verification with Asterinas and Verus"
          loading="lazy"
          allow="autoplay; fullscreen"
          allowfullscreen></iframe>
</div>

<p class="slide-deck-links">
  <a href="/doc/talks/2026-10-14-rust_verus/index.html">Open slides in a new tab</a>
  &middot;
  <a href="/doc/talks/2026-10-14-rust_verus/slides.pdf">Download PDF</a>
  &middot;
  <a href="https://github.com/master-q/masterq-docs/tree/master/presentations/20261014-rust_verus">View Markdown source</a>
</p>

[Asterinas](https://github.com/asterinas/asterinas) is a Linux-compatible kernel written in Rust. Most of its code uses safe Rust, while low-level operations that require `unsafe` are isolated in OSTD. [VOSTD](https://github.com/asterinas/vostd) uses [Verus](https://github.com/verus-lang/verus) to verify this low-level layer.

For the demo, I deliberately introduced a bug into `align_down`. The function should return the greatest multiple of a power-of-two alignment that is no greater than the input. Changing

```rust
self & !(align - 1)
```

to

```rust
self & (align - 1)
```

breaks that guarantee. Verus caught the bug because it could no longer prove the postcondition `ret % align == 0`. Unlike a test, this check is about satisfying the specification, not just passing selected inputs.

Writing the proof for the correct implementation is much harder than spotting this bug. The proof needs lemmas connecting bitwise operations, masks, and alignment. [KVerus](https://github.com/asterinas/KVerus) explores using LLMs to generate and repair Verus proofs. Perhaps one day, developers will only need to write preconditions and postconditions, while an LLM drafts the proof code and Verus checks it. That is a direction to explore, not yet a reason to treat proof generation as a solved problem.

## Resources

- [Asterinas](https://github.com/asterinas/asterinas)
- [VOSTD](https://github.com/asterinas/vostd)
- [Verus](https://github.com/verus-lang/verus)
- [KVerus](https://github.com/asterinas/KVerus)
