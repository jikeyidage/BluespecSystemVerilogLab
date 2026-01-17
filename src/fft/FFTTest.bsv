import ClientServer::*;
import Complex::*;
import FixedPoint::*;
import FShow::*;
import Vector::*;
import GetPut::*;

import AudioProcessorTypes::*;
import FFT::*;

// Unit test for mkFFT: impulse in -> all ones out.
(* synthesize *)
module mkFFTTest(Empty);

    FFT dut <- mkFFT();

    Reg#(Bool) fed <- mkReg(False);
    Reg#(Bool) checked <- mkReg(False);
    Reg#(Bool) passed <- mkReg(True);

    function Bool closeEnough(ComplexSample a, ComplexSample b);
        FixedPoint#(16, 16) tol = fromReal(0.25);
        let dr = abs(a.rel - b.rel);
        let di = abs(a.img - b.img);
        return (dr <= tol && di <= tol);
    endfunction

    function ComplexSample r2c(Integer r, Integer i);
        return cmplx(fromInteger(r), fromInteger(i));
    endfunction

    // Three test vectors and expected spectra.
    Vector#(3, Vector#(FFT_POINTS, ComplexSample)) stim = newVector;
    Vector#(3, Vector#(FFT_POINTS, ComplexSample)) expected = newVector;

    // Case 0: arbitrary real vector (captured golden).
    stim[0][0] = r2c(0, 0);
    stim[0][1] = r2c(1000, 0);
    stim[0][2] = r2c(-1000, 0);
    stim[0][3] = r2c(2000, 0);
    stim[0][4] = r2c(-2000, 0);
    stim[0][5] = r2c(1234, 0);
    stim[0][6] = r2c(-1234, 0);
    stim[0][7] = r2c(500, 0);

    expected[0][0] = r2c(500, 0);
    expected[0][1] = r2c(774, -1129);
    expected[0][2] = r2c(234, 266);
    expected[0][3] = r2c(3226, -661);
    expected[0][4] = r2c(-8968, 0);
    expected[0][5] = r2c(3226, 661);
    expected[0][6] = r2c(234, -266);
    expected[0][7] = r2c(774, 1129);

    // Case 1: all zeros -> all zeros.
    for (Integer i = 0; i < valueof(FFT_POINTS); i = i+1) begin
        stim[1][i] = r2c(0, 0);
        expected[1][i] = r2c(0, 0);
    end

    // Case 2: all ones -> bin0 = 8, others = 0.
    for (Integer i = 0; i < valueof(FFT_POINTS); i = i+1) begin
        stim[2][i] = r2c(1, 0);
        expected[2][i] = (i == 0) ? r2c(8, 0) : r2c(0, 0);
    end

    Reg#(Bit#(2)) caseIdx <- mkReg(0);

    rule setup (!fed && !checked);
        dut.request.put(stim[caseIdx]);
        fed <= True;
    endrule

    rule verify (fed && !checked);
        let y <- dut.response.get();
        Bool ok = True;
        $display("Verifying FFT case %0d", caseIdx);
        for (Integer i = 0; i < valueof(FFT_POINTS); i = i+1) begin
            if (!closeEnough(y[i], expected[caseIdx][i])) begin
                $display("FFT mismatch at idx %0d", i);
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
        if (passed) $display("FFT PASSED");
        else $display("FFT FAILED");
        $finish();
    endrule

endmodule
