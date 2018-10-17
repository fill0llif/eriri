import it.feelburst.eriri.listener {
	Mp3PlayerListener
}
import java.util.concurrent {

	Future
}
import java.io {

	File
}
shared interface Mp3Player {
	"The song track being played"
	shared formal File track;
	"Asynchronously test whether the song track is playing"
	shared formal Boolean playing;
	"Asynchronously test whether the song track is paused"
	shared formal Boolean paused;
	"Asynchronously test whether the song track is stopped"
	shared formal Boolean stopped;
	"Asynchronously test whether the player is finalized"
	shared formal Boolean finalized;
	"Asynchronously get current instant (in millis)"
	shared formal Integer now;
	"Asynchronously get when the song track last paused (in millis)"
	shared formal Integer lastPaused;
	"Asynchronously play the song track starting from a specific time (in millis).
	 The future returned specifies if the request has been processed or not."
	shared formal Future<Boolean> play(Integer from = 0);
	"Asynchronously resume the song track.
	 The future returned specifies if the request has been processed or not."
	shared formal Future<Boolean> resume();
	"Asynchronously pause the song track.
	 The future returned specifies if the request has been processed or not."
	shared formal Future<Boolean> pause();
	"Asynchronously stop the song track.
	 The future returned specifies if the request has been processed or not."
	shared formal Future<Boolean> stop();
	"Add mp3 player listener"
	shared formal void addMp3PlayerListener(Mp3PlayerListener listener);
	"Remove mp3 player listener"
	shared formal void removeMp3PlayerListener(Mp3PlayerListener listener);
	"Finalize the player before discarding it (waiting for the player to close)"
	shared formal void finalize();
}