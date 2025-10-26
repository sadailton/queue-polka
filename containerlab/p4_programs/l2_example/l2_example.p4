#include <core.p4>
#if __TARGET_TOFINO__ == 3
#include <t3na.p4>
#elif __TARGET_TOFINO__ == 2
#include <t2na.p4>
#else
#include <tna.p4>
#endif

#include "/open-p4studio/pkgsrc/p4-examples/p4_16_programs/common/headers.p4"
#include "/open-p4studio/pkgsrc/p4-examples/p4_16_programs/common/util.p4"

// CORRIGIDO: Adicionado ponto e vírgula no final.
struct headers {
    ethernet_h ethernet;
    ipv4_h     ipv4;
};

// CORRIGIDO: Adicionado ponto e vírgula no final.
struct metadata_t {};



parser SwitchIngressParser(packet_in pkt, out headers hdr, out metadata_t ig_md,
                out ingress_intrinsic_metadata_t ig_intr_md) {

    TofinoIngressParser() tofino_parser;

    state start {
        tofino_parser.apply(pkt, ig_intr_md);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        
        transition accept;
       
       }
    
    /*state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition accept;
    }*/
}

control SwitchIngress(inout headers hdr,
        inout metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_intr_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_intr_tm_md) {

    // CORRIGIDO: A ação agora aceita o MAC de origem (do roteador)
    // e o MAC de destino (do próximo salto) como parâmetros separados.
    action ethernet_forward (bit<9> port) {
        
        ig_intr_tm_md.ucast_egress_port = port;
    }

    table dmac {
        key = {
            hdr.ethernet.dst_addr: exact;
        }
        actions = {
            ethernet_forward;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }
    
    apply {
        if (hdr.ethernet.isValid()) {
            dmac.apply();
        }
    }
}

control SwitchIngressDeparser(packet_out pkt,
        inout headers hdr,
        in metadata_t ig_md,
        in ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md) {

    apply {
        pkt.emit(hdr.ethernet);
        //pkt.emit(hdr.ipv4);
    }
}

Pipeline(SwitchIngressParser(),
        SwitchIngress(),
        SwitchIngressDeparser(),
        EmptyEgressParser(),
        EmptyEgress(),
        EmptyEgressDeparser()) pipe;

Switch(pipe) main;
