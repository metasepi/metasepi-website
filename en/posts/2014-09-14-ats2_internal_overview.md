---
title: (UnderConstruction) ATS2 internal overview
description: First trying to read source code of ATS2 compiler.
tags: ats, internal, compiler
---

## Call graph

~~~
pats_main.dats:main
=> pats_filename.dats:the_prepathlst_push
=> pats_trans1_env.dats:the_trans1_env_initialize
=> pats_trans2_env.dats:the_trans2_env_initialize
=> pats_comarg.dats:comarglst_parse
=> pats_comarg.dats:process_ATSPKGRELOCROOT
=> pats_main.dats:process_cmdline
   => pats_main.dats:process_cmdline2
~~~
