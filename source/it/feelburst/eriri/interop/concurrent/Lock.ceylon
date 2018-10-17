import java.lang {
	overloaded
}
import java.util.concurrent {
	TimeUnit
}
import java.util.concurrent.locks {
	JLock=Lock,
	ReentrantLock,
	Condition
}
shared class Lock(ReentrantLock lck = ReentrantLock()) satisfies JLock&Obtainable {
	
	shared actual void lock() =>
		lck.lock();
	
	shared actual void lockInterruptibly() =>
		lck.lockInterruptibly();
	
	shared actual Condition newCondition() =>
		lck.newCondition();
	
	shared actual overloaded Boolean tryLock() =>
		lck.tryLock();
	
	shared actual overloaded Boolean tryLock(Integer time, TimeUnit? unit) =>
		lck.tryLock(time, unit);
	
	shared actual void unlock() =>
		lck.unlock();
	
	shared actual void obtain() =>
		lock();
	
	shared actual void release(Throwable? error) {
		unlock();
		if (exists error) {
			throw error;
		}
	}
	
}