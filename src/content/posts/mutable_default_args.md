+++
title = "Hacky usage of mutable default arguments in Python"
date = 2025-01-15
draft = "true"
+++

<intro para about I always used to wonder what we can do with it>
<interview example that I used to ask that to test this knowledge>
<quote from intermediate python book about violation in mutable default argument>
<quote another reference from python reference in internet>
<blabber bit OOP and state>
<How we can replicate that state behaviour with partials>
<Talk about your problem of logging>
<Solution that I created with partials and mutable default args for capturing logs on series of LLM calls>
<Disclaimer that this is not a recommended solution, just a thought process and quirky implementation>


One of the most commonly known gotcha's in Python is the use of mutable default arguments. 
Consider this snippet below:
```python
def foo(item: int, bar: list = []) -> None:
    bar.append(item)
    print(f"{bar=}") # Neat f-string trick btw to print both variable name and value

foo(6, [10])
foo(6)
foo(12)
```
You would expect the output to be:
```
bar=[10, 6]
bar=[6]
bar=[12]
```
Instead you would get:
```
bar=[10, 6]
bar=[6]
bar=[6, 12]
```
You would assume that the default [] empty list argument would be initialised at every function call.
A default argument value is evaluated only once when the function is defined not when the function is called. We would be fine while using immutable values (None, str, int, bool, tuple, etc) as default. But mutable defaults like list, dictionary can lead to odd behaviours.
This is recognized as an anti-pattern and warned off in ["Effective Python"](https://effectivepython.com/) by Brett Slakin and [The Hitchhiker's Guide to Python](https://docs.python-guide.org/writing/gotchas/)

I would also test this among interview candidates occasionally to see if they were aware of this behaviour or at least if they pondered about it at that moment.


Recently, I was building a Chatbot with LLM service provided by OpenAI API.
```python
def create_node_history_hook(
    mutable_log_trace: list[openai_client_utils.OpenAINodeRunLog],
):
    """
    Creates a hook function for logging and dumping node history.

    This function returns a closure that can be used to log OpenAI node runs
    and periodically dump them to the database.

    Args:
        mutable_log_trace (list[openai_client_utils.OpenAINodeRunLog]):
            A mutable list to store log traces temporarily.

    Returns:
        Callable: A hook function that can be called to log runs or dump to database.

    The returned hook function has the following signature:
        node_history_hook(
            log: openai_client_utils.OpenAINodeRunLog | None = None,
            dump: bool = False,
            extra_data: dict | None = None,
        ) -> None

    Hook function args:
        log (openai_client_utils.OpenAINodeRunLog | None): Log object to append.
        dump (bool): If True, dumps the collected logs to the database.
        extra_data (dict | None): Additional data to include in the database entry.

    Raises:
        RuntimeError: If an unexpected error occurs during bulk create.
        ValueError: If both log and dump are False.

    Example:
        log_trace = []
        hook = create_node_history_hook(mutable_log_trace=log_trace)
        hook(log=some_log_object)  # Logs a run
        hook(dump=True)  # Dumps logs to database
    """

    def node_history_hook(
        log: openai_client_utils.OpenAINodeRunLog | None = None,
        dump: bool = False,
        extra_data: dict | None = None,
    ) -> None:
        if log:
            mutable_log_trace.append(log)

        if dump:
            try:
                node_history = [
                    models.LLMNodeRunLog(
                        node_name=midalloy_chat_app_constants.LLMNodeNames(
                            log_obj.node_name
                        ),
                        llm_prompt=log_obj.llm_prompt,
                        llm_functions=log_obj.llm_functions,
                        llm_response=log_obj.llm_response,
                        tokens_used={
                            "prompt_tokens": log_obj.prompt_tokens,
                            "completion_tokens": log_obj.completion_tokens,
                        },
                        is_success=log_obj.is_success,
                        start_time=log_obj.start_time,
                        end_time=log_obj.end_time,
                        **(extra_data or {}),
                    )
                    for log_obj in mutable_log_trace
                ]
                models.LLMNodeRunLog.objects.bulk_create(node_history)
                mutable_log_trace.clear()
            except Exception as e:
                raise RuntimeError(f"Unexpected error during bulk create: {e}")

        if not log and not dump:
            raise ValueError("At least one of log or dump must be True")

    return node_history_hook
```
