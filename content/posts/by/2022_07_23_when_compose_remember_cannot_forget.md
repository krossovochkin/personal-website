+++
title = "Калі Compose remember ня можа забыць"
date = "2022-07-23"
author = "Вася Драбушкоў"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["android"]
keywords = ["android", "compose", "remember"]
description = "Што рабіць калі compose remember ня можа забыць значэнне"
showFullContent = false
+++

[Read in English](../../2022_07_23_when_compose_remember_cannot_forget)

[![](https://img.shields.io/badge/androidweekly-529-blue#badge)](https://androidweekly.net/issues/issue-529)

## Уводзіны

Пры распрацоўцы прыкладання [color-utils](https://krossovochkin.com/apps/color-utils/) з выкарыстаннем Compose для Web я сутыкнуўся з праблемай, што `remember` не хацеў забываць стан. Гэта быў вельмі раздражняльны вопыт, бо я адчуваў сябе па-дурному: Composable функцыя перакампанавана з новым значэннем, але `remember` па-ранейшаму захоўвала старое значэнне.
Як звычайна, ніякай магіі тут няма, і адказ даволі просты, таму гэты артыкул не будзе вельмі доўгі.

Compose - гэта ўсё аб стане. У прыкладанні ў мяне было два ўзроўні стану:

1. "domain" - бягучае значэнне `Color`. Гэты аб'ект адлюстроўвае сапраўдны колер.
2. "ui" - стан некаторых элементаў кіравання (тэкставых палёў), з дапамогай якіх карыстальнік можа змяняць колер. Трэба адзначыць, што бягучы стан карыстальніцкага інтэрфейсу неабавязкова можна пераўтварыць у правільны аб'ект `Color`. Напрыклад, тэкставае поле можа быць пустым - гэта азначае, што карыстальнік знаходзіцца ў працэсе змены значэння колеру, і мы не можам стварыць аб'ект `Color` з несапраўднымі дадзенымі.

Значэнне дамена захоўвалася як зменлівы стан, які можа быць зменены пры змене колеру:

```kotlin
var foregroundColor by remember { mutableStateOf(Color.White) }

ColorPicker(foregroundColor) {
    foregroundColor = it
}
```

Значэнне карыстацкага інтэрфейсу было атрымана з дамена і захавала бягучы стан адпаведнага тэкставага поля. Новае значэнне распаўсюджвалася на ўзровень "дамена" толькі тады, калі яно было сапраўдным:

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

Адзін аб'ект `Color` адпавядае некалькім тэкставым палям, якія змяняюць альфа-узровень, чырвоны, зялёны, сіні і hex значэнні. Кожны раз, калі нейкае значэнне змяняецца на сапраўднае, ствараецца і распаўсюджваецца новы аб'ект `Color`. Змена значэння `Color` запускае рэкампазіцыю ўнутраных Composable функцый з новымі значэннямі, якія змяняюць значэнні тэкставых палёў на новыя.

Праблема заключалася ў тым, што пры такім змене, напрыклад, чырвонага значэння не выклікалася змена ў hex тэксту з новым значэннем, нават калі выклікалася рэкампазіцыя.
Я нават паглядзеў на фактычныя значэнні:

```kotlin
println("${color.hex}, $hex")
```
Пасля таго, як новы колер быў абраны пасля рэкампазіцыі, ён надрукаваў:
```
ffaaffff, ffffffff
```

Такім чынам, функцыя была выклікана з новым значэннем `Color`, але `remember` па-ранейшаму забяспечвала пачатковае значэнне.

Прычына гэтага ў тым, што `remember` запамінае значэнне пры рэкампазіцыі - гэта як асноўная асаблівасць гэтага метаду.
Каб перапісаць запомненае значэнне, нам трэба яўна сказаць `remember` абнавіць значэнне, указаўшы ключ:

```kotlin
public inline fun <T> remember(key1: kotlin.Any?, calculation: @androidx.compose.runtime.DisallowComposableCalls () -> T): T 
```

Пры змене ключа `remember` прыме новае значэнне і запомніць яго.

Такім чынам, калі я дадаў новае значэнне колеру ў якасці ключа, як:

```kotlin
var red: Int? by remember(color) { mutableStateOf(color.red) }
```

Усё пачало працаваць як трэба.

Шчаслівага кадавання!