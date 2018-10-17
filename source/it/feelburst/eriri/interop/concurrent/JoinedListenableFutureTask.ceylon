import java.util.concurrent {
	JCallable=Callable
}
import java.util.concurrent.locks {
	Condition
}

import org.springframework.util.concurrent {
	ListenableFuture,
	ListenableFutureTask
}
import it.feelburst.eriri.interop.concurrent {
	Lock
}

shared class JoinedListenableFutureTask<Left,Right>
	extends ListenableFutureTask<[Left,Right]>
	satisfies ListenableFuture<[Left,Right]> {
	
	late ListenableFuture<Left> left;
	late ListenableFuture<Right> right;
	
	shared new (
		ListenableFuture<Left> left,
		ListenableFuture<Right> right)
		extends ListenableFutureTask<[Left,Right]>(
			object satisfies JCallable<[Left,Right]> {
				value lock = Lock();
				value isLftDone = lock.newCondition();
				value isRghtDone = lock.newCondition();
				
				void await(Condition condition) {
					try (lock) {
						condition.await();
					}
				}
				
				void signal(Condition condition) {
					try (lock) {
						condition.signal();
					}
				}
				
				left.addCallback(
					(Left arg0) => signal(isLftDone),
					(Throwable arg0) => signal(isLftDone));
				
				right.addCallback(
					(Right arg0) => signal(isRghtDone),
					(Throwable arg0) => signal(isRghtDone));
				
				shared actual [Left,Right] call() {
					while (!left.done) {
						await(isLftDone);
					}
					while (!right.done) {
						await(isRghtDone);
					}
					return [left.get(),right.get()];
				}
			}) {
		this.left = left;
		this.right = right;
	}
	
}