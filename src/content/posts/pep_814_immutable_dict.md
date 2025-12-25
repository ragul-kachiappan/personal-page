+++
title = "Frozendict in Python (PEP 814): The Safer Default-Argument Story for Mappings"
date = 2025-12-25T10:00:00+05:30
tags = ["Python", "PEPs", "Immutability", "Concurrency"]
categories = ["Python"]
+++

Python's mutable-default-argument gotcha is infamous. In my earlier [post](https://ragulk.com/posts/mutable_default_args/), I went one step further and tried to *exploit* it: using a mutable default as a state bucket, then showing why it breaks the moment you want multiple independent instances (and why it gets even uglier around concurrency).

Now there's a language-level proposal that's relevant to the *same theme*—but in a much more principled way.

**PEP 814 proposes a new built-in type: `frozendict`**, an immutable mapping designed to be "safe by design." It's currently a **Draft** targeting **Python 3.15**.

This won’t “solve mutable defaults” as a whole (lists are still lists), but it *does* improve one specific class of bugs and awkwardness: **dictionary-shaped defaults and configs**.

---

## What `frozendict` is (according to PEP 814)

PEP 814’s `frozendict` is:

* A public immutable mapping added to `builtins`
* **Not a `dict` subclass** (inherits from `object` directly)
* Insertion-order preserving (like `dict`)
* Pickleable
* Potentially **hashable** (when keys and values are hashable)

That "not a `dict` subclass" detail is doing real work: it avoids the classic loophole where a "frozen" type can still be mutated via base-class methods (e.g., `dict.__setitem__(...)`).

---

## The immediate win: safer defaults for mapping parameters

The boring-but-correct pattern today is:

```python
def build_config(overrides=None):
    if overrides is None:
        overrides = {}
    ...
```

PEP 814 explicitly calls out that immutable mappings help avoid the mutable-default trap for dict-like parameters. With `frozendict`, you can write something like:

```python
def build_config(overrides=frozendict()): ...
```

Now the default can't be mutated accidentally, and the "this is read-only config" intent becomes enforceable instead of purely conventional.

Important boundary: this only helps when your default is naturally a **mapping**. Your classic `list=[]` gotcha is still alive and well.

---

## Hashability unlocks nicer caching and composability

`dict` is unhashable, which is why it can't be used as a key in another dict or as an argument key for memoization-style caching.

PEP 814 proposes that `frozendict` becomes hashable *if* all keys and values are hashable, with an order-independent hash conceptually computed like hashing a `frozenset(items)`.

That matters because `functools.lru_cache` effectively depends on hashable arguments for its cache keying behavior, and unhashable inputs (like dicts) are a common friction point.

So `frozendict` isn’t just “read-only dict”: it’s also a “can participate in other data structures cleanly” dict.

---

## Concurrency: “safe to share”… but shallowly immutable

PEP 814 explicitly motivates `frozendict` as easier to reason about across thread and async task boundaries because it's immutable after creation.

There's a footnote worth stating plainly:

**`frozendict` is structurally immutable, not deeply immutable.**

If you store a list as a value, the mapping won't let you replace that value, but the list itself can still be mutated if you have a reference to it. The PEP itself illustrates the shallow-copy reality: copying the container doesn't protect you from mutations inside nested mutable values.

So the practical rule is:

* `frozendict` prevents “oops I added/updated a key” bugs.
* It does not automatically prevent “oops I mutated a nested object” bugs.

---

## Why this is better than `MappingProxyType` for many cases

Python already has `types.MappingProxyType`, which creates a read-only proxy view over a mapping. The catch is: it's a **dynamic view**—if the underlying dict changes, the proxy reflects those changes.

PEP 814 argues that `MappingProxyType` also isn't hashable and doesn't provide the same "safe by design" story (because the original mutable dict still exists and can be mutated elsewhere).

So the rough division is:

* `MappingProxyType`: “read-only view of something mutable”
* `frozendict`: “actually immutable container”

They’re not substitutes; they’re different tools for different trust boundaries.

---

## Tying it back to the “hacky mutable defaults” lesson

The meta-lesson from my earlier exploration wasn't "defaults are bad." It was:

* Hidden shared state is a trap.
* If you want state, make ownership explicit (closure/partial/class/context).
* If you want safety across concurrency, don't rely on accidental sharing.

`frozendict` fits cleanly into that worldview: it makes “this mapping is not supposed to mutate” something you can express directly in the type system and runtime behavior—especially useful for configs, options, and constant lookup tables.

It won’t make stateful buffering patterns magically safe (that’s still about lifecycle and ownership), but it *does* remove a whole category of accidental mutation for mapping-shaped data.

---

## References

* [PEP 814 – Add frozendict built-in type](https://peps.python.org/pep-0814/)
* [Mutable default arguments in Python (blog post)](https://ragulk.com/posts/mutable_default_args/)
* [Python documentation: types.MappingProxyType](https://docs.python.org/3/library/types.html)
* [Python.org discussion on PEP 814](https://discuss.python.org/t/pep-814-add-frozendict-built-in-type/104854)
* [Python documentation: functools and lru_cache](https://docs.python.org/3/library/functools.html)
