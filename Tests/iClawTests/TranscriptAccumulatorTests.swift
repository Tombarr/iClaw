import Testing
@testable import iClaw

@Suite("TranscriptAccumulator")
struct TranscriptAccumulatorTests {

    @Test func emptyByDefault() {
        let acc = TranscriptAccumulator()
        #expect(acc.finalizedTranscript == "")
        #expect(acc.volatileTranscript == "")
        #expect(acc.combined == "")
    }

    @Test func volatileResultAppearsInCombined() {
        var acc = TranscriptAccumulator()
        acc.apply(text: "hello", isFinal: false)

        #expect(acc.volatileTranscript == "hello")
        #expect(acc.finalizedTranscript == "")
        #expect(acc.combined == "hello")
    }

    @Test func finalizedResultAppearsInCombined() {
        var acc = TranscriptAccumulator()
        acc.apply(text: "hello", isFinal: true)

        #expect(acc.finalizedTranscript == "hello")
        #expect(acc.volatileTranscript == "")
        #expect(acc.combined == "hello")
    }

    @Test func volatileReplacedByNewVolatile() {
        var acc = TranscriptAccumulator()
        acc.apply(text: "hel", isFinal: false)
        acc.apply(text: "hello", isFinal: false)

        #expect(acc.volatileTranscript == "hello")
        #expect(acc.combined == "hello")
    }

    @Test func volatileClearedWhenFinalized() {
        var acc = TranscriptAccumulator()
        acc.apply(text: "hel", isFinal: false)
        acc.apply(text: "hello ", isFinal: true)

        #expect(acc.volatileTranscript == "")
        #expect(acc.finalizedTranscript == "hello ")
        #expect(acc.combined == "hello")
    }

    @Test func multipleFinalizedSegmentsAccumulate() {
        var acc = TranscriptAccumulator()
        acc.apply(text: "Hello ", isFinal: true)
        acc.apply(text: "world", isFinal: true)

        #expect(acc.finalizedTranscript == "Hello world")
        #expect(acc.combined == "Hello world")
    }

    @Test func volatileAfterFinalizedAppendsToCombined() {
        var acc = TranscriptAccumulator()
        acc.apply(text: "Hello ", isFinal: true)
        acc.apply(text: "wor", isFinal: false)

        #expect(acc.combined == "Hello wor")
    }

    @Test func typicalLiveSequence() {
        var acc = TranscriptAccumulator()

        // First word builds up via volatile results
        acc.apply(text: "H", isFinal: false)
        #expect(acc.combined == "H")

        acc.apply(text: "Hell", isFinal: false)
        #expect(acc.combined == "Hell")

        acc.apply(text: "Hello ", isFinal: true)
        #expect(acc.combined == "Hello")

        // Second word
        acc.apply(text: "w", isFinal: false)
        #expect(acc.combined == "Hello w")

        acc.apply(text: "world", isFinal: false)
        #expect(acc.combined == "Hello world")

        acc.apply(text: "world.", isFinal: true)
        #expect(acc.combined == "Hello world.")
    }

    @Test func combinedTrimsWhitespace() {
        var acc = TranscriptAccumulator()
        acc.apply(text: "  hello  ", isFinal: true)
        #expect(acc.combined == "hello")
    }
}
