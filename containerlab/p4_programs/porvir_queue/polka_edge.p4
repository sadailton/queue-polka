/* -*- P4_16 -*- */
#include <core.p4>
#if __TARGET_TOFINO__ == 2
#include <t2na.p4>
#else
#include <tna.p4>
#endif

#define POLKA_HEADER_SIZE 160
//#define POLKA_EDGE 1
// Headers and parsers ingress
/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
#include "include/ingress_headers.p4"
#include "include/ingress_metadata.p4"

#include "include/edge/ingress_edge_parser.p4"
#include "include/edge/edge-tunnel_encap.p4"
#include "include/edge/ingress_edge.p4"

#include "include/ingress_deparser.p4"

/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
#include "include/egress.p4"

Pipeline(
    IngressParser(),
    Ingress(),
    IngressDeparser(),
    EgressParser(),
    Egress(),
    EgressDeparser()
) pipe;

Switch(pipe) main;