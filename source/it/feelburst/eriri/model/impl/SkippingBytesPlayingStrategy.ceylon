import com.mpatric.mp3agic {
	Mp3File
}

import it.feelburst.eriri.interop.stream {
	CountingInputStream
}

import java.io {
	File,
	InputStream,
	FileInputStream
}

import javazoom.jl.player.advanced {
	AdvancedPlayer,
	PlaybackEvent
}
shared class SkippingBytesPlayingStrategy(
	shared actual File track)
	satisfies PlayingStrategy {
	
	variable CountingInputStream? trackInputStream = null;
	
	shared actual variable AdvancedPlayer? player = null;
	
	variable Integer toSkip = 0;
	
	variable Integer remaining = 0;
	
	value length = track.length();
	value mp3File = Mp3File(track);
	
	"Track's number of frames"
	shared actual Integer frameCount = mp3File.frameCount;
	"Track's length in secs"
	shared actual Integer trackLength = mp3File.lengthInMilliseconds;
	
	shared actual InputStream createTrackInputStream() {
		value trackInputStream = CountingInputStream(FileInputStream(track));
		trackInputStream.skip(toSkip);
		this.trackInputStream = trackInputStream;
		return trackInputStream;
	}
	
	shared actual void setWhenToResume(
		PlaybackEvent event,
		Integer lastRequested, 
		Integer lastStopped) {
		assert (exists trackInputStream = this.trackInputStream);
		/*
		 WONTFIX even though the stream is skipping the exact bytes read
		 the audio played is still too delayed
		 this probably cannot be solved easily because depends on the
		 track codec used
		 */
		toSkip = trackInputStream.count;
		log.info("playing strategy - skip ``toSkip`` bytes");
		remaining = length - toSkip;
		log.info("playing strategy - remaining ``remaining`` bytes");
	}
	
	"Resume the song track starting from a specific time skipping the preceding bytes"
	shared actual void resume() {
		assert (exists player = this.player);
		player.play(remaining);
	}
	
	shared actual void reset() {
		trackInputStream = null;
		player = null;
		toSkip = 0;
		remaining = 0;
	}
}