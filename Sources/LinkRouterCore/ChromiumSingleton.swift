import Foundation

/// Hands URLs to an already-running Chromium browser through its
/// `SingletonSocket` — the same channel a second `chrome` process uses to say
/// "open these in the existing session". Talking to the socket directly skips
/// spawning that second process, which has to load the whole Chromium
/// framework first (~seconds) just to forward its command line; this takes
/// well under a millisecond.
///
/// Protocol (chrome/browser/process_singleton_posix.cc): connect to the Unix
/// socket, write `START\0<cwd>\0<argv0>\0<arg1>…`, shut down the write side,
/// read back `ACK`.
public enum ChromiumSingleton {
    public enum Failure: Error, Equatable {
        case noSocket
        case pathTooLong
        case connect(Int32)
        case write(Int32)
        case noAck(String)
    }

    public static func message(cwd: String, argv: [String]) -> Data {
        var parts = ["START", cwd]
        parts += argv
        return Data(parts.joined(separator: "\0").utf8)
    }

    /// `<user data dir>/SingletonSocket` resolved through its symlink (Chrome
    /// points it into a short temp dir to stay under the sun_path limit).
    public static func socketPath(userDataDir: URL) -> String? {
        let link = userDataDir.appendingPathComponent("SingletonSocket").path
        if let dest = try? FileManager.default.destinationOfSymbolicLink(atPath: link) {
            return dest.hasPrefix("/") ? dest : (userDataDir.path as NSString).appendingPathComponent(dest)
        }
        return FileManager.default.fileExists(atPath: link) ? link : nil
    }

    /// Sends the command line and waits (up to `timeout`) for the ACK.
    public static func send(socketPath: String, argv: [String], cwd: String = "/", timeout: TimeInterval = 2) -> Result<Void, Failure> {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return .failure(.connect(errno)) }
        defer { close(fd) }

        var tv = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout - floor(timeout)) * 1_000_000))
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(socketPath.utf8)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        guard pathBytes.count < capacity else { return .failure(.pathTooLong) }
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            buf.copyBytes(from: pathBytes)
            buf[pathBytes.count] = 0
        }
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)

        let rc = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard rc == 0 else { return .failure(.connect(errno)) }

        let msg = message(cwd: cwd, argv: argv)
        var sent = 0
        while sent < msg.count {
            let n = msg.withUnsafeBytes { raw in
                write(fd, raw.baseAddress!.advanced(by: sent), msg.count - sent)
            }
            guard n > 0 else { return .failure(.write(errno)) }
            sent += n
        }
        shutdown(fd, SHUT_WR)

        var buf = [UInt8](repeating: 0, count: 64)
        var got = [UInt8]()
        while got.count < 3 {
            let n = read(fd, &buf, buf.count)
            if n <= 0 { break }
            got += buf[0..<n]
        }
        let reply = String(decoding: got, as: UTF8.self)
        return reply.hasPrefix("ACK") ? .success(()) : .failure(.noAck(reply))
    }
}
