import ClientServer::*;
import GetPut::*;
import Vector::*;
import FixedPoint::*;
import FShow::*;
import ComplexMP::*;
import PitchShift::*;

// Unit test for PitchShift, styled like FFTTest.
(* synthesize *)
module mkPitchShiftTest (Empty);

    // For nbins = 8 pitch factor = 2.0
    PitchShift#(8, 16, 16, 16) adjust <- mkPitchShift(2);

    Reg#(Bool) fed <- mkReg(False);
    Reg#(Bool) checked <- mkReg(False);
    Reg#(Bool) passed <- mkReg(True);
    Reg#(Bit#(2)) caseIdx <- mkReg(0);

    function Bool closeEnough(ComplexMP#(16, 16, 16) a, ComplexMP#(16, 16, 16) b);
        let dm = abs(a.magnitude - b.magnitude);
        let dp = abs(a.phase - b.phase);
        return (dm <= fromReal(0.25) && dp <= 1);
    endfunction

    // Three test vectors and expected outputs.
    Vector#(3, Vector#(8, ComplexMP#(16, 16, 16))) stim = newVector;
    Vector#(3, Vector#(8, ComplexMP#(16, 16, 16))) expected = newVector;

    // Case 0.
    stim[0][0] = cmplxmp(1.000000, tophase(3.141593));
    stim[0][1] = cmplxmp(1.000000, tophase(-1.570796));
    stim[0][2] = cmplxmp(1.000000, tophase(0.000000));
    stim[0][3] = cmplxmp(1.000000, tophase(1.570796));
    stim[0][4] = cmplxmp(1.000000, tophase(3.141593));
    stim[0][5] = cmplxmp(1.000000, tophase(-1.570796));
    stim[0][6] = cmplxmp(1.000000, tophase(0.000000));
    stim[0][7] = cmplxmp(1.000000, tophase(1.570796));

    expected[0][0] = cmplxmp(1.000000, tophase(-0.000000));
    expected[0][1] = cmplxmp(0.000000, tophase(0.000000));
    expected[0][2] = cmplxmp(1.000000, tophase(-3.141593));
    expected[0][3] = cmplxmp(0.000000, tophase(0.000000));
    expected[0][4] = cmplxmp(1.000000, tophase(0.000000));
    expected[0][5] = cmplxmp(0.000000, tophase(0.000000));
    expected[0][6] = cmplxmp(1.000000, tophase(3.141593));
    expected[0][7] = cmplxmp(0.000000, tophase(0.000000));

    // Case 1.
    stim[1][0] = cmplxmp(1.000000, tophase(3.141593));
    stim[1][1] = cmplxmp(1.000000, tophase(0.000000));
    stim[1][2] = cmplxmp(1.000000, tophase(3.141593));
    stim[1][3] = cmplxmp(1.000000, tophase(0.000000));
    stim[1][4] = cmplxmp(1.000000, tophase(3.141593));
    stim[1][5] = cmplxmp(1.000000, tophase(0.000000));
    stim[1][6] = cmplxmp(1.000000, tophase(3.141593));
    stim[1][7] = cmplxmp(1.000000, tophase(0.000000));

    expected[1][0] = cmplxmp(1.000000, tophase(-0.000000));
    expected[1][1] = cmplxmp(0.000000, tophase(0.000000));
    expected[1][2] = cmplxmp(1.000000, tophase(0.000000));
    expected[1][3] = cmplxmp(0.000000, tophase(0.000000));
    expected[1][4] = cmplxmp(1.000000, tophase(-0.000000));
    expected[1][5] = cmplxmp(0.000000, tophase(0.000000));
    expected[1][6] = cmplxmp(1.000000, tophase(0.000000));
    expected[1][7] = cmplxmp(0.000000, tophase(0.000000));

    // Case 2.
    stim[2][0] = cmplxmp(0.000000, tophase(0.000000));
    stim[2][1] = cmplxmp(6.395666, tophase(2.455808));
    stim[2][2] = cmplxmp(9.899495, tophase(-2.356194));
    stim[2][3] = cmplxmp(14.801873, tophase(-1.229828));
    stim[2][4] = cmplxmp(14.000000, tophase(0.000000));
    stim[2][5] = cmplxmp(14.801873, tophase(1.229828));
    stim[2][6] = cmplxmp(9.899495, tophase(2.356194));
    stim[2][7] = cmplxmp(6.395666, tophase(-2.455808));

    expected[2][0] = cmplxmp(0.000000, tophase(0.000000));
    expected[2][1] = cmplxmp(0.000000, tophase(0.000000));
    expected[2][2] = cmplxmp(6.395666, tophase(-1.371570));
    expected[2][3] = cmplxmp(0.000000, tophase(0.000000));
    expected[2][4] = cmplxmp(9.899495, tophase(1.570796));
    expected[2][5] = cmplxmp(0.000000, tophase(0.000000));
    expected[2][6] = cmplxmp(14.801873, tophase(-2.459700));
    expected[2][7] = cmplxmp(0.000000, tophase(0.000000));

    rule setup (!fed && !checked);
        adjust.request.put(stim[caseIdx]);
        fed <= True;
    endrule

    rule verify (fed && !checked);
        let y <- adjust.response.get();
        Bool ok = True;
        $display("Verifying pitch shifting case %0d", caseIdx);
        for (Integer i = 0; i < 8; i = i + 1) begin
            if (!closeEnough(y[i], expected[caseIdx][i])) begin
                $display("PitchShift mismatch idx %0d", i);
                $display("Expected: ", fshow(expected[caseIdx][i]));
                $display("Got:      ", fshow(y[i]));
                ok = False;
            end
        end
        if (!ok) passed <= False;
        fed <= False;
        if (caseIdx == 2) checked <= True;
        else caseIdx <= caseIdx + 1;
    endrule

    rule finish (checked);
        if (passed) $display("PITCH PASSED");
        else $display("PITCH FAILED");
        $finish();
    endrule

endmodule
