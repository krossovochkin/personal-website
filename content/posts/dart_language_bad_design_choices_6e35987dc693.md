+++
title = "Dart language bad design choices"
date = "2019-04-08"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["dart"]
keywords = []
description = ""
showFullContent = false
+++

Source: https://www.dartlang.org/assets/shared/dart-logo-for-shares.png?2

> [![](https://img.shields.io/badge/original-medium-green)](https://medium.com/@krossovochkin/dart-language-bad-design-choices-6e35987dc693)

## Introduction

Before raising a point about some design choices we need to define some criteria.

1. Intent/Declaration > Usage/Implementation
Code one write should clearly state the intent. 
Implementation is not that important than an intent.

1. Implicit is bad
Implicit things do not share the intention, therefore from the first point it means that any implicit thing hides true intent.
If anything hides intention — it can be considered bad.

1. Mixing different things together is bad.
Partially it relates to the first point about intention.
If you do the change and it is not clear whether it is because of one thing or another (which are mixed into one) — then intention is hidden and it is bad.

Now let’s look at some design choices in Dart language and think whether they hide developer’s intent or they can be considered good.

## Visibility modifiers
> The import and library directives can help you create a modular and shareable code base. Libraries not only provide APIs, but are a unit of privacy: identifiers that start with an underscore (_) are visible only inside the library.
[Reference](https://www.dartlang.org/guides/language/language-tour#libraries-and-visibility)

Basically in Dart each file is a library.
And effectively that means that in Dart there are only two visibility modifiers:

* Visible everywhere (i.e. public)

* Visible in library/file only (hereinafter when I use *library*, I will also mean *file*)

There is no private in class. There is no protected.
One can emulate private in class by using private-in-library with only one class in library.
One can emulate protected by having both parent and child class in one file and using private-in-library.

If you want to have one property private-in-class and another protected… Bad luck. This is not what Dart is about.
> **Note**: visibility modifiers are designed that way because of performance and usage of **dynamic **(will discuss it later in the article).
The question is: whether **dynamic* ***feature is so great to have lack in visibility modifiers?
[Reference](https://github.com/dart-lang/sdk/issues/33383)

But not having some of the common visibility modifiers is not the only issue about them in Dart. As said before there are only two visibility modifiers (public and private-in-library).
And to distinguish them one should use _ (underscore):

* **property/function() **— is a public property/function

* **_property/_function() **— is a private-in-library property/function

“Clever solution” to distinguish two different cases. But it comes with a price:

* If later on designers of language decide to add more visibility modifiers — it would be difficult.

* If you want to change visibility for some property/function you have to make *rename *refactoring.

Here the issue is that visibility modifier is mixed with name of property/function.
Mixing different things is bad.
If you want to change visibility of property you should be able to change visibility.
If you want to change property name you should be able to change property name.
If you want to change visibility of property you should not be forced to change property name (including all occurrences of usage of that property).

Dart is not good at it.
Though again it was done because of the *dynamic *feature (see link above).

## Implicit returns
> All functions return a value. If no return value is specified, the statement return null; is implicitly appended to the function body.
[Reference](https://www.dartlang.org/guides/language/language-tour#return-values)

Implicit is bad.

I can’t say much about this.
Just that language, which doesn’t really tries to protect you from NullPointerException issues, and instead provides you a way to face it if you made a mistake with missing return value, looks like a weird one.

**Suggestion:** One should setup lint to catch missing returns. And in each place where return null; was intentional, just put it explicitly.
> **Note**: This implicit feature becomes even more weird when it comes to using void. You can read this [article ](https://medium.com/flutter-community/the-curious-case-of-void-in-dart-f0535705e529)to get more inside.

## Implicit interfaces
> Every class implicitly defines an interface containing all the instance members of the class and of any interfaces it implements.
[Reference](https://www.dartlang.org/guides/language/language-tour#implicit-interfaces)

Implicit is bad.
Intent/Declaration > Usage/Implementation

Dart has no *interface *keyword.
You can’t declare interface in Dart.
I see this as a major issue. Interface > Implementation.
The only way to emulate interface in Dart is to create abstract class.

That means that in Dart abstract class is mixed with interface.
Mixing different things together is bad.

Instead of having interfaces and abstract classes separate Dart designers decided to have different ways to extend classes.
You can use keyword *extend *and it will work as usual.
You can use keyword *implements *and in such case you will implement **implicit **interface some class defines.
> **Note**: additionally you can add more functionality with mixin feature of Dart. This is questionable feature, which is similar to interfaces with default functions in Java (with some differences, of course).
I’ll omit discussing mixins here as it is quite a big topic.
Read [this article](https://medium.com/flutter-community/dart-what-are-mixins-3a72344011f3) as some quick dive in.

That means that if you add some public property to a class it immediately becomes part of that class interface.
And keeping in mind private-in-library feature, if you add **any** property to a class it immediately becomes part of that class interface inside library.
Therefore class has different implicit interfaces inside and outside of library.

**Suggestion: **create explicit interfaces. Even considering Dart doesn’t support them.
Create abstract classes with public-only properties/functions in a separate file (to ensure you’re not clashing with private-in-library features).
> **Note:** Interface keyword was removed intentionally
[Reference](https://news.dartlang.org/2012/06/proposal-to-eliminate-interface.html)

## Functions first-class support
> Dart is a true object-oriented language, so even functions are objects and have a type, [Function.](https://api.dartlang.org/stable/dart-core/Function-class.html) This means that functions can be assigned to variables or passed as arguments to other functions.
[Reference](https://www.dartlang.org/guides/language/language-tour#functions)
> **UPDATE**: as pointed in [the comment](https://medium.com/@jamesdlin/the-part-about-function-applies-only-if-you-dont-specify-return-types-or-parameter-types-cd5d7a454ca2) this part of the article is actually wrong as it is possible to add type information to function.
Wherever possible use functions with explicit information.

It is great that Dart has first-class support for functions.
It is bad that Function has no information about parameters and return types.

In general function can be represented as a class with one function.
Classes can be of generic types as functions can. But Function in Dart has no type information (as dynamic feature we’ll look at later).

That means that compiler doesn’t help you if you provide wrong number of arguments, incorrect argument types or return wrong type (or null).

**Suggestion**: Do not use Function in Dart. Try to use explicit interfaces. This can save you from weird issues at runtime.

## Dynamic

Feature of the language which it seems made other design choices required.

In any object-oriented programming language there is a basic type. In Java it is Object, in Kotlin it is Any, in Dart it is **dynamic**.
The difference is that in Java/Kotlin base type has limited number of supported methods (and if you would like to call some method which is not part of base type interface you have to make a downcast first), but in Dart on dynamic type one can call any property/function by name.
That means that code like this is purely valid (for true/false value passed to a function):

```dart
void main() {
  dynamic c = get(false);
  print(c.a());
}

dynamic get(bool flag) {
  if (flag) {
    return A();
  } else {
    return B();
  }
}

class A {
  
  dynamic a() {
    return "a";
  }
}

class B {
  
  dynamic a() {
    return "b";
  }
}
```

This means that Dart is more like JavaScript and is less like Java.

When you decide to have more dynamic things than statically typed things (which can be verified by compiler), you will get JavaScript-like language.

Considering that in web development TypeScript with some types support is favorited by developers more than vanilla JavaScript is not a surprise.
Developers like to delegate some checks to tests and compiler because it allows to concentrate on what matters.

Direction Dart pointed to might be understandable, though not looking as a modern language.

Also not making compiler do many checks during compilation allows Flutter to have hot-reload feature, as re-compilation is pretty fast (as compiler seems not doing many of checks).

Though if one asked me whether I’d like to have issues in runtime with fast compilation or being able to catch issues at compile time, I’d for sure choose the second one.

**Suggestion:** avoid using *dynamic*. Use explicit interfaces instead.

## Bonus. Dart type system.
> A sound *type system* means you can never get into a state where an expression evaluates to a value that doesn’t match the expression’s static type. For example, if an expression’s static type is String, at runtime you are guaranteed to only get a string when you evaluate it.
Dart’s type system, like the type systems in Java and C#, is sound.
[Reference](https://www.dartlang.org/guides/language/sound-dart#what-is-soundness)

Let’s create simple test:

```dart
void main() {
  String s = null;
  if (s is String) {
    print("string");
  } else if (s is Null) {
    print("null");
  } else {
    print ("none");
  }
}
```

We assign null (which is instance of Null class: [Reference](https://api.dartlang.org/stable/2.2.0/dart-core/Null-class.html)) to a String variable.
As stated in documentation each expression can return only value of expected static type.
In an example above we expect value to be of type String, but program will print “null”.

As Null is a type in Dart and Null is not a String, but we can assign null to String variable without errors even in runtime – there is inconsistency in Dart type system.

This and another case with *void, *which also behaves in a special way, looks like Dart type system is not stable enough (and therefore designed poorly).

Happy coding.
