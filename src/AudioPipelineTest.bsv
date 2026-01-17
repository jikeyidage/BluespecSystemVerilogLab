import Counter::*;

import AudioPipeline::*;
import AudioProcessorTypes::*;
import Vector::*;

module mkAudioPipelineTest(Empty);

    AudioProcessor pipeline <- mkAudioPipeline();

    function closeEnough(Sample a, Sample b);
        let diff = a - b;
		return (diff <= 10 && diff >= -10);
    endfunction

    Integer nSamples = 16;

    // Stimulus and expected outputs inlined from data/in.txt and data/out_ref.txt.
    Vector#(16, Sample) stim = newVector;
    Vector#(16, Sample) expected = newVector;

    stim[0]  = 0;
    stim[1]  = 5000;
    stim[2]  = 10000;
    stim[3]  = 15000;
    stim[4]  = 20000;
    stim[5]  = 15000;
    stim[6]  = 10000;
    stim[7]  = 5000;
    stim[8]  = 0;
    stim[9]  = -5000;
    stim[10] = -10000;
    stim[11] = -15000;
    stim[12] = -20000;
    stim[13] = -15000;
    stim[14] = -10000;
    stim[15] = -5000;

    expected[0]  = -1;
    expected[1]  = 0;
    expected[2]  = 3;
    expected[3]  = 10;
    expected[4]  = 17;
    expected[5]  = 9;
    expected[6]  = 98;
    expected[7]  = 219;
    expected[8]  = -246;
    expected[9]  = -167;
    expected[10] = 588;
    expected[11] = 535;
    expected[12] = 144;
    expected[13] = 311;
    expected[14] = 1321;
    expected[15] = 1050;

    Reg#(Bit#(5)) feedIdx <- mkReg(0);
    Reg#(Bit#(5)) outIdx  <- mkReg(0);
    Reg#(Bool) checked    <- mkReg(False);
    Reg#(Bool) passed     <- mkReg(True);
    Counter#(8) outstanding <- mkCounter(0);

    // Feed samples into the pipeline.
    rule feed (!checked && feedIdx < fromInteger(nSamples));
        pipeline.putSampleInput(stim[feedIdx]);
        feedIdx <= feedIdx + 1;
        outstanding.up();
    endrule

    // Read and check outputs as they become available.
    rule verify (outstanding.value() > 0);
        Sample y <- pipeline.getSampleOutput();
        Sample exp = expected[outIdx];
		if (!closeEnough(y, exp)) begin
            $display("Mismatch idx %0d! Expected %0d, got %0d", outIdx, exp, y);
            passed <= False;
        end
        outIdx <= outIdx + 1;
        outstanding.down();

        if (outIdx + 1 == fromInteger(nSamples) && feedIdx == fromInteger(nSamples) && outstanding.value() == 1)
            checked <= True;
    endrule

    rule finish (checked && outstanding.value() == 0);
        if (passed) $display("AUDIO PIPELINE PASSED");
        else $display("AUDIO PIPELINE FAILED");
        $finish();
    endrule

endmodule
