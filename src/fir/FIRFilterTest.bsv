import FIFO::*;
import FixedPoint::*;
import FShow::*;
import Vector::*;

import AudioProcessorTypes::*;
import FIRFilter::*;

// Unit test for mkFIRFilter, following FFTTest style (no closeEnough).
// Flushes zeros between cases to reset FIR state.
(* synthesize *)
module mkFIRFilterTest(Empty);

    AudioProcessor dut <- mkFIRFilter();

    function closeEnough(Sample a, Sample b);
        let diff = a - b;
        return (diff <= 1 && diff >= -1);
    endfunction

    Integer nCases = 3;
    Integer flushLen = 8; // number of zeros to clear taps
    Vector#(3, Integer) nSamples = newVector;
    nSamples[0] = 10;
    nSamples[1] = 8;
    nSamples[2] = 10;

    // Stimulus/expected tables.
    Vector#(3, Vector#(10, Sample)) stim = newVector;
    Vector#(3, Vector#(10, Sample)) expected = newVector;

    // Case 0 stimulus.
    stim[0][0] = 0;
    stim[0][1] = 1000;
    stim[0][2] = -1000;
    stim[0][3] = 2000;
    stim[0][4] = -2000;
    stim[0][5] = 0;
    stim[0][6] = 5000;
    stim[0][7] = -5000;
    stim[0][8] = 1234;
    stim[0][9] = -1234;
    // Golden outputs from current FIR (case 0).
    expected[0][0] = 0;
    expected[0][1] = -13;
    expected[0][2] = 12;
    expected[0][3] = -39;
    expected[0][4] = 38;
    expected[0][5] = 791;
    expected[0][6] = -854;
    expected[0][7] = 1684;
    expected[0][8] = -1705;
    expected[0][9] = 42;

    // Case 1: all zeros.
    for (Integer i = 0; i < 10; i = i+1) begin
        stim[1][i] = (i < nSamples[1]) ? 0 : 0;
        expected[1][i] = 0;
    end

    // Case 2: negated case 0 (linearity check).
    for (Integer i = 0; i < 10; i = i+1) begin
        stim[2][i] = -stim[0][i];
        expected[2][i] = -expected[0][i];
    end

    Reg#(Bool) fed <- mkReg(False);
    Reg#(Bool) checked <- mkReg(False);
    Reg#(Bool) passed <- mkReg(True);
    Reg#(Bool) flushing <- mkReg(False);
    Reg#(Bit#(2)) caseIdx <- mkReg(0);

    Reg#(Bit#(4)) feedIdx <- mkReg(0); // up to 10 samples
    Reg#(Bit#(4)) outIdx <- mkReg(0);
    Reg#(Bit#(4)) flushIn <- mkReg(0);
    Reg#(Bit#(4)) flushOut <- mkReg(0);

    // Feed samples for the current case.
    rule setup (!fed && !checked && !flushing && feedIdx < fromInteger(nSamples[caseIdx]));
        dut.putSampleInput(stim[caseIdx][feedIdx]);
        feedIdx <= feedIdx + 1;
        if (feedIdx + 1 == fromInteger(nSamples[caseIdx])) fed <= True;
    endrule

    // Verify outputs as they arrive.
    rule verify (!flushing && outIdx < feedIdx);
        if (outIdx == 0) $display("Verifying FIR case %0d", caseIdx);
        Sample y <- dut.getSampleOutput();
        Sample exp = expected[caseIdx][outIdx];
        if (!closeEnough(y, exp)) begin
            $display("FIR mismatch idx %0d", outIdx);
            $display("Expected: %0d", exp);
            $display("Got:      %0d", y);
            passed <= False;
        end
        outIdx <= outIdx + 1;
    endrule

    // Start flushing zeros between cases (except after last case).
    rule start_flush (!flushing && fed && outIdx == fromInteger(nSamples[caseIdx]) && caseIdx + 1 < fromInteger(nCases));
        flushing <= True;
        flushIn <= 0;
        flushOut <= 0;
    endrule

    // Drive zeros to clear FIR state.
    rule flush_feed (flushing && flushIn < fromInteger(flushLen));
        dut.putSampleInput(0);
        flushIn <= flushIn + 1;
    endrule

    // Consume flushed outputs (ignore values).
    rule flush_drain (flushing && flushOut < flushIn);
        let _ <- dut.getSampleOutput();
        flushOut <= flushOut + 1;
    endrule

    // Advance to next case after flush completes.
    rule next_case (flushing && flushIn == fromInteger(flushLen) && flushOut == fromInteger(flushLen));
        flushing <= False;
        fed <= False;
        feedIdx <= 0;
        outIdx <= 0;
        caseIdx <= caseIdx + 1;
    endrule

    // Finish after last case outputs are seen.
    rule finish (!flushing && fed && outIdx == fromInteger(nSamples[caseIdx]) && caseIdx == fromInteger(nCases - 1));
        if (passed) $display("FIR PASSED");
        else $display("FIR FAILED");
        $finish();
    endrule

endmodule
