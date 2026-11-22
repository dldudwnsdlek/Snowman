import Foundation

nonisolated(unsafe) var checkCount = 0
nonisolated(unsafe) var failures: [String] = []

func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
    checkCount += 1
    if !ok { failures.append("✗ \(name) \(detail())") }
}

func checkClose(_ name: String, _ a: Double, _ b: Double, tol: Double) {
    check(name, abs(a - b) <= tol, "got \(a), expected \(b) ± \(tol)")
}

func finish() -> Never {
    if failures.isEmpty {
        print("All \(checkCount) checks passed")
        exit(0)
    }
    failures.forEach { print($0) }
    print("\(failures.count) of \(checkCount) checks failed")
    exit(1)
}
