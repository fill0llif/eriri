import java.io {
	File
}
shared interface Mp3PlayerEvent {
	"Song track"
	shared formal File track;
	"When the song track last started playing (in millis)"
	shared formal Integer from;
}
