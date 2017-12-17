import Console

let console = Terminal()

console.output("Welcome", style: .init(color: .red), newLine: false)
console.output(" to", style: .init(color: .yellow), newLine: false)
console.output(" the", style: .init(color: .green), newLine: false)
console.output(" Console", style: .init(color: .cyan), newLine: false)
console.output(" Example!", style: .init(color: .magenta))

console.print()


// TEST DEMO

let name = console.ask("What is your name?")

console.print("Hello, \(name).")

console.blockingWait(seconds: 1.5)
console.print()

console.print("I can show progress bars...")
console.blockingWait(seconds: 1.5)
console.clear(.line)

let progressBar = console.progressBar(title: "backups.dat")

let cycles = 30
for i in 0 ... cycles {
    if i != 0 {
        console.blockingWait(seconds: 0.05)
    }
    progressBar.progress = Double(i) / Double(cycles)
}

progressBar.finish()

console.blockingWait(seconds: 0.5)
console.print()

console.print("I can show loading bars...")
console.blockingWait(seconds: 1.5)
console.clear(.line)


let loadingBar = console.loadingBar(title: "Connecting...")

loadingBar.start()
console.blockingWait(seconds: 2.5)
loadingBar.finish()


console.blockingWait(seconds: 0.5)
console.print()

console.print("I can show...")
console.blockingWait(seconds: 1.5)
console.clear(.line)

console.print("Plain messages")
console.blockingWait(seconds: 0.5)

console.info("Informational messages")
console.blockingWait(seconds: 0.5)

console.success("Success messages")
console.blockingWait(seconds: 0.5)

console.warning("Warning messages")
console.blockingWait(seconds: 0.5)

console.error("Error messages")
console.blockingWait(seconds: 0.5)

console.blockingWait(seconds: 0.5)
console.print()

console.print("Thanks for watching, \(name)!")
console.blockingWait(seconds: 1.5)
console.clear(.line)


console.info("Goodbye! 👋")
console.print()

