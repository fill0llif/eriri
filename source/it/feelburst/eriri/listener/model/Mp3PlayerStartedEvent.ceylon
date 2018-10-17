import java.io {
	File
}
"Event notifying the player had started playing the song track"
shared class Mp3PlayerStartedEvent(
	shared default actual File track,
	shared default actual Integer from) satisfies Mp3PlayerEvent {}