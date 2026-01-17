
import FIFO::*;
import FixedPoint::*;
import Vector::*;

import AudioProcessorTypes::*;

module mkFIRFilter(AudioProcessor);
    Vector#(9, FixedPoint#(16,16)) coeffs = newVector;
    coeffs[0] = fromReal(-0.0124);
    coeffs[1] = fromReal(0.0);
    coeffs[2] = fromReal(-0.0133);
    coeffs[3] = fromReal(0.0);
    coeffs[4] = fromReal(0.8181);
    coeffs[5] = fromReal(0.0);
    coeffs[6] = fromReal(-0.0133);
    coeffs[7] = fromReal(0.0);
    coeffs[8] = fromReal(-0.0124);

    // Shift register to store the last 8 samples (x[n-1] to x[n-8])
    Vector#(8, Reg#(Sample)) delayLine <- replicateM(mkReg(0));
    FIFO#(Sample) inputFIFO <- mkFIFO();
    FIFO#(Sample) outputFIFO <- mkFIFO();

    // Process input: shift delay line and compute output
    rule process;
        let x_n = inputFIFO.first();
        inputFIFO.deq();

        // Compute weighted sum: y[n] = c0*x[n] + c1*x[n-1] + ... + c8*x[n-8]
        FixedPoint#(32, 32) sum = 0;
        
        // c0 * x[n] (current input)
        FixedPoint#(16, 16) x_n_fp = fromInt(x_n);
        FixedPoint#(32, 32) product = fxptMult(x_n_fp, coeffs[0]);
        sum = sum + extend(product);
        
        // c1 * x[n-1] + ... + c8 * x[n-8] (from delay line)
        for (Integer i = 0; i < 8; i = i + 1) begin
            FixedPoint#(16, 16) x_delayed_fp = fromInt(delayLine[i]);
            product = fxptMult(x_delayed_fp, coeffs[i + 1]);
            sum = sum + extend(product);
        end

        // Shift the delay line: new x[n-1] = old x[n], etc.
        delayLine[7] <= delayLine[6];
        delayLine[6] <= delayLine[5];
        delayLine[5] <= delayLine[4];
        delayLine[4] <= delayLine[3];
        delayLine[3] <= delayLine[2];
        delayLine[2] <= delayLine[1];
        delayLine[1] <= delayLine[0];
        delayLine[0] <= x_n;

        // Convert back to Int#(16)
        Int#(32) sum_int = fxptGetInt(sum);
        Sample output = truncate(sum_int);
        outputFIFO.enq(output);
    endrule

    method Action putSampleInput(Sample in);
        inputFIFO.enq(in);
    endmethod

    method ActionValue#(Sample) getSampleOutput();
        outputFIFO.deq();
        return outputFIFO.first();
    endmethod
endmodule