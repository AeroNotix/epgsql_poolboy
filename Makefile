REBAR = rebar3
TEST_DATABASE = epgsql_test_database

.PHONY: compile clean console databases distclean dialyzer test

all: compile

compile:
	$(REBAR) compile

clean:
	$(REBAR) clean

console:
	erl -pa deps/*/ebin/ -pa ebin/ -sname epgsql_poolboy

distclean: clean
	rm -fR _build

dialyzer: compile
	@dialyzer -Wno_undefined_callbacks \
	-r ebin \
	-r _build/default/lib/bear \
	-r _build/default/lib/epgsql \
	-r _build/default/lib/folsom \
	-r _build/default/lib/poolboy

databases: $(TEST_DATABASE)

$(TEST_DATABASE):
	@if [ `psql -l | grep $@ | wc -l` -eq 0 ]; then \
		createdb $@; \
	fi

postgres-init: databases
	@psql -d $(TEST_DATABASE) < priv/test_schema.sql

test: postgres-init
	$(REBAR) ct

