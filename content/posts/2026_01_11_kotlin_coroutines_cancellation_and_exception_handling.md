+++
title = "Kotlin Coroutines Cancellation and Exception Handling"
date = "2026-01-11"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["kotlin", "coroutines", "exception"]
keywords = ["kotlin", "coroutines", "exception"]
description = ""
showFullContent = false
+++

[![](https://img.shields.io/badge/androidweekly-710-blue#badge)](https://androidweekly.net/issues/issue-710)


Cancellation and exception handling in coroutines is by far the most complex thing I've faced during my entire career. These two things are so complicated that I sometimes ask myself how people are using such a difficult-to-use framework. I read all the possible docs that I found, many different articles, video courses, and even tried to look at the code - and still, I feel that my understanding of this topic is quite bad.  
When reading articles, I often thought that their structure was not good and that things were not clarified in a reasonable way. Usually, articles are just a collection of examples that show how certain combinations of suspending functions or coroutine builders will work. Learning by examples is good, but they should help with understanding core concepts so that all other situations are easy to relate to what was learned.

So, I decided to write my own article, and my original idea was to create a definitive checklist and a cheat sheet that would cover all cases and serve as a go-to document to reference when you're unsure what to do.  

And I failed.  

I tried to structure the materials, and every time I felt everything was good, I found another case that broke most of what I had.

Still, I wanted to shed some light on this topic, so here is my best attempt. The article has three parts:  
1. My opinion on the complexity of the coroutines framework with respect to cancellation and exception handling.  
2. An explanation of cancellation and exception handling to the best of my skills, in a way I think is reasonable to learn.  
3. Best practices for cancellation and exception handling.

---

### Why so complex?

I think there are a lot of reasons why cancellation and exception handling are so complex.  
First, cancellation and exception handling are two different things, but they are coupled together. When an exception happens, the work cannot proceed further, so it should be cancelled. Understanding how these two concepts work together makes it more difficult to work with.

The API of coroutines is very flexible - sometimes too flexible. The fact that `coroutineContext` is just a map of some elements opens the possibility of misuse, passing incorrect objects, or getting unexpected results. The compiler doesn't help, as it doesn't know anything specific. Custom linting can help, but you have to create it yourself.

Also, the API hides a lot from the developer, which is again both good and bad. On the good side, you don't need to dive into the complexity of concurrency to use coroutines. On the other hand, it is often difficult to understand what is happening inside and why the result you got differs from your expectations. There are a lot of methods and extensions meant to help, but from their names, it is very difficult to understand what they do exactly - do they create a new coroutine or work in the current one, do they reuse the job or create a new one, how exceptions will be propagated, and so on.

All this together makes the topic very difficult to grasp, even for professional engineers with a good background in concurrency.

---

### Cancellation and Exception Handling in Coroutines

Let's start with some simple concepts that are also described in the official documentation.

Cancelling can happen in two directions. The first one goes from parent to child. The simplest example is manual cancellation of the scope or job:

```kotlin
scope.cancel() // after that, scope can't be used anymore
scope.coroutineContext.cancelChildren() // cancels all the jobs in the scope, but scope stays alive
job.cancel()
```

Cancellation might also go from child to parent, so effectively a child can cancel the parent, and then the parent will cancel all its remaining children. This might happen, for example, when there is an exception in the child:

```kotlin
scope.launch {
    launch { throw RuntimeException() }
    launch { delay(100) }
}
```

In the example above, all the coroutines and the scope will be cancelled because the child was cancelled with an exception.

So far, pretty straightforward and easy. Why call this complex? Let's dive into details.

---

There are two ways of handling exceptions with coroutines:  
1. `try-catch`  
2. `CoroutineExceptionHandler`

Note that `try-catch` doesn't work with coroutine builder functions `launch` and `async`.  
This won't catch any exceptions thrown in their blocks. This is because builders create the coroutine, effectively entering a concurrent world. What is inside can be executed on another thread, so wrapping that with `try-catch` in our thread cannot have an effect.

A side note: this **will** work with the `runBlocking` coroutine builder due to its nature. So, as we'll see many times - pay attention to details, look at specifics, and try to avoid premature generalization.

```kotlin
try { scope.launch { ... } } catch(e: Exception) { ... }
try { scope.async { ... } } catch(e: Exception) { ... }
```

Let's look at `launch`. Any unhandled exception can be handled by `CoroutineExceptionHandler`:

```kotlin
val handler = CoroutineExceptionHandler { _, _ -> println("handled") }
val scope = CoroutineScope(Job())
scope.launch(handler) { throw RuntimeException() }
```

Setting a handler to a `launch` worked, and the message "handled" was printed.

Similar behavior occurs if we set the handler on the scope. This way, we don't need to set it for each `launch` in that scope:

```kotlin
val handler = CoroutineExceptionHandler { _, _ -> println("handled") }
val scope = CoroutineScope(Job() + handler)
scope.launch { throw RuntimeException() }
```

---

**First important note**: the handler works only in top-level coroutines. That means, if you set it to an intermediate `launch`, the exception won't be handled.  
This won't handle it:

```kotlin
val handler = CoroutineExceptionHandler { _, _ -> println("handled") }
val scope = CoroutineScope(Job())
scope.launch {
    launch(handler) { throw RuntimeException() }
}
```

---

**Second important note**: the handler can work in an intermediate `launch`, but only if there is a `SupervisorJob` in that scope. In the example below, we create a new `supervisorScope` that will have a `SupervisorJob`, so setting up a handler for its launches will handle them:

```kotlin
val handler = CoroutineExceptionHandler { _, _ -> println("handled") }
val scope = CoroutineScope(Job())
scope.launch {
    supervisorScope {
        launch(handler) { throw RuntimeException() }
    }
}
```

---

**Third important note**: handling exceptions with `CoroutineExceptionHandler` is not designed for application-level exception handling. Even if you have a top-level `launch` with a handler, if an exception happens, the coroutine will be cancelled, and the parent will be cancelled as well.  
So, the handler is designed for more technical aspects - logging something to analytics, preventing app crashes - but it doesn't affect scope management.

---

Let's switch to `async` now. `async` handles all exceptions and rethrows them when `await` is called. Here's a basic example:

```kotlin
val handler = CoroutineExceptionHandler { _, _ -> println("handled") }
val scope = CoroutineScope(Job())
val deferred = scope.async { throw RuntimeException() }
try { deferred.await() } catch(e: Exception) { ... }
```

The exception is handled, and the app doesn't crash.

---

**First important note**: setting up an exception handler will be a no-op. While it is possible to pass it to `async`, you should not do that. They just don't work together.  

**Second important note**: while the exception is re-thrown in `await`, `async` cancels with the exception at the time it happens. Why does this matter? Because cancelling with an exception cancels the parent job, which can eventually lead to a crash:

```kotlin
val scope = CoroutineScope(Job())
val job = scope.launch {
    async {
        throw RuntimeException()
    }
}
```

Here, even though we haven't called `await`, the exception is propagated to the parent along with a cancellation. And because the parent `launch` doesn't handle the exception, it will lead to a crash.

---

### Best Practices

When talking about cancellation and exceptions, there is only one best practice:

**Use exceptions only for exceptional cases.**

And this is a best practice from a long time ago:  
Joshua Bloch, *Effective Java*, Item 69: *Use exceptions only for exceptional conditions.*

So, the best thing you can do is to avoid exceptions as much as possible and handle them in scope.  
There are various techniques to achieve that. Two common ones are:  
1. Return `null` when some conditions are not met (if you don't care about the type of error).  
2. Use wrappers such as `Result<Success, Error>` that provide additional information about the error.

By following the rule to avoid exceptions, you will end up with much simpler code that is easier to manage and maintain. You won't need to handle various edge cases related to error propagation and cancellation because of errors.  
Consider exceptions to be errors that you cannot handle, and therefore they may crash your app. Make your code as safe as possible by handling exceptions where possible, and if something slips through, then it might be a good reason to let the app crash.

---

### Bad Practices

A few words on the flexibility of the coroutines API. Previously, I pointed out that you can add any coroutine element to the context, including `Job`.  
Also, `CoroutineExceptionHandler` only works for top-level coroutines or the ones launched within a `SupervisorJob`.

In the example above, I used `supervisorScope` to create a new scope with a `SupervisorJob`:

```kotlin
scope.launch {
    supervisorScope {
        launch(handler) { throw RuntimeException() }
    }
}
```

At the same time, it's possible to do something like this:

```kotlin
scope.launch {
    launch(SupervisorJob() + handler) { throw RuntimeException() }
}
```

Here, I manually set a `SupervisorJob` to the inner `launch`, which makes that `launch` coroutine "top-level," so the handler works.  
However, you should **never** do this.

While it seems to work from the handler's perspective, this destroys the main principle of coroutines - structured concurrency.  
By injecting a job into the inner `launch`, we effectively break the parent-child relationship. The inner `launch` is no longer connected to the parent job. Instead, it is connected to the injected job.

I can hardly imagine a practical use case where such injection is needed. And even if it exists, there should be a more straightforward way to accomplish it. Breaking structured concurrency for coroutines is a recipe for disaster later.  
**Avoid it at all costs.**

---

### Conclusion

That said, I don't think this is the definitive guide I wanted to write. Each suspend function and coroutine builder in the API might have its own specific behavior that one should learn by first reading the docs for each method and testing the functionality.  
Other than that, I still hope this article was useful.

Happy coding!
