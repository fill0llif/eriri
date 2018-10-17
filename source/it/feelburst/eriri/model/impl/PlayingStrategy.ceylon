import ceylon.math.decimal {
	decimalNumber
}

import java.io {
	File,
	InputStream
}

import javazoom.jl.player.advanced {
	AdvancedPlayer,
	PlaybackEvent
}
shared interface PlayingStrategy {
	shared formal File track;
	shared formal Integer frameCount;
	shared formal Integer trackLength;
	shared formal variable AdvancedPlayer? player;
	shared formal InputStream createTrackInputStream();
	shared formal void setWhenToResume(
		PlaybackEvent event,
		Integer lastRequested,
		Integer lastStopped);
	shared default void play(Integer from) {
		assert (exists player = this.player);
		player.play(
			decimalNumber(from.float * frameCount / trackLength).integer, 
			frameCount);
	}
	shared formal void resume();
	shared formal void reset();
}