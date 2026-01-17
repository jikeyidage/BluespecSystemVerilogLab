
import ClientServer::*;
import GetPut::*;
import Vector::*;

import AudioProcessorTypes::*;
import Chunker::*;
import FFT::*;
import FIRFilter::*;
import Splitter::*;
import ComplexMP::*;
import ConvertComplexMP::*;
import OverSampler::*;
import Overlayer::*;
import PitchShift::*;

typedef 16 I_SIZE;
typedef 16 F_SIZE;
typedef 16 P_SIZE;
typedef 8 N;
typedef 2 S;
typedef 2 FACTOR;

module mkAudioPipeline(AudioProcessor);

    AudioProcessor fir <- mkFIRFilter();
    Chunker#(S, Sample) chunker <- mkChunker();
    OverSampler#(S, N, Sample) overSampler <- mkOverSampler(replicate(0));
    FFT fft <- mkFFT();
    ToMP#(N, I_SIZE, F_SIZE, P_SIZE) toMP <- mkToMP();
    PitchShift#(N, I_SIZE, F_SIZE, P_SIZE) pitchShift <- mkPitchShift(fromInteger(valueOf(FACTOR)));
    FromMP#(N, I_SIZE, F_SIZE, P_SIZE) fromMP <- mkFromMP();
    FFT ifft <- mkIFFT();
    Overlayer#(N, S, Sample) overlayer <- mkOverlayer(replicate(0));
    Splitter#(S, Sample) splitter <- mkSplitter();

    rule fir_to_chunker (True);
        let x <- fir.getSampleOutput();
        // $display("fir_to_chunker: %d", x);
        chunker.request.put(x);
    endrule

    rule chunker_to_overSampler (True);
        let x <- chunker.response.get();
        // $display("chunker_to_overSampler: %d", x);
        overSampler.request.put(x);
    endrule

    rule overSampler_to_fft (True);
        let x <- overSampler.response.get();
        // $display("overSampler_to_fft: %d", x);
        Vector#(N, ComplexSample) res = replicate(unpack(0));
        for (Integer i = 0; i < valueOf(N); i = i + 1) begin
            res[i] = tocmplx(x[i]);
        end
        fft.request.put(res);
    endrule

    rule fft_to_ToMP (True);
        let x <- fft.response.get();
        // $display("fft_to_ToMP: %d", x);
        toMP.request.put(x);
    endrule

    rule toMP_to_pitchAdjust (True);
        let x <- toMP.response.get();
        // $display("toMP_to_pitchAdjust: %d", x);
        pitchShift.request.put(x);
    endrule

    rule pitchShift_to_fromMP (True);
        let x <- pitchShift.response.get();
        // $display("pitchShift_to_fromMP: %d", x);
        fromMP.request.put(x);
    endrule

    rule fromMP_to_ifft (True);
        let x <- fromMP.response.get();
        // $display("fromMP_to_ifft: %d", x);
        ifft.request.put(x);
    endrule

    rule ifft_to_overlayer (True);
        let x <- ifft.response.get();
        // $display("ifft_to_overlayer: %d", x);
        Vector#(N, Sample) res = replicate(unpack(0));
        for (Integer i = 0; i < valueOf(N); i = i + 1) begin
            res[i] = frcmplx(x[i]);
        end
        overlayer.request.put(res);
    endrule

    rule overlayer_to_splitter (True);
        let x <- overlayer.response.get();
        // $display("overlayer_to_splitter: %d", x);
        splitter.request.put(x);
    endrule
    
    method Action putSampleInput(Sample x);
        fir.putSampleInput(x);
    endmethod

    method ActionValue#(Sample) getSampleOutput();
        let x <- splitter.response.get();
        return x;
    endmethod

endmodule
