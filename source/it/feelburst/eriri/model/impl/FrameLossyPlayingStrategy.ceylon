import com.mpatric.mp3agic {
	Mp3File
}

import java.io {
	File,
	FileInputStream,
	InputStream
}

import javazoom.jl.player.advanced {
	AdvancedPlayer,
	PlaybackEvent
}
"Frame lossy resuming strategy.
 The reason for it being lossy it's that it jumps to specific frame which
 is evaluated each time from the number of frames and the length in seconds of the track
 when requested"
shared class FrameLossyPlayingStrategy(
	shared actual File track)
	satisfies PlayingStrategy {
	
	variable Integer whenToResume = 0;
	
	shared actual variable AdvancedPlayer? player = null;
	
	value mp3File = Mp3File(track);
	
	"Track's number of frames"
	shared actual Integer frameCount = mp3File.frameCount;
	"Track's length in secs"
	shared actual Integer trackLength = mp3File.lengthInMilliseconds;
	
	shared actual InputStream createTrackInputStream() =>
		FileInputStream(track);
	
	shared actual void setWhenToResume(
		PlaybackEvent event,
		Integer lastRequested, 
		Integer lastStopped) =>
		whenToResume = lastStopped;
	
	"Resume the song track starting from a specific time in millis"
	shared actual void resume() =>
		play(whenToResume);
	
	shared actual void reset() {
		whenToResume = 0;
		player = null;
	}
}
