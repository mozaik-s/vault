.PHONY: compile test lint dialyzer clean

PLT       = .dialyzer.plt
BEAM_DIR  = _build/dev/lib/vault/ebin
SRC_DIR   = src
DEPS_EBIN = $(wildcard deps/*/ebin) $(wildcard _build/dev/lib/*/ebin)
INCLUDES  = $(patsubst %,-I %,$(wildcard deps/*/include))
DEPS_PA   = $(patsubst %,-pa %,$(DEPS_EBIN))
ERL_FLAGS = $(DEPS_PA) $(INCLUDES) -Wall +debug_info

compile:
	@mkdir -p $(BEAM_DIR)
	@erlc $(ERL_FLAGS) -o $(BEAM_DIR) $(SRC_DIR)/*.erl && echo "Compiled"

test: compile
	@mkdir -p _build/test/logs
	@ct_run $(DEPS_PA) \
	  -spec test/vault.spec \
	  -cover test/cover.spec \
	  -logdir _build/test/logs \
	  2>&1 | grep -E "(Testing |TEST COMPLETE|FAILED|ERROR|failed of|Updating )"
	@COVERDATA=$$(ls -t _build/test/logs/ct_run.*/all.coverdata 2>/dev/null | head -1); \
	  [ -n "$$COVERDATA" ] && escript scripts/print_coverage.escript "$$COVERDATA" \
	    | grep -v "^Analysis includes" | grep -v "^\[\"" || true

lint:
	@elvis rock && echo "Linting passed"

$(PLT):
	dialyzer --build_plt --output_plt $(PLT) \
	  --apps erts kernel stdlib crypto eunit common_test \
	  $(patsubst %,-r %,$(wildcard _build/dev/lib/*/ebin)); \
	  status=$$?; [ $$status -le 2 ] && exit 0 || exit $$status

dialyzer: compile $(PLT)
	dialyzer --plt $(PLT) $(DEPS_PA) $(BEAM_DIR); \
	  status=$$?; [ $$status -le 2 ] && echo "Dialyzer passed" || exit $$status

clean:
	rm -rf _build
