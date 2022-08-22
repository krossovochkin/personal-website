+++
title = "When Compose remember cannot forget"
date = "2022-07-23"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["android"]
keywords = ["android", "compose", "remember"]
description = "What to do if compose remember cannot forget the value"
showFullContent = false
+++

[Чытаць на беларускай мове](../by/2022_07_23_when_compose_remember_cannot_forget)

[![](https://img.shields.io/badge/androidweekly-529-blue#badge)](https://androidweekly.net/issues/issue-529)

## Introduction

When developing [color-utils](https://krossovochkin.com/apps/color-utils/) app using Compose for Web I faced an issue that `remember` didn't want to forget the state. It was quite annoying experience as it felt stupid: composable function is recomposed with the new value provided but `remember` still kept old value.   
As usual, there is no magic there and the answer is quite simple therefore this article won't be that long.  

Compose is all about state. In the app I had two levels of state:

1. "domain" - current `Color` value. This object represents actual color.
2. "ui" - state of some controls (text fields) using which user is able to modify the color. Need to note that current UI state doesn't necessarily can be converted into correct `Color` object. For example, text field can be empty - that means that user is in process of modifying color value and we cannot create the `Color` object with not valid data.

Domain value was kept as a mutable state that can be mutated when color is changed:

```kotlin
var foregroundColor by remember { mutableStateOf(Color.White) }

ColorPicker(foregroundColor) {
    foregroundColor = it
}
```

UI value was derived from domain and kept current state of the corresponding text field. New value was propagated to "domain" level only when it was valid:

```kotlin
var red: Int? by remember { mutableStateOf(color.red) }

Input(InputType.Number) {
    value(value ?: Double.NaN)
    style {
        onInput {
            val validated = validateRgbValue(it.value)
            red = validated
            if (validated != null) {
                onChanged(color.copy().apply { this.red = validated })
            }
        }
    }
}
```

Single `Color` object corresponds to multiple text fields that change alpha, red, green, blue and hex values. Whenever some value is changed to a valid value new `Color` object is created and propagated up. Changing of the `Color` value triggers recomposion of inner composables with new values changing text fields' values to a new ones.  

The issue was that with such a code changing e.g. red value didn't trigger hex text input with the new value even though recomposition was called.  
I even looked at the actual values provided:

```kotlin
println("${color.hex}, $hex")
```
After new color is picked after recomposition it printed:
```
ffaaffff, ffffffff
```

So, function was called with the new `Color` value but `remember` still provided initial value.  

The reason of that is that `remember` remembers value across recompositions - this is like the core feature of that method.  
In order to re-write remembered value we need to explicitly tell `remember` to update the value by providing the key:

```kotlin
public inline fun <T> remember(key1: kotlin.Any?, calculation: @androidx.compose.runtime.DisallowComposableCalls () -> T): T 
```

When the key is changed `remember` will take new value and remember it.

So, when I added new color value as a key like this:

```kotlin
var red: Int? by remember(color) { mutableStateOf(color.red) }
```

Everything started working as needed.

Happy coding!
