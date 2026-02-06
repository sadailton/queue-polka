P4C = p4c-bm2-ss
SWITCH = DR_PIFO.p4
JSON = DR_PIFO.json

all: build

build:
	$(P4C) --p4v 16 --emit-externs -o $(JSON) $(SWITCH)