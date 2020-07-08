+++
title = "Kotlin-Java interop: function references and SAM conversions"
date = "2018-09-13"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["kotlin", "java", "interop", "interoperability"]
keywords = []
description = ""
showFullContent = false
+++

> [![](https://img.shields.io/badge/original-medium-green)](https://medium.com/@krossovochkin/kotlin-java-interop-function-references-and-sam-conversions-3d0cd36f7967)

Though all the things below are pretty obvious if being careful while dealing with Kotlin-Java interop, I decided still to write short note about one particular issue with function references (from Kotlin side) and SAM conversions (from Java side).

### Function reference

Function reference is a good way to pass function as a parameter without explicitly using lambdas.

For example, if we have function:

    fun method(callback: (Input) -> Output) { ... }

then we can pass our function as a lambda with function call or as a function reference:

    fun callback(input: Input): Output { ... }

    ...

    method { input -> callback(input) } // lambda
    method(::callback) // function reference

I really like to use function references where possible, because it is a bit more concise, you do not create wrapper for “callback”, code is shorter and even easier to read (most of the time).
And this article is about issues function references can produce when they touch Java.

### **SAM conversions**
> Just like Java 8, Kotlin supports SAM conversions. This means that Kotlin function literals can be automatically converted into implementations of Java interfaces with a single non-default method, as long as the parameter types of the interface method match the parameter types of the Kotlin function.
[Reference](https://kotlinlang.org/docs/reference/java-interop.html#sam-conversions)

That means that when you call some Java method from Kotlin, and that method satisfies conditions described above, you can pass lambda or method reference instead.

So example (from the same reference):

    Executor.java:

    void execute(Runnable command) { ... }

    Kotlin:

    executor.execute { doSomething() }

### Issue description

So, let’s take a look at the example, which shows the issue.
Consider we have some ThirdParty Java class with some listeners inside.
One can register some listeners in ThirdParty class and have updates passed through them.
Later on you can unregister listeners.
ThirdParty class might look like this (code with business logic of calculating some data and passing it through listeners is not presented in the code as it doesn’t matter):

    public class ThirdParty {
    
        public static final String *TAG *= "ThirdParty";
    
        private List<Callback> callbacks = new ArrayList<>();
    
        public void addCallback(Callback callback) {
            Log.*d*(*TAG*, "addCallback: " + callback);
    
            callbacks.add(callback);
        }
    
        public void removeCallback(Callback callback) {
            Log.*d*(*TAG*, "removeCallback: " + callback);
    
            callbacks.remove(callback);
        }
    
        public void printState() {
            Log.*d*("ThirdParty", "Callbacks count" + callbacks.size());
        }
    
        interface Callback {
            void onValueChanged(int value);
        }
    }

So we have **Callback** interface which satisfied SAM conversion rules, so as a result we can pass lambdas and method references to **addCallback **and **removeCallback **methods from Kotlin code.

Then let’s look at the client code.
We will create callback, register it in the ThirdParty class and then immediately unregister it.
After each step we’ll look at the state of ThirdParty class (using logs).

    fun main() {
    
        **val callback = ::onValueChanged**
        Log.d(ThirdParty.*TAG*, "callback created: $callback")
    
        val thirdParty = ThirdParty()
    
        thirdParty.printState()
    **    thirdParty.addCallback(callback)**
        thirdParty.printState()
    **    thirdParty.removeCallback(callback)**
        thirdParty.printState()
    }
    
    private fun onValueChanged(value: Int) {
        // do something
    }

So, here we’ve created callback (we store value in the property, so that we can unregister that callback later).

Let’s look at logs:

    D/ThirdParty: callback created: function onValueChanged (Kotlin reflection is not available)
    E/ThirdParty: Callbacks count0
    D/ThirdParty: **addCallback**: $sam$ThirdParty_Callback$0@**6a2e0a7**
    E/ThirdParty: Callbacks **count1**
    D/ThirdParty: **removeCallback**: $sam$ThirdParty_Callback$0@**bf6b954**
    E/ThirdParty: Callbacks **count1**

So what we see:

* addCallback was called with one instance of callback and removeCallback was called with another instance (though we passed same function reference to both methods)

* removeCallback hasn’t removed callback and previously added callback is still registered in ThirdParty. So we have a leak.

That happens because our created callback is a (Int) -> Unit function and is not instance of ThirdParty.Callback , so after passing that function reference to a SAM different instanced of ThirdParty.Callback are created.

### How to fix

To fix this issue (and leak) we should have our callback to be ThirdParty.Callback from the beginning and not a function reference.
There are few ways to do that:

    val callback = object : ThirdParty.Callback {
        override fun onValueChanged(value: Int) {
            this@App.onValueChanged(value)
        }
    }

    val callback = ThirdParty.Callback **{ **value **-> **onValueChanged(value) **}**

    val callback = ThirdParty.Callback(::onValueChanged)

All of them are the same, though third one again looks a bit better.

Let’s look at resulting logs:

    D/ThirdParty: callback created: $sam$ThirdParty_Callback$0@**6a2e0a7**
    D/ThirdParty: Callbacks count0
    D/ThirdParty: addCallback: $sam$ThirdParty_Callback$0@**6a2e0a7**
    D/ThirdParty: Callbacks **count1**
    D/ThirdParty: removeCallback: $sam$ThirdParty_Callback$0@**6a2e0a7**
    D/ThirdParty: Callbacks **count0**

So all instances are the same and we successfully removed callback from ThirdParty class.

Looks pretty obvious and clear, though such small improvements from Kotlin side to predict how things can be used in Java can provide weird issues which are difficult to track (especially when it comes to memory leaks).

### What happens if there is no Java code

One important thing to know is that such issues can happen only between Kotlin and Java.
If we had ThirdParty class written in Kotlin (or just converted from Java to Kotlin), then our previously written code wouldn’t compile:

    Type mismatch: inferred type is KFunction1<[@ParameterName](http://twitter.com/ParameterName) Int, Unit> but ThirdParty.Callback was expected

That’s because SAM conversion works only with Java and not with Kotlin. So in this case we’re pretty much safe and won’t make such errors.

But at the same time we have only one option to create callback:

    val callback = object : ThirdParty.Callback {
        override fun onValueChanged(value: Int) {
            this@App.onValueChanged(value)
        }
    }

Other ways won’t work, because SAM conversion is not available and interfaces don’t have constructors.
So there are some drawbacks in readability for the sake of correctness.

### Conclusion

The only conclusion from this article is that one should be pretty attentive when dealing with things where Kotlin and Java touch each other.
