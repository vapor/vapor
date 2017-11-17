import Console

let console: Console = Terminal()

try console.output("Welcome", style: .custom(.red), newLine: false)
try console.output(" to", style: .custom(.yellow), newLine: false)
try console.output(" the", style: .custom(.green), newLine: false)
try console.output(" Console", style: .custom(.cyan), newLine: false)
try console.output(" Example!", style: .custom(.magenta))

try console.print()


// TEST DEMO

let name = try console.ask("What is your name?")

try console.print("Hello, \(name).")

console.wait(seconds: 1.5)
try console.print()

try console.print("I can show progress bars...")
console.wait(seconds: 1.5)
try console.clear(.line)

let progressBar = console.progressBar(title: "backups.dat")

let cycles = 30
for i in 0 ... cycles {
    if i != 0 {
        console.wait(seconds: 0.05)
    }
    progressBar.progress = Double(i) / Double(cycles)
}

try progressBar.finish()

console.wait(seconds: 0.5)
try console.print()

try console.print("I can show loading bars...")
console.wait(seconds: 1.5)
try console.clear(.line)


let loadingBar = console.loadingBar(title: "Connecting...")

try loadingBar.start()
console.wait(seconds: 2.5)
try loadingBar.finish()


console.wait(seconds: 0.5)
try console.print()

try console.print("I can show...")
console.wait(seconds: 1.5)
try console.clear(.line)

try console.print("Plain messages")
console.wait(seconds: 0.5)

try console.info("Informational messages")
console.wait(seconds: 0.5)

try console.success("Success messages")
console.wait(seconds: 0.5)

try console.warning("Warning messages")
console.wait(seconds: 0.5)

try console.error("Error messages")
console.wait(seconds: 0.5)

console.wait(seconds: 0.5)
try console.print()

try console.print("Thanks for watching, \(name)!")
console.wait(seconds: 1.5)
try console.clear(.line)


try console.info("Goodbye! 👋")
try console.print()
