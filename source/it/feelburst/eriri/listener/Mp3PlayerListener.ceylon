import it.feelburst.eriri.listener.model {
	Mp3PlayerInstantEvent,
	Mp3PlayerStartedEvent,
	Mp3PlayerStoppedEvent
}
shared interface Mp3PlayerListener {
	shared formal void onPlay(Mp3PlayerStartedEvent event);
	shared formal void onPause(Mp3PlayerStoppedEvent event);
	shared formal void onResume(Mp3PlayerStartedEvent event);
	shared formal void onStop(Mp3PlayerStoppedEvent event);
	shared formal void onComplete(Mp3PlayerStoppedEvent event);
	shared formal void onEverySecondWhilePlaying(Mp3PlayerInstantEvent event);
}