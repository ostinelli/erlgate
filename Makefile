PROJECT_DIR:=$(strip $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST)))))

all:
	@rebar3 compile

clean:
	@rebar3 clean
	@find $(PROJECT_DIR)/. -name "erl_crash\.dump" | xargs rm -f

dialyze:
	@rebar3 dialyzer

run:
	@erl -pa `rebar3 path` \
	-name erlgate@127.0.0.1 \
	+K true \
	-config erlgate \
	-eval 'erlgate:start().'

run2:
	@erl -pa `rebar3 path` \
	-name erlgate2@127.0.0.1 \
	+K true \
	-config erlgate2 \
	-eval 'erlgate:start().'

tests: all
	ct_run -dir $(PROJECT_DIR)/test -logdir $(PROJECT_DIR)/test/results \
	-pa `rebar3 path`
