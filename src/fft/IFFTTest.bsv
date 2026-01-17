import ClientServer::*;
import Complex::*;
import FShow::*;
import Vector::*;
import FixedPoint::*;
import GetPut::*;

import AudioProcessorTypes::*;
import FFT::*;

// Unit test for mkIFFT: constant spectrum of ones -> impulse at index 0.
(* synthesize *)
module mkIFFTTest(Empty);

    FFT dut <- mkIFFT();

    Reg#(Bool) fed <- mkReg(False);
    Reg#(Bool) checked <- mkReg(False);
    Reg#(Bool) passed <- mkReg(True);

    function ComplexSample r2c(Integer r, Integer i);
        return cmplx(fromInteger(r), fromInteger(i));
    endfunction

    function Bool closeEnough(ComplexSample a, ComplexSample b);
        FixedPoint#(16, 16) tol = fromReal(0.25);
        let dr = abs(a.rel - b.rel);
        let di = abs(a.img - b.img);
        return (dr <= tol && di <= tol);
    endfunction

    // Three spectra and expected time-domain outputs.
    Vector#(3, Vector#(FFT_POINTS, ComplexSample)) spectrum = newVector;
    Vector#(3, Vector#(FFT_POINTS, ComplexSample)) expected = newVector;

    // Case 0: captured golden pair.
    spectrum[0][0] = r2c(500, 0);
    spectrum[0][1] = r2c(774, -1129);
    spectrum[0][2] = r2c(234, 266);
    spectrum[0][3] = r2c(3226, -661);
    spectrum[0][4] = r2c(-8968, 0);
    spectrum[0][5] = r2c(3226, 661);
    spectrum[0][6] = r2c(234, -266);
    spectrum[0][7] = r2c(774, 1129);

    expected[0][0] = r2c(0, 0);
    expected[0][1] = r2c(1000, 0);
    expected[0][2] = r2c(-1000, 0);
    expected[0][3] = r2c(2000, 0);
    expected[0][4] = r2c(-2000, 0);
    expected[0][5] = r2c(1234, 0);
    expected[0][6] = r2c(-1234, 0);
    expected[0][7] = r2c(500, 0);

    // Case 1: all zeros -> all zeros.
    for (Integer i = 0; i < valueof(FFT_POINTS); i = i+1) begin
        spectrum[1][i] = r2c(0, 0);
        expected[1][i] = r2c(0, 0);
    end

    // Case 2: only DC bin set to 8 -> all ones after IFFT.
    for (Integer i = 0; i < valueof(FFT_POINTS); i = i+1) begin
        spectrum[2][i] = (i == 0) ? r2c(8, 0) : r2c(0, 0);
        expected[2][i] = r2c(1, 0);
    end

    Reg#(Bit#(2)) caseIdx <- mkReg(0);

    rule setup (!fed && !checked);
        dut.request.put(spectrum[caseIdx]);
        fed <= True;
    endrule

    rule verify (fed && !checked);
        let y <- dut.response.get();
        Bool ok = True;
        $display("Verifying IFFT case %0d", caseIdx);
        for (Integer i = 0; i < valueof(FFT_POINTS); i = i+1) begin
            if (!closeEnough(y[i], expected[caseIdx][i])) begin
                $display("IFFT mismatch at idx %0d", i);
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
        if (passed) $display("IFFT PASSED");
        else $display("IFFT FAILED");
        $finish();
    endrule

endmodule
