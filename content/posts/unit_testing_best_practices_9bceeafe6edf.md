+++
title = "Unit Testing Best Practices"
date = "2020-03-19"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["programming", "unit testing", "unit", "test"]
keywords = []
description = "A list of practical suggestions that can help you write better tests"
showFullContent = false
+++

![[Source](https://unsplash.com/photos/IiEFmIXZWSw)](https://images.unsplash.com/photo-1547637589-f54c34f5d7a4?ixlib=rb-1.2.1&auto=format&fit=crop&w=1357&q=80)*[Source](https://unsplash.com/photos/IiEFmIXZWSw)*

**Disclaimer**: This is a set of things I consider very useful when writing unit tests. I call them *best practices* because they allow me to write good, quality tests that are easier to read, more maintainable, and better describe business needs.

These points might be subjective, you might have other opinions or have more items. That’s fine. Do not hesitate to put your opinions in the comments.

## Tests in the Development Process

Tests are very important in the development process. They give you a lot of benefits:

* Tests validate requirements. This shows you that your implementation correctly solved the problem.

* They identify defects in the early stages. It is always better to find issues earlier as it will be faster and cheaper to fix. Finding a defect during development by writing tests is perfect timing.

* Improve maintainability. To write tests, the source code should be testable, which means that it would be more maintainable. Testable code is usually well-decoupled which adds more readability. This also forces better architecture.

* Make refactoring safer. Tests allow big changes, with validation that no regressions were introduced.

* Helps in code review. As tests clearly show the intention of the author, it is easier to first verify that tests do what the solution should. This will give more insight into what was actually done, making it simpler to review.

## Good Test

We’ll start by defining what can be considered a “good test”.

Usually, a good test is:

* Trustworthy. That means that it fails only if it is broken. If tests can sometimes fail then it is flaky and can’t be called a good test.

* Readable/maintainable. From reading a test, it should be clear what it tests and how it is done. It should have no boilerplate or tricky tweaks of state or control.

* Should verify a single use case. This is related to the single responsibility principle. If a test verifies multiple cases then if it fails, we can’t say why exactly. A good test verifies a single use case and when it fails, we immediately know what went wrong.

* Isolated. The test should not be able to influence other tests. This particularly implies that tests should not share a global state. If tests are not isolated, then the order in which they are executed can lead to unexpected results.

## Best Practices for a Good Test Process

The second set of best practices is about a good test process.

A test process is good if:

### It is automated (on CI)

Tests are only useful if they are executed in a timely manner. The best option is to use continuous integration which will constantly run your tests, for example, on each commit. Otherwise, it is easy to forget to run tests, which makes them useless.

### Tests are written during development, not after

TDD (when you write tests before writing code) is great, but from the beginning, it might not be that easy to foresee what your module should look like, what the structure of the classes will be, and so on.

So, if one can’t write tests first — that’s OK. What is important is to set up tests as early in the development as possible and to not delay them until the end.

The reason is that tests help you to write clean code. Separate concerns, use interfaces to hide implementation details or some platform-specifics. If you delay writing tests, you can find yourself in a position where some code is not testable and it would be very tempting to hack it around.

### **Tests are added for each defect/case found**

When write tests, you don’t need to take care of all the situations that might theoretically happen (we’ll talk about it in detail below).

The most important thing is to reflect business use cases and add tests continuously for any other requirement or defect found. Especially for defects. Because this way, you can verify before fixing that there is a case failing and check that after the fix, the test actually passed.

## Testing Best Practices

These were some theoretical practices that are general to writing unit tests. They are good to get a general feeling about the test process.

In this article though, I’d like to go more into some practical points which might make your tests better.

### Write a good test name

It should describe what is under test, under what conditions the test happens, and what is expected as a test result.

If there is a test case for a given test, provide a link to it in a test Javadoc.
If the test name becomes big, use abbreviations. Describe the meaning of abbreviations in the test Javadoc.

A bad test name makes it less maintainable.

### Test the public interface

Everything that is not public should not be tested.

Do not break encapsulation (by providing [@VisibleForTesting](http://twitter.com/VisibleForTesting) or something like that) to test a functionality.

If there is a method you’d like to test thoroughly and separately, that means that it most likely should be part of a public interface of some other class (or utility method, or extension).

Each class under test should have a public interface (to make it explicit what should be tested).

Testing non-public stuff makes a test less-maintainable. Breaking encapsulation ruins architecture.

### Verify one use case per test

A test should check one thing. Particularly, that means that each test should have only one assertion.

There are exceptions here though: if you want to check that a set up for a test was actually set correctly then you can use assumed checks.

If you want to verify what methods in mocks were called (or not called) during the test, then it is fine to have multiple verifications.
Though for assertions it is important to assert only once per test.

Testing multiple things in a single test doesn’t allow you, when such a test fails, to clearly say why exactly it failed.

### Group the test body into logical sections

In the case of a simple unit test that asserts on returning a value, there should be a section with setup and a section with assertion.

In the case of a complex test (closer to an integration test), there should be a setup section (given), a trigger section (when), and a result section (then).

A test with no logical grouping essentially is more difficult to read, therefore, it is less-maintainable.

### Use dependency inversion

Provide dependencies to classes under test in the constructor or via the public interface. Do not create some third-party dependencies inside the class. Don’t get a singleton instance from inside the class.

Wrap some system/platform classes with your own interfaces and provide these interfaces instead of real platform classes as a dependency. This includes providing the interface to work with calendar/time.

Not using DI makes your code less testable.

### Mocks vs. stubs

Use real classes where possible. If that is not possible, then provide a stub. If providing a stub is not possible, provide a mock.

That usually translates into that entities and value objects should be real, some first-party services should be either real or stubbed, third-party services should be stubs or mocks.

Excessive usage of mocks in tests might lead to you testing the mock implementation and not the actual implementation.

### Entity/value object default builders

When using real classes for entities or value objects, it is handy to have builders with default values to construct them.

Basically, it would be a default implementation of the entity/value object, in which one can change properties that are important for a given test.

Not having such builders leads to code duplication and makes tests less maintainable.

### Group tests that are coupled into sub-classes

Create an abstract base test class with a common setup and extend it with sub-classes that test a particular part of the functionality.

This will group tightly coupled test cases in one place. This way, it is possible to extract part of the test names (the repeating part) into an enclosing class name.

Having all the tests inside a single class reduces readability.

### The initial state for tests should be generated via the public API of the class under test and its dependencies only

There should be no internal modifications of classes to make a test setup. No @VisibleForTesting with breaking encapsulation.

Changing the internal state via a non-public API might create an impossible case. Also, it breaks encapsulation.

### Set up tests early

Write a few tests that cover basic functionality. Add more tests over time when the architecture establishes itself and more information is learned.

Writing a lot of tests early on requires skill (if going with TDD). TDD is great but without enough experience, one might need to re-write tests quite a lot of times when the structure changes significantly.

Postponing writing tests until the end of development might lead to non-testable code.

## Conclusion

Writing tests is not an easy task. It requires discipline.

Also, tests are also code, which should be written with that same care as your general production code. But, when you invest time into tests then over time, you gain more and more value from them.

Don’t fear writing tests. Do not wait. Start today. And keep working on tests.

Happy coding!
