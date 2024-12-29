+++
title = "Card Soccer"
date = "2022-07-10"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["app"]
keywords = ["app", "card", "soccer"]
description = ""
showFullContent = false
+++

<iframe width="275px" height="600px" src="../../applications/card-soccer/index.html" style="margin: 0 auto; display: block;"></iframe>

### How to play

The goal of the game is to win AI opponent by scoring more goals.  
The game is turn based.  
On your turn you should move the "ball" (card opened from your deck) to opponents goal.  
You start from the row that is close to your goal: you should select a card in a row and if it matches by value or suite - proceed to the next row up until the opponent's goal.  
If there is no match - your turn is over.  
You can select opened and closed cards.  
If the whole row is opened - you can skip it and procced to the next one.
You score when your "ball" matches opponent goal.  

Use short passes, long passes or even long shots on target to smash your opponent!


### Background

In the childhood I loved soccer a lot (now I don't). FIFA 2002 was probably the first championship I followed from the beginning till the end and it was amazing. I still have newspaper clippings from that times.  
With my friend we played in the card soccer, we completed the whole championship tracking results. And Algeria was a card soccer champion :)  
So many years later I decided to develop that game so that somebody might wish to try it out.  
The game is insanely random, so there is no chance to have a guaranteed win, but there are some strategies and tactics.  
I have hard times working with web, so for this I used kotlin multiplatform along with jetpack compose ui to develop first desktop version and then port it to the web.  

[Sources](https://github.com/krossovochkin/krossovochkin-web-apps/tree/main/apps/card-soccer)
