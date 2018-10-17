import java.util.concurrent {
	TimeUnit
}
shared String mmss(Integer millis) =>
	let (mins = TimeUnit.milliseconds.toMinutes(millis))
	let (secs =
		TimeUnit.milliseconds.toSeconds(millis) - 
		TimeUnit.minutes.toSeconds(mins))
	"``mins.string.padLeading(2, '0')``:" +
			"``secs.string.padLeading(2, '0')``";

shared String mmssSSS(Integer millis) =>
	let (mins = TimeUnit.milliseconds.toMinutes(millis))
	let (secs =
		TimeUnit.milliseconds.toSeconds(millis) - 
		TimeUnit.minutes.toSeconds(mins))
	let (mlls = millis - 
		(TimeUnit.minutes.toMillis(mins) + TimeUnit.seconds.toMillis(secs)))
	"``mins.string.padLeading(2, '0')``:" +
			"``secs.string.padLeading(2, '0')``," +
			"``mlls.string.padLeading(3, '0')``";
