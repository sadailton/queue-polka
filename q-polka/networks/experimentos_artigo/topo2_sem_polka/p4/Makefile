P4C = p4c-bm2-ss
CORE = router_core.p4
EDGE = router_edge.p4
JSON_CORE = router_core.json
JSON_EDGE = router_edge.json

all: build

build: edge
	${P4C} --p4v 16 --emit-externs -o $(JSON_CORE) $(CORE)

edge:
	${P4C} --p4v 16 --emit-externs -o $(JSON_EDGE) $(EDGE)


clean:
	rm -rf *.json *.p4i