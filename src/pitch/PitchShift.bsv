
import ClientServer::*;
import FIFO::*;
import GetPut::*;

import FixedPoint::*;
import Vector::*;

import ComplexMP::*;


typedef Server#(
    Vector#(nbins, ComplexMP#(isize, fsize, psize)),
    Vector#(nbins, ComplexMP#(isize, fsize, psize))
) PitchShift#(numeric type nbins, numeric type isize, numeric type fsize, numeric type psize);


// factor - the amount to adjust the pitch.
//  1.0 makes no change. 2.0 goes up an octave, 0.5 goes down an octave, etc...
module mkPitchShift(FixedPoint#(isize, fsize) factor, PitchShift#(nbins, isize, fsize, psize) ifc)
    provisos( Add#(a__, psize, TAdd#(isize, isize))
            , Add#(psize, b__, isize)
            , Add#(c__, TLog#(nbins), isize)
            , Add#(TAdd#(TLog#(nbins), 1), d__, isize)
            , Min#(isize, 1, 1)
            , Min#(TAdd#(isize, fsize), 2, 2)
            );

    FIFO#(Vector#(nbins, ComplexMP#(isize, fsize, psize))) inputFIFO <- mkFIFO();
    FIFO#(Vector#(nbins, ComplexMP#(isize, fsize, psize))) outputFIFO <- mkFIFO();
    
    // Store previous frame's input phases
    Vector#(nbins, Reg#(Phase#(psize))) inphases <- replicateM(mkReg(0));
    // Store previous frame's output phases
    Vector#(nbins, Reg#(Phase#(psize))) outphases <- replicateM(mkReg(0));
    
    // Processing state: which bin we're currently processing
    Reg#(Bit#(TAdd#(TLog#(nbins), 1))) idx <- mkReg(fromInteger(valueof(nbins)));
    Reg#(Vector#(nbins, ComplexMP#(isize, fsize, psize))) currentInput <- mkRegU();
    Reg#(Vector#(nbins, ComplexMP#(isize, fsize, psize))) currentOutput <- mkReg(replicate(cmplxmp(0, 0)));

    // Process one frequency bin per cycle
    rule process (idx < fromInteger(valueof(nbins)));
        Vector#(nbins, ComplexMP#(isize, fsize, psize)) in;
        if (idx == 0) begin
            // Start new frame: get input and initialize output
            in = inputFIFO.first();
            currentInput <= in;
            currentOutput <= replicate(cmplxmp(0, 0));
        end else begin
            in = currentInput;
        end
        
        Vector#(nbins, ComplexMP#(isize, fsize, psize)) out = currentOutput;
        
        // Get current input phase and magnitude
        Phase#(psize) phase = in[idx].phase;
        FixedPoint#(isize, fsize) magnitude = in[idx].magnitude;
        
        // Calculate phase difference with previous frame
        Int#(TAdd#(psize, 1)) phase_diff_raw = extend(pack(phase)) - extend(pack(inphases[idx]));
        // Handle phase wrapping (keep in range [-PI, PI))
        Phase#(psize) phase_diff = unpack(truncate(phase_diff_raw));
        
        // Save current input phase
        inphases[idx] <= phase;
        
        // Calculate target bin: bin = idx * factor
        FixedPoint#(TAdd#(isize, isize), TAdd#(fsize, fsize)) idx_fp = fromInt(idx);
        FixedPoint#(TAdd#(isize, isize), TAdd#(fsize, fsize)) bin_fp = fxptMult(idx_fp, extend(factor));
        Int#(TAdd#(TLog#(nbins), 1)) bin_int = fxptGetInt(bin_fp);
        
        // Only process if bin < nbins
        if (bin_int < fromInteger(valueof(nbins))) begin
            // Shifted phase = phase_diff * factor
            FixedPoint#(TAdd#(isize, isize), TAdd#(fsize, fsize)) phase_diff_fp = fromInt(pack(phase_diff));
            FixedPoint#(TAdd#(isize, isize), TAdd#(fsize, fsize)) shifted_phase_diff_fp = fxptMult(phase_diff_fp, extend(factor));
            Int#(TAdd#(psize, 1)) shifted_phase_diff_int = fxptGetInt(shifted_phase_diff_fp);
            
            // Accumulate to output phase
            Int#(TAdd#(psize, 1)) new_outphase_raw = extend(pack(outphases[bin_int])) + shifted_phase_diff_int;
            Phase#(psize) new_outphase = unpack(truncate(new_outphase_raw));
            outphases[bin_int] <= new_outphase;
            
            // Generate output: magnitude from input, phase from accumulated output phase
            out[bin_int] = cmplxmp(magnitude, new_outphase);
        end
        
        // Update output
        currentOutput <= out;
        idx <= idx + 1;
        
        // Finish frame: output result and reset
        if (idx + 1 == fromInteger(valueof(nbins))) begin
            inputFIFO.deq();
            outputFIFO.enq(out);
            idx <= 0;
        end
    endrule

    interface Put request;
        method Action put(Vector#(nbins, ComplexMP#(isize, fsize, psize)) x);
            inputFIFO.enq(x);
        endmethod
    endinterface

    interface Get response;
        method ActionValue#(Vector#(nbins, ComplexMP#(isize, fsize, psize)) get();
            outputFIFO.deq();
            return outputFIFO.first();
        endmethod
    endinterface
endmodule
