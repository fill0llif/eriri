# Eriri 英梨々
_Eriri_ is a basic mp3 player that provides _play_, _pause_, _resume_ and _stop_ functions. It comes with a basic listener model too (which differentiates between _onStop_ and _onComplete_).

_Eriri_ is written in [Ceylon](https://ceylon-lang.org) and uses Spring, [JAVAZOOM jLayer](http://www.javazoom.net/javalayer/javalayer.html) and [mp3agic](https://github.com/mpatric/mp3agic).

# Building

	ceylon compile --flat-classpath --fully-export-maven-dependencies
	
## Getting started

You just need to add this declaration to your Ceylon module:

```ceylon
import it.feelburst.eriri "1.0.1";
```
