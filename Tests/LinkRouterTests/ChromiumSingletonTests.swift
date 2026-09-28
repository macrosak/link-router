import Foundation
import Testing
@testable import LinkRouterCore

@Suite("Chromium singleton socket")
struct ChromiumSingletonTests {
    @Test func messageFormat() {
        let m = ChromiumSingleton.message(cwd: "/", argv: ["/C", "--profile-directory=Profile 1", "https://x"])
        #expect(m == Data("START\0/\0/C\0--profile-directory=Profile 1\0https://x".utf8))
    }

    @Test func missingSocketFailsFast() {
        let r = ChromiumSingleton.send(socketPath: "/tmp/definitely-not-a-socket-\(UUID().uuidString)", argv: ["x"])
        guard case .failure(.connect) = r else { Issue.record("expected connect failure, got \(r)"); return }
    }

    /// Round-trips against a fake Chrome listening on a real Unix socket.
    @Test func sendsCommandLineAndReadsAck() throws {
        let path = "/tmp/lr-test-\(getpid()).sock"
        unlink(path)
        let server = socket(AF_UNIX, SOCK_STREAM, 0)
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            let b = Array(path.utf8); buf.copyBytes(from: b); buf[b.count] = 0
        }
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(server, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        try #require(bound == 0)
        listen(server, 1)
        defer { close(server); unlink(path) }

        final class Box: @unchecked Sendable { var received = Data() }
        let box = Box()
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            let c = accept(server, nil, nil)
            var buf = [UInt8](repeating: 0, count: 1024)
            while true {
                let n = read(c, &buf, buf.count)
                if n <= 0 { break }
                box.received.append(contentsOf: buf[0..<n])
            }
            _ = "ACK".withCString { write(c, $0, 3) }
            close(c)
            done.signal()
        }

        let r = ChromiumSingleton.send(socketPath: path, argv: ["/C", "https://x"])
        done.wait()
        guard case .success = r else { Issue.record("expected success, got \(r)"); return }
        #expect(box.received == ChromiumSingleton.message(cwd: "/", argv: ["/C", "https://x"]))
    }
}
