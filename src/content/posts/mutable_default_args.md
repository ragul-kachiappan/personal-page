+++
title = "Hacky usage of mutable default arguments in Python"
date = 2025-02-12
draft = "true"
tags = ["Python", "logging", "Functional Programming"]
categories = ["Python", "Functional Programming"]
+++

One of the most commonly known gotchas in Python is the use of mutable default arguments.
Consider this simple Python function snippet:

```python
def foo(item: int, bar: list = []) -> None:
    bar.append(item)
    print(f"{bar=}")  # Neat f-string trick btw to print both variable name and value


foo(6)
foo(6)
foo(12)
```

A Python newcomer might expect the output to be:

```python
bar = [6]
bar = [6]
bar = [12]
```

Instead you would get:

```python
bar = [6]
bar = [6, 6]
bar = [6, 6, 12]
```

You would assume that the default [] empty list argument would be initialised at every function call. The reason is that default arguments in Python are evaluated once at function definition time, not each time the function is called. Mutable objects like lists and dictionaries, once created as defaults, will be shared across all calls to the same function that don’t provide an explicit value. This behaviour is well documented in sources like ["Effective Python"](https://effectivepython.com/) by Brett Slakin and [The Hitchhiker's Guide to Python](https://docs.python-guide.org/writing/gotchas/)

## Exploiting the behaviour: A hack for state retention

While using mutable defaults is widely recognized as an anti-pattern for everyday programming, I started exploring on whether this persistent state can be used to temporarily collect something on between repeated calls to the same function.

For instance, I once needed to log info from a series of API calls in a Chatbot that uses OpenAI API. Each query to Chatbot would make multiple LLM API calls to arrive at an answer. I needed to save those logs to database but saving to DB after each API call would introduce unnecessary DB writes. I wanted to accumulate logs in a temporary "bucket" and write them to DB once the session is complete.

Here’s an example that uses a mutable default to accumulate log entries:

```python
from dataclasses import dataclass


@dataclass
class APICallLog:
    message: str
    timestamp: float


def call_logger(
    log: APICallLog | None = None,
    dump: bool = False,
    mutable_log_trace: list[APICallLog] = [],
) -> None:
    if not log and not dump:
        raise Exception("No log provided and dump not set")
    if log:
        mutable_log_trace.append(log)
    if dump:
        # Process logs (for example, write to DB)
        print(f"Dumping {len(mutable_log_trace)} logs")
        mutable_log_trace.clear()


# Using the logger
logger = call_logger

logger(log=APICallLog("foo", 1.0))
logger(log=APICallLog("bar", 2.0))
logger(dump=True)
```

At first glance, this seems like a neat way to “remember” state between calls without resorting to classes. However, the problem becomes apparent when you try to use multiple independent loggers:

```python
logger1 = call_logger
logger2 = call_logger

logger1(log=APICallLog("foo", 1.0))
logger1(log=APICallLog("bar", 2.0))
logger2(log=APICallLog("hello", 3.0))
logger2(log=APICallLog("world", 4.0))
logger1(dump=True)
```

Both logger1 and logger2 share the same default list, leading to an unintended merge of log entries.

Instead of writing a Class based solution, I experimented with a stateful function by relying on a mutable default argument.
While Functional Programming emphasizes pure functions and immutability, it still provides mechanisms like closures and partials for handling state when necessary. It should be more sophisticated than directly mutating a global list, but lighter than a full OOP implementation.

## Better Alternatives: Closures and Partials

To avoid this pitfall while still keeping a functional flavor (and without resorting to OOP), you can “encapsulate” state in a closure or bind it with a partial.

### Using Closures

Closures allow you to define a function that captures variables from its enclosing scope. Here’s how you can create a stateful logger using a closure:

```python
def create_call_logger() -> callable:
    mutable_log_trace: list[APICallLog] = []

    def call_logger(log: APICallLog | None = None, dump: bool = False) -> None:
        if not log and not dump:
            raise Exception("No log provided and dump not set")
        if log:
            mutable_log_trace.append(log)
        if dump:
            print(f"Dumping {len(mutable_log_trace)} logs")
            mutable_log_trace.clear()

    return call_logger


logger1 = create_call_logger()
logger2 = create_call_logger()

logger1(log=APICallLog("foo", 1.0))
logger1(log=APICallLog("bar", 2.0))
logger2(log=APICallLog("hello", 3.0))
logger2(log=APICallLog("world", 4.0))
logger1(dump=True)  # Dumps only logger1's logs
```

With closures, each logger gets its own enclosed state, preventing the accidental sharing seen with mutable default arguments.

### Using Partials

Another approach is to use `functools.partial` to “bake in” a fresh mutable object for each instance of your logger:

```python
from functools import partial


def call_logger(
    mutable_log_trace: list[APICallLog],
    log: APICallLog | None = None,
    dump: bool = False,
) -> None:
    if not log and not dump:
        raise Exception("No log provided and dump not set")
    if log:
        mutable_log_trace.append(log)
    if dump:
        print(f"Dumping {len(mutable_log_trace)} logs")
        mutable_log_trace.clear()


logger1 = partial(call_logger, mutable_log_trace=[])
logger2 = partial(call_logger, mutable_log_trace=[])

logger1(log=APICallLog("foo", 1.0))
logger1(log=APICallLog("bar", 2.0))
logger2(log=APICallLog("hello", 3.0))
logger2(log=APICallLog("world", 4.0))
logger1(dump=True)
```

Here, each partial call binds its own new list as the `mutable_log_trace`. This method is concise and leverages Python’s built-in functional programming tools.

Using proper logging frameworks is the ideal approach in production systems as this stateful functions may have some pitfalls when it comes to memory, error handling, debugging and concurrency. But it still demonstrates a neat Functional Programming based solutioning for simple problems we might encounter.
