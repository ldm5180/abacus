# The S0 spike.  Every target runs through alr so AUnit resolves.

.PHONY: test prove bench format no-float

## test      The AUnit suite, in debug (contracts checked) then release
test:
	alr exec -- gprbuild -p -j0 -XMODE=debug -P tests/tests.gpr
	alr exec -- tests/bin/debug/test_runner
	alr exec -- gprbuild -p -j0 -XMODE=release -P tests/tests.gpr
	alr exec -- tests/bin/release/test_runner

## prove     SPARK proof of every spike unit, at each Frac's instance
prove:
	timeout 30m gnatprove -P proof/proof.gpr -j0 --level=2 \
	  --checks-as-errors=on --warnings=error
	sed -n '/^Summary of SPARK/,/^Total/p' proof/obj/gnatprove/gnatprove.out

## bench     Build and run the benchmark in both measured profiles
bench:
	alr exec -- gprbuild -p -j0 -XMODE=release -P bench/bench.gpr
	alr exec -- gprbuild -p -j0 -XMODE=unchecked -P bench/bench.gpr
	bench/bin/release/bench_spike release
	bench/bin/unchecked/bench_spike unchecked

## format    gnatformat over the committed Ada sources
format:
	alr exec -- gnatformat --charset utf-8 -P spike.gpr --check $$(git ls-files 'src/*.ad[sb]')
	alr exec -- gnatformat --charset utf-8 -P tests/tests.gpr --check $$(git ls-files 'tests/src/*.ad[sb]' 'harness/*.ad[sb]')
	alr exec -- gnatformat --charset utf-8 -P bench/bench.gpr --check $$(git ls-files 'bench/src/*.ad[sb]')
	alr exec -- gnatformat --charset utf-8 -P proof/proof.gpr --check $$(git ls-files 'proof/src/*.ad[sb]')

## no-float  No floating-point type anywhere in the spike's Ada
no-float:
	! grep -rniE '\b(long_)*float\b|\bdigits\b|elementary_functions' \
	  --include='*.ad[sb]' src tests/src bench/src proof/src harness
