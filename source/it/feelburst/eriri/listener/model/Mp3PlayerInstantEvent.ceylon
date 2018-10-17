import java.io {

	File
}
"Event notifying a specific song track time during the playing song track"
shared class Mp3PlayerInstantEvent(
	shared actual File track,
	shared actual Integer from,
	"Specific song track time"
	shared Integer instant) satisfies Mp3PlayerEvent {}
