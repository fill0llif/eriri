import ceylon.collection {
	HashSet
}

import it.feelburst.eriri.interop.concurrent {
	Lock,
	JoinedListenableFutureTask
}
import it.feelburst.eriri.interop.format {
	mmssSSS
}
import it.feelburst.eriri.listener {
	Mp3PlayerListener
}
import it.feelburst.eriri.listener.model {
	Mp3PlayerInstantEvent,
	Mp3PlayerStartedEvent,
	Mp3PlayerStoppedEvent
}
import it.feelburst.eriri.model {
	Mp3Player
}

import java.io {
	File
}
import java.lang {
	volatile,
	Thread
}
import java.util {
	ArrayDeque
}
import java.util.concurrent {
	Executors,
	TimeUnit,
	ScheduledFuture,
	Future,
	CompletableFuture
}
import java.util.concurrent.locks {
	Condition
}

import javazoom.jl.player.advanced {
	PlaybackListener,
	AdvancedPlayer,
	PlaybackEvent
}

import org.springframework.util.concurrent {
	ListenableFutureTask
}

"Song track's state"
abstract class State(String name)
	of playing | paused | stopped | evaluating | finalized {
	shared actual String string =>
		name;
}
object playing extends State("playing") {}
object paused extends State("paused") {}
object stopped extends State("stopped") {}
object evaluating extends State("evaluating") {}
object finalized extends State("finalized") {}

abstract class Request(String name)
	of play | pause | resume | stop | finalize {
	shared actual String string =>
		name;
}
object play extends Request("play") {}
object pause extends Request("pause") {}
object resume extends Request("resume") {}
object stop extends Request("stop") {}
object finalize extends Request("finalize") {}

