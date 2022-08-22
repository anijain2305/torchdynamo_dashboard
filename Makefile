.PHONY: default

PY_FILES := $(wildcard dashboard/*.py)
PIP ?= python -m pip

default: develop

develop:
	python setup.py develop


format:
	isort $(PY_FILES)
	black $(PY_FILES)

lint:
	black --check --diff $(PY_FILES)
	isort --check --diff $(PY_FILES)

lint-deps:
	grep -E '(black|flake8|isort|click|)' requirements.txt | xargs $(PIP) install

