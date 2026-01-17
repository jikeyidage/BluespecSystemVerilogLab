
import ClientServer::*;
import Complex::*;
import FIFO::*;
import FixedPoint::*;
import GetPut::*;
import Real::*;
import Vector::*;

import AudioProcessorTypes::*;

typedef 8 FFT_POINTS;
typedef TLog#(FFT_POINTS) FFT_LOG_POINTS;

typedef Server#(
    Vector#(FFT_POINTS, ComplexSample),
    Vector#(FFT_POINTS, ComplexSample)
) FFT;

// Get the appropriate twiddle factor for the given stage and index.
// This computes the twiddle factor statically.
function ComplexSample getTwiddle(Integer stage, Integer index, Integer points);
    Integer i = ((2*index)/(2 ** (log2(points)-stage))) * (2 ** (log2(points)-stage));
    return cmplx(fromReal(cos(fromInteger(i)*pi/fromInteger(points))),
                 fromReal(-1*sin(fromInteger(i)*pi/fromInteger(points))));
endfunction

// Inverse FFT, based on the mkFFT module.
// ifft[k] = fft[N-k]/N
module mkIFFT (FFT);
    FFT fft <- mkFFT();
    FIFO#(Vector#(FFT_POINTS, ComplexSample)) outputFIFO <- mkFIFO();
    FixedPoint#(16, 16) inv_n = fromReal(1.0 / fromInteger(valueof(FFT_POINTS)));

    rule reverse_and_scale;
        let result <- fft.response.get();
        
        // Reverse the sequence and divide by N
        Vector#(FFT_POINTS, ComplexSample) reversed = result;
        reversed[0] = result[0];
        for (Integer i = 1; i < valueof(FFT_POINTS); i = i + 1) begin
            reversed[i] = result[valueof(FFT_POINTS) - i];
        end
        
        // Scale by 1/N
        Vector#(FFT_POINTS, ComplexSample) scaled = reversed;
        for (Integer i = 0; i < valueof(FFT_POINTS); i = i + 1) begin
            scaled[i] = cmplx(
                fxptMult(reversed[i].rel, inv_n),
                fxptMult(reversed[i].img, inv_n)
            );
        end
        
        outputFIFO.enq(scaled);
    endrule

    interface Put request;
        method Action put(Vector#(FFT_POINTS, ComplexSample) x);
            fft.request.put(x);
        endmethod
    endinterface

    interface Get response;
        method ActionValue#(Vector#(FFT_POINTS, ComplexSample)) get();
            outputFIFO.deq();
            return outputFIFO.first();
        endmethod
    endinterface
endmodule

module mkFFT(FFT);
    FIFO#(Vector#(FFT_POINTS, ComplexSample)) inputFIFO <- mkFIFO();
    FIFO#(Vector#(FFT_POINTS, ComplexSample)) outputFIFO <- mkFIFO();
    
    // Pipeline stages: bit reversal + 3 stages
    FIFO#(Vector#(FFT_POINTS, ComplexSample)) stage0FIFO <- mkFIFO();
    FIFO#(Vector#(FFT_POINTS, ComplexSample)) stage1FIFO <- mkFIFO();
    FIFO#(Vector#(FFT_POINTS, ComplexSample)) stage2FIFO <- mkFIFO();

    // Bit reversal: reverse the bits of each index
    function Integer bitReverse(Integer index, Integer bits);
        Integer reversed = 0;
        for (Integer i = 0; i < bits; i = i + 1) begin
            if ((index & (1 << i)) != 0) begin
                reversed = reversed | (1 << (bits - 1 - i));
            end
        end
        return reversed;
    endfunction

    // Butterfly operation
    function ComplexSample butterfly(ComplexSample x0, ComplexSample x1, ComplexSample twiddle);
        // y0 = x0 + W * x1
        // y1 = x0 - W * x1
        ComplexSample w_x1 = cmplx(
            fxptMult(twiddle.rel, x1.rel) - fxptMult(twiddle.img, x1.img),
            fxptMult(twiddle.rel, x1.img) + fxptMult(twiddle.img, x1.rel)
        );
        ComplexSample y0 = cmplx(x0.rel + w_x1.rel, x0.img + w_x1.img);
        ComplexSample y1 = cmplx(x0.rel - w_x1.rel, x0.img - w_x1.img);
        return y0; // This returns y0, we'll handle y1 separately
    endfunction

    // Perform butterfly on two samples
    function Tuple2#(ComplexSample, ComplexSample) butterflyPair(
        ComplexSample x0, ComplexSample x1, ComplexSample twiddle);
        ComplexSample w_x1 = cmplx(
            fxptMult(twiddle.rel, x1.rel) - fxptMult(twiddle.img, x1.img),
            fxptMult(twiddle.rel, x1.img) + fxptMult(twiddle.img, x1.rel)
        );
        ComplexSample y0 = cmplx(x0.rel + w_x1.rel, x0.img + w_x1.img);
        ComplexSample y1 = cmplx(x0.rel - w_x1.rel, x0.img - w_x1.img);
        return tuple2(y0, y1);
    endfunction

    // Stage 0: Bit reversal
    rule bitReverse;
        let x = inputFIFO.first();
        inputFIFO.deq();
        
        Vector#(FFT_POINTS, ComplexSample) reversed = x;
        for (Integer i = 0; i < valueof(FFT_POINTS); i = i + 1) begin
            Integer rev_idx = bitReverse(i, valueof(FFT_LOG_POINTS));
            reversed[rev_idx] = x[i];
        end
        
        stage0FIFO.enq(reversed);
    endrule

    // Stage 0: Butterfly + Permutation
    rule stage0;
        let x = stage0FIFO.first();
        stage0FIFO.deq();
        
        Vector#(FFT_POINTS, ComplexSample) result = x;
        
        // Butterfly operations: 4 pairs
        for (Integer i = 0; i < 4; i = i + 1) begin
            Integer idx0 = 2 * i;
            Integer idx1 = 2 * i + 1;
            ComplexSample twiddle = getTwiddle(0, i, valueof(FFT_POINTS));
            match {.y0, .y1} = butterflyPair(x[idx0], x[idx1], twiddle);
            result[idx0] = y0;
            result[idx1] = y1;
        end
        
        // Permutation for stage 0: [0,4,2,6,1,5,3,7]
        Vector#(FFT_POINTS, ComplexSample) permuted = result;
        permuted[0] = result[0];
        permuted[1] = result[4];
        permuted[2] = result[2];
        permuted[3] = result[6];
        permuted[4] = result[1];
        permuted[5] = result[5];
        permuted[6] = result[3];
        permuted[7] = result[7];
        
        stage1FIFO.enq(permuted);
    endrule

    // Stage 1: Butterfly + Permutation
    rule stage1;
        let x = stage1FIFO.first();
        stage1FIFO.deq();
        
        Vector#(FFT_POINTS, ComplexSample) result = x;
        
        // Butterfly operations: 4 pairs
        for (Integer i = 0; i < 4; i = i + 1) begin
            Integer idx0 = 2 * i;
            Integer idx1 = 2 * i + 1;
            ComplexSample twiddle = getTwiddle(1, i, valueof(FFT_POINTS));
            match {.y0, .y1} = butterflyPair(x[idx0], x[idx1], twiddle);
            result[idx0] = y0;
            result[idx1] = y1;
        end
        
        // Permutation for stage 1: [0,2,4,6,1,3,5,7]
        Vector#(FFT_POINTS, ComplexSample) permuted = result;
        permuted[0] = result[0];
        permuted[1] = result[2];
        permuted[2] = result[4];
        permuted[3] = result[6];
        permuted[4] = result[1];
        permuted[5] = result[3];
        permuted[6] = result[5];
        permuted[7] = result[7];
        
        stage2FIFO.enq(permuted);
    endrule

    // Stage 2: Butterfly + No permutation (final stage)
    rule stage2;
        let x = stage2FIFO.first();
        stage2FIFO.deq();
        
        Vector#(FFT_POINTS, ComplexSample) result = x;
        
        // Butterfly operations: 4 pairs
        for (Integer i = 0; i < 4; i = i + 1) begin
            Integer idx0 = 2 * i;
            Integer idx1 = 2 * i + 1;
            ComplexSample twiddle = getTwiddle(2, i, valueof(FFT_POINTS));
            match {.y0, .y1} = butterflyPair(x[idx0], x[idx1], twiddle);
            result[idx0] = y0;
            result[idx1] = y1;
        end
        
        outputFIFO.enq(result);
    endrule

    interface Put request;
        method Action put(Vector#(FFT_POINTS, ComplexSample) x);
            inputFIFO.enq(x);
        endmethod
    endinterface

    interface Get response;
        method ActionValue#(Vector#(FFT_POINTS, ComplexSample)) get();
            outputFIFO.deq();
            return outputFIFO.first();
        endmethod
    endinterface
endmodule