"Player that can play (at a specific time), pause, resume or stop a mp3 song track."
shared class Mp3PlayerImpl(
	shared actual File track,
	PlayingStrategy playingStrategy = FrameLossyPlayingStrategy(track))
	satisfies Mp3Player {
	"Player impl (JavaZOOM JLayer)"
	variable AdvancedPlayer? playerInternal = null;
	"Track state"
	variable volatile State state = package.stopped;
	"When track last started playing in unix time (millis)"
	variable Integer lastUnixStarted = 0;
	"When track last stopped playing in unix time (millis)"
	variable Integer lastUnixStopped = 0;
	"Starting instant requested to play in millis"
	variable Integer firstRequested = 0;
	"Last starting instant requested to play in millis"
	variable Integer lastRequested = 0;
	
	variable {Integer*} intervals = [];
	
	"To ensure updates are queued"
	value executor = Executors.newCachedThreadPool();
	value updateExecutor = Executors.newSingleThreadExecutor();
	value periodicExecutor = Executors.newScheduledThreadPool(1);
	value updateRequests = ArrayDeque<Request?>();
	
	value pausedLock = Lock();
	value isPaused = pausedLock.newCondition();
	value stoppedLock = Lock();
	value isStopped = stoppedLock.newCondition();
	value updateLock = Lock();
	value updated = updateLock.newCondition();
	value finalizeLock = Lock();
	value canFinalize = finalizeLock.newCondition();
	
	value listeners = HashSet<Mp3PlayerListener>();
	
	"Track's length in millis"
	value trackLength = playingStrategy.trackLength;
	
	variable ScheduledFuture<out Object>? everySecondWhilePlayingFuture = null;
	
	shared actual Boolean playing =>
		state == package.playing;
	
	shared actual Boolean paused =>
		state == package.paused;
	
	shared actual Boolean stopped =>
		state == package.stopped;
	
	Boolean evaluating =>
		state == package.evaluating;
	
	shared actual Boolean finalized =>
		state == package.finalized;
	
	Integer until(Integer unixTime) =>
		firstRequested + 
		intervals.fold(0)(plus) + 
		(if (lastUnixStopped == 0) then unixTime - lastUnixStarted else 0);
	
	shared actual Integer now =>
		let (now = system.milliseconds)
		until(now);
	
	shared actual Integer lastPaused =>
		until(lastUnixStopped);

	AdvancedPlayer createPlayer(Integer from) {
		value player = AdvancedPlayer(playingStrategy.createTrackInputStream());
		player.playBackListener = object extends PlaybackListener() {
			shared actual void playbackStarted(PlaybackEvent evt) {
				if (intervals.empty) {
					firstRequested = from;
				}
				lastRequested = from;
				lastUnixStarted = system.milliseconds;
				log.debug("Start playing at ``mmssSSS(lastRequested)``.");
				everySecondWhilePlayingFuture = periodicExecutor.scheduleAtFixedRate(() =>
					listeners.each((Mp3PlayerListener listener) =>
						listener.onEverySecondWhilePlaying(Mp3PlayerInstantEvent(
						track, 
						lastRequested, 
						now))), 
					0, 1, TimeUnit.seconds);
			}
			shared actual void playbackFinished(PlaybackEvent evt) {
				lastUnixStopped = system.milliseconds;
				intervals = intervals.follow(lastUnixStopped - lastUnixStarted);
				value lastStopped = lastPaused;
				log.debug("Stop playing at ``mmssSSS(lastStopped)``.");
				assert (exists evrtScndWhlPlyFtr = everySecondWhilePlayingFuture);
				evrtScndWhlPlyFtr.cancel(false);
				playingStrategy.setWhenToResume(evt,lastRequested,lastStopped);
			}
		};
		return player;
	}
	
	ListenableFutureTask<Boolean> createAwaiting(Lock lock,Condition condition) =>
		ListenableFutureTask<Boolean>(() {
			try (lock) {
				log.debug("Awaiting condition.");
				value awaited = condition.await(200, TimeUnit.milliseconds);
				log.debug("Awaited '``awaited``'.");
				return awaited;
			}
		});
		
	void updateState(
		Boolean awaitedPaused,
		Boolean awaitedStopped) {
		updateExecutor.execute(() {
			if (awaitedPaused) {
				state  = package.paused;
				this.playerInternal = null;
				log.info("Song track '``track.name``' paused at ``mmssSSS(lastPaused)``.");
				listeners.each((Mp3PlayerListener listener) =>
					listener.onPause(Mp3PlayerStoppedEvent(track, lastRequested, lastPaused)));
				lastUnixStarted = 0;
				lastUnixStopped = 0;
			}
			else if (awaitedStopped) {
				state = package.stopped;
				this.playerInternal = null;
				value lastStopped = until(lastUnixStopped);
				log.info("Song track '``track.name``' stopped at ``mmssSSS(lastStopped)``.");
				listeners.each((Mp3PlayerListener listener) =>
					listener.onStop(Mp3PlayerStoppedEvent(track, lastRequested, lastStopped)));
				updateRequests.clear();
				lastUnixStarted = 0;
				lastUnixStopped = 0;
				firstRequested = 0;
				lastRequested = 0;
				intervals = [];
				playingStrategy.reset();
				try (finalizeLock) {
					canFinalize.signal();
				}
			}
			else {
				assert (exists player = this.playerInternal);
				player.close();
				state = package.stopped;
				this.playerInternal = null;
				value lastStopped = until(lastUnixStopped);
				log.info("Song track '``track.name``' completed.");
				listeners.each((Mp3PlayerListener listener) =>
					listener.onComplete(Mp3PlayerStoppedEvent(track, lastRequested, lastStopped)));
				updateRequests.clear();
				lastUnixStarted = 0;
				lastUnixStopped = 0;
				firstRequested = 0;
				lastRequested = 0;
				intervals = [];
				playingStrategy.reset();
				try (finalizeLock) {
					canFinalize.signal();
				}
			}
		});
	}
	
	Boolean follows(Request request) =>
		let (lastRequest = updateRequests.peekLast())
		!(if (exists lastRequest) then lastRequest != request else true);
	
	void playInternal(
		Integer from,
		void play(Integer from),
		void onPlayInternal(Mp3PlayerListener listener,Mp3PlayerStartedEvent event)) {
		executor.submit(() {
			listeners.each((Mp3PlayerListener listener) =>
				onPlayInternal(listener,Mp3PlayerStartedEvent(track, from)));
			
			state = package.playing;
			
			play(from);
			
			log.debug("Stopped.");
			
			state = package.evaluating;
			
			value awaitingPaused = createAwaiting(pausedLock,isPaused);
			value awaitingStopped = createAwaiting(stoppedLock,isStopped);
			value awaitingBoth = JoinedListenableFutureTask(awaitingPaused,awaitingStopped);
			{awaitingBoth,awaitingPaused,awaitingStopped}
			.each((
				ListenableFutureTask<Boolean>|
				JoinedListenableFutureTask<Boolean,Boolean> awaiting) {
				executor.submit(awaiting);
			});
			
			Thread.sleep(100);
			
			try (updateLock) {
				updated.signal();
				log.debug("Update signaled.");
			}
			
			value awaitedBoth = awaitingBoth.get();
			value awaitedPaused = awaitedBoth[0];
			log.debug("Awaited paused = '``awaitedPaused``'.");
			value awaitedStopped = awaitedBoth[1];
			log.debug("Awaited stopped = '``awaitedStopped``'.");
			
			updateState(awaitedPaused,awaitedStopped);
		});
	}

	shared actual Future<Boolean> play(Integer from) {
		if (!finalized) {
			if (from < trackLength) {
				if (!evaluating) {
					value playProcessed = CompletableFuture<Boolean>();
					updateExecutor.execute(() {
						value playRequest = package.play;
						if (!follows(playRequest)) {
							if (stopped) {
								updateRequests.offer(playRequest);
								value player = createPlayer(from);
								this.playerInternal = player;
								this.playingStrategy.player = player;
								log.info("Song track '``track.name``' played at ``mmssSSS(from)``.");
								playInternal(
									from,
									(Integer from) =>
										playingStrategy.play(from),
									(Mp3PlayerListener listener,Mp3PlayerStartedEvent event) =>
										listener.onPlay(event));
								playProcessed.complete(true);
							}
							else {
								log.error(
									"Track cannot be played. It must be either not started yet or already stopped. " +
									"If you want to resume the track just resume it, " + 
									"otherwise stop it and then play it again.");
								playProcessed.complete(false);
							}
						}
						else {
							log.warn("Request '``playRequest``' failed because duplicated.");
							playProcessed.complete(false);
						}
					});
					return playProcessed;
				}
				else {
					log.warn("Track cannot be played. Player is in an inconsistent state.");
					return CompletableFuture.completedFuture(false);
				}
			}
			else {
				log.error(
					"Track cannot be played. Cannot start at requested time because greater than track's length.");
				return CompletableFuture.completedFuture(false);
			}
		}
		else {
			log.warn("Track cannot be played. Player is already finalized.");
			return CompletableFuture.completedFuture(false);
		}
	}
	
	shared actual Future<Boolean> resume() {
		if (!finalized) {
			if (!evaluating) {
				value resumeProcessed = CompletableFuture<Boolean>();
				updateExecutor.execute(() {
					value resumeRequest = package.resume;
					if (!follows(resumeRequest)) {
						if (paused) {
							updateRequests.offer(resumeRequest);
							value from = lastPaused;
							value player = createPlayer(from);
							this.playerInternal = player;
							this.playingStrategy.player = player;
							log.info("Song track '``track.name``' resumed at ``mmssSSS(from)``.");
							playInternal(
								from,
								(Integer from) =>
									playingStrategy.resume(),
								(Mp3PlayerListener listener,Mp3PlayerStartedEvent event) =>
									listener.onResume(event));
							resumeProcessed.complete(true);
						}
						else {
							log.error(
								"Track cannot be resumed. It is either not started yet, " +
										"actually playing or already stopped.");
							resumeProcessed.complete(false);
						}
					}
					else {
						log.warn("Request '``resumeRequest``' failed because duplicated.");
						resumeProcessed.complete(false);
					}
				});
				return resumeProcessed;
			}
			else {
				log.warn("Track cannot be resumed. Player is in an inconsistent state.");
				return CompletableFuture.completedFuture(false);
			}
		}
		else {
			log.warn("Track cannot be resumed. Player is already finalized.");
			return CompletableFuture.completedFuture(false);
		}
	}
	
	shared actual Future<Boolean> pause() {
		if (!finalized) {
			if (!evaluating) {
				value pauseProcessed = CompletableFuture<Boolean>();
				updateExecutor.execute(() {
					value pauseRequest = package.pause;
					if (!follows(pauseRequest)) {
						if (playing) {
							updateRequests.offer(pauseRequest);
							assert (exists player = this.playerInternal);
							player.stop();
							try (updateLock) {
								log.debug("Wait for update signal.");
								updated.await();
							}
							try (pausedLock) {
								log.debug("Paused signaled.");
								isPaused.signal();
							}
							pauseProcessed.complete(true);
						}
						else {
							log.error(
								"Track cannot be paused. It isn't actually playing ('``state``').");
							pauseProcessed.complete(false);
						}
					}
					else {
						log.warn("Request '``pauseRequest``' failed because duplicated.");
						pauseProcessed.complete(false);
					}
				});
				return pauseProcessed;
			}
			else {
				log.warn("Track cannot be paused. Player is in an inconsistent state.");
				return CompletableFuture.completedFuture(false);
			}
		}
		else {
			log.warn("Track cannot be paused. Player is already finalized.");
			return CompletableFuture.completedFuture(false);
		}
	}
	
	shared actual Future<Boolean> stop() {
		if (!finalized) {
			if (!evaluating) {
				value stopProcessed = CompletableFuture<Boolean>();
				updateExecutor.execute(() {
					value stopRequest = package.stop;
					if (!follows(stopRequest)) {
						if (playing) {
							updateRequests.offer(stopRequest);
							assert (exists player = this.playerInternal);
							player.stop();
							try (updateLock) {
								log.debug("Wait for update signal.");
								updated.await();
							}
							try (stoppedLock) {
								log.debug("Stopped signaled.");
								isStopped.signal();
							}
							stopProcessed.complete(true);
						}
						else if (paused) {
							state = package.stopped;
							value lastStopped = until(lastUnixStopped);
							log.info("Song track '``track.name``' stopped at ``mmssSSS(lastStopped)``.");
							listeners.each((Mp3PlayerListener listener) =>
								listener.onStop(Mp3PlayerStoppedEvent(track, firstRequested, lastStopped)));
							updateRequests.clear();
							lastUnixStarted = 0;
							lastUnixStopped = 0;
							firstRequested = 0;
							lastRequested = 0;
							intervals = [];
							playingStrategy.reset();
							stopProcessed.complete(true);
							try (finalizeLock) {
								canFinalize.signal();
							}
						}
						else {
							log.warn("Track cannot be stopped. It already is.");
							stopProcessed.complete(false);
						}
					}
					else {
						log.warn("Request '``stopRequest``' failed because duplicated.");
						stopProcessed.complete(false);
					}
				});
				return stopProcessed;
			}
			else {
				log.warn("Track cannot be stopped. Player is in an inconsistent state.");
				return CompletableFuture.completedFuture(false);
			}
		}
		else {
			log.warn("Track cannot be stopped. Player is already finalized.");
			return CompletableFuture.completedFuture(false);
		}
	}
	
	shared actual void addMp3PlayerListener(Mp3PlayerListener listener) =>
		listeners.add(listener);
	
	shared actual void removeMp3PlayerListener(Mp3PlayerListener listener) =>
		listeners.remove(listener);
	
	Boolean awaitedToFinalize() {
		try (finalizeLock) {
			value awaited = canFinalize.await(1000, TimeUnit.milliseconds);
			return awaited || !package.play in updateRequests;
		}
	}
	
	shared actual void finalize() {
		if (!finalized) {
			if (!evaluating) {
				log.info("Try waiting for player to stop...");
				if (awaitedToFinalize()) {
					state = package.finalized;
					log.info("Finalizing resources...");
					updateExecutor.shutdown();
					executor.shutdown();
					periodicExecutor.shutdown();
					log.info("Resources finalized.");
				}
				else {
					log.error("Player cannot be finalized. Player hasn't been stopped accordingly.");
				}
			}
			else {
				log.warn("Player cannot be finalized. Player is in an inconsistent state.");
			}
		}
		else {
			log.info("Player has already been finalized.");
		}
	}
	
}