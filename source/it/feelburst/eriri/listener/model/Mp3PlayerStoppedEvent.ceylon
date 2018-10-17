import java.io {
	File
}
"Event notifying the player had paused/stopped playing the song track"
shared class Mp3PlayerStoppedEvent(
	shared actual File track,
	shared actual Integer from,
	"When the song track last stopped playing (in millis)"
	shared Integer to) satisfies Mp3PlayerEvent {}
