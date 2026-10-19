import AppKit

let usage = """
usage:
  MoveSpike list
  MoveSpike snapshot <windowID> <out.png>
  MoveSpike drag <windowID> <deltaX> [--step-ms N] [--steps N] [--tap hid|session|pid] [--force]
  MoveSpike check-perms
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func parseOptions(_ args: [String]) -> DragOptions {
    var options = DragOptions()
    var iterator = args.makeIterator()
    while let flag = iterator.next() {
        if flag == "--force" {
            options.force = true
            continue
        }
        guard let value = iterator.next() else { fail("missing value for \(flag)\n\(usage)") }
        switch flag {
        case "--step-ms":
            guard let ms = Int(value) else { fail("bad --step-ms") }
            options.stepMs = ms
        case "--steps":
            guard let steps = Int(value) else { fail("bad --steps") }
            options.steps = steps
        case "--tap": options.tap = value
        default: fail("unknown flag \(flag)\n\(usage)")
        }
    }
    return options
}

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else { fail(usage) }

do {
    switch command {
    case "list":
        runList()
    case "check-perms":
        print("AXIsProcessTrusted (Accessibility): \(AXIsProcessTrusted())")
        print("CGPreflightScreenCaptureAccess (Screen Recording): \(CGPreflightScreenCaptureAccess())")
    case "snapshot":
        guard args.count == 3, let id = UInt32(args[1]) else { fail(usage) }
        try await runSnapshot(windowID: id, outPath: args[2])
    case "drag":
        guard args.count >= 3, let id = UInt32(args[1]), let delta = Double(args[2]) else { fail(usage) }
        try runDrag(windowID: id, deltaX: delta, options: parseOptions(Array(args.dropFirst(3))))
    default:
        fail(usage)
    }
} catch {
    fail("error: \(error)")
}
