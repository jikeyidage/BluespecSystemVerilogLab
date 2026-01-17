bscflags = -keep-fires -aggressive-conditions -Xc++ -D_GLIBCXX_USE_CXX11_ABI=0
bsvdir = src/utility:src/fir:src/fft:src/pitch:src/
build_dir = bscdir

src = $(wildcard src/fir/*.bsv) $(wildcard src/fft/*.bsv) $(wildcard src/pitch/*.bsv)

compile: $(src)
	mkdir -p bscdir
	bsc -u -sim -simdir $(build_dir) -bdir $(build_dir) -info-dir $(build_dir) $(bscflags) -p +:$(bsvdir) -g mkAudioPipelineTest src/AudioPipelineTest.bsv
sim: compile
	bsc -e mkAudioPipelineTest -sim -o ./audio.out -simdir $(build_dir) -bdir $(build_dir) -info-dir $(build_dir) $(bscflags) && ./audio.out

compile-fir: $(wildcard src/fir/*.bsv)
	mkdir -p bscdir
	bsc -u -sim -simdir $(build_dir) -bdir $(build_dir) -info-dir $(build_dir) $(bscflags) -p +:$(bsvdir) -g mkFIRFilterTest src/fir/FIRFilterTest.bsv

sim-fir: compile-fir
	bsc -e mkFIRFilterTest -sim -o ./fir.out -simdir $(build_dir) -bdir $(build_dir) -info-dir $(build_dir) $(bscflags) && ./fir.out

compile-fft: $(wildcard src/fft/*.bsv)
	mkdir -p bscdir
	bsc -u -sim -simdir $(build_dir) -bdir $(build_dir) -info-dir $(build_dir) $(bscflags) -p +:$(bsvdir) -g mkFFTTest src/fft/FFTTest.bsv

sim-fft: compile-fft
	bsc -e mkFFTTest -sim -o ./fft.out -simdir $(build_dir) -bdir $(build_dir) -info-dir $(build_dir) $(bscflags) && ./fft.out

compile-ifft: $(wildcard src/fft/*.bsv)
	mkdir -p bscdir
	bsc -u -sim -simdir $(build_dir) -bdir $(build_dir) -info-dir $(build_dir) $(bscflags) -p +:$(bsvdir) -g mkIFFTTest src/fft/IFFTTest.bsv

sim-ifft: compile-ifft
	bsc -e mkIFFTTest -sim -o ./ifft.out -simdir $(build_dir) -bdir $(build_dir) -info-dir $(build_dir) $(bscflags) && ./ifft.out

compile-pitch: $(wildcard src/pitch/*.bsv)
	mkdir -p bscdir
	bsc -u -sim -simdir $(build_dir) -bdir $(build_dir) -info-dir $(build_dir) $(bscflags) -p +:$(bsvdir) -g mkPitchShiftTest src/pitch/PitchShiftTest.bsv

sim-pitch: compile-pitch
	bsc -e mkPitchShiftTest -sim -o ./pitch.out -simdir $(build_dir) -bdir $(build_dir) -info-dir $(build_dir) $(bscflags) && ./pitch.out

clean:
	rm -rf bscdir *.out *.so
