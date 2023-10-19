BUILD_DIR := ./build
.DEFAULT_GOAL := build
.PHONY: build
.PHONY: test

build:
	python -m venv ${BUILD_DIR}/scikgtex_build_env
	. ${BUILD_DIR}/scikgtex_build_env/bin/activate
	python -m pip install -r ${BUILD_DIR}/requirements.txt
	python ${BUILD_DIR}/get_orkg_predicates.py
	python ${BUILD_DIR}/assemble_lua_source.py

build-from-json:
	python -m venv ${BUILD_DIR}/scikgtex_build_env
	. ${BUILD_DIR}/scikgtex_build_env/bin/activate
	python -m pip install -r ${BUILD_DIR}/requirements.txt
	python ${BUILD_DIR}/assemble_lua_source.py

test:
	sh ./test/run.sh