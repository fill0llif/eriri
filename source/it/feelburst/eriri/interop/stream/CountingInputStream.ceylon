import java.io {
	FilterInputStream,
	InputStream,
	IOException
}
import java.lang {
	overloaded,
	ByteArray,
	synchronized
}
shared class CountingInputStream(InputStream input)
	extends FilterInputStream(input) {
	
	variable value countInternal = 0;
	variable value markInternal = -1;
	
	shared Integer count =>
		countInternal;
	
	shared actual overloaded Integer read() {
		value result = input.read();
		if (result != -1) {
			countInternal++;
		}
		return result;
	}
	
	shared actual overloaded Integer read(ByteArray? b, Integer off, Integer len) {
		value result = input.read(b, off, len);
		if (result != -1) {
			countInternal += result;
		}
		return result;
	}
	
	shared actual Integer skip(Integer n) {
		value result = input.skip(n);
		countInternal += result;
		return result;
	}
	
	shared actual synchronized void mark(Integer readlimit) {
		input.mark(readlimit);
		markInternal = count;
		// it's okay to mark even if mark isn't supported, as reset won't work
	}
	
	shared actual synchronized void reset() {
		if (!input.markSupported()) {
			throw IOException("Mark not supported");
		}
		if (markInternal == -1) {
			throw IOException("Mark not set");
		}
		input.reset();
		countInternal = markInternal;
	}
	
}