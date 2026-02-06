/* =========================================================================
   P4_16 Program for DR_PIFO Scheduler Test
   Architecture: v1model (simple_switch)
   ========================================================================= */

#include <core.p4>
#include <v1model.p4>

/* -------------------------------------------------------------------------
   1. Headers and Metadata
   ------------------------------------------------------------------------- */
header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

struct headers {
    ethernet_t ethernet;
    ipv4_t     ipv4;
}

struct metadata {
    /* Metadata needed for your scheduler */
    bit<32> flow_id;
    bit<32> priority_rank;
}

/* -------------------------------------------------------------------------
   2. EXTERN DEFINITION
   ------------------------------------------------------------------------- */
extern DR_PIFO_scheduler {
    DR_PIFO_scheduler();
    void my_scheduler(in bit<32> flow_id, 
                      in bit<32> number_of_levels_used, 
                      in bit<32> pred, 
                      in bit<32> arrival_time, 
                      in bit<32> shaping, 
                      in bit<32> enq, 
                      in bit<32> pkt_ptr, 
                      in bit<32> use_queues_rank, 
                      in bit<32> use_updated_rank, 
                      in bit<32> force_deq, 
                      in bit<32> force_deq_flow_id, 
                      in bit<32> enable_error_correction, 
                      in bit<32> reset_time);
}

/* -------------------------------------------------------------------------
   3. Parser
   ------------------------------------------------------------------------- */
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            0x0800: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }
}

/* -------------------------------------------------------------------------
   4. Checksum Verification
   ------------------------------------------------------------------------- */
control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}

/* -------------------------------------------------------------------------
   5. Ingress Processing
   ------------------------------------------------------------------------- */
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    /* Instanciação do Extern */
    @name("dr_pifo") 
    DR_PIFO_scheduler() dr_pifo;

    action drop() {
        mark_to_drop(standard_metadata);
    }

    action ipv4_forward(bit<9> port) {
        standard_metadata.egress_spec = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    apply {
        if (hdr.ipv4.isValid()) {
            /* 1. Basic Routing */
            ipv4_lpm.apply();
            
            if (standard_metadata.egress_spec < 511 ){
                /* 2. Scheduler Logic - Agora com valores significativos */
                // Usa os 16 bits menos significativos do endereço fonte como flow_id
                meta.flow_id = (bit<32>)hdr.ipv4.srcAddr[15:0];
                
                // Usa DSCP como rank, convertendo de 8 para 32 bits
                meta.priority_rank = (bit<32>)hdr.ipv4.diffserv;
                
                /* Chamada do Extern com valores mais realistas */
                dr_pifo.my_scheduler(
                    meta.flow_id,           // flow_id
                    2,                      // number_of_levels_used
                    meta.priority_rank,     // pred (rank do pacote)
                    (bit<32>)standard_metadata.ingress_global_timestamp, // arrival_time
                    0,                      // shaping (desabilitado inicialmente)
                    1,                      // enq (sempre enfileira)
                    0,                      // pkt_ptr (ignorado, usamos ingress_pkt_id)
                    0,                      // use_queues_rank
                    0,                      // use_updated_rank
                    0,                      // force_deq
                    0,                      // force_deq_flow_id
                    0,                      // enable_error_correction
                    0                       // reset_time
                );
            }
        }
    }
}

/* -------------------------------------------------------------------------
   6. Egress Processing
   ------------------------------------------------------------------------- */
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { 
        /* Bloco vazio intencionalmente */
    }
}

/* -------------------------------------------------------------------------
   7. Checksum Computation
   ------------------------------------------------------------------------- */
control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply {
        update_checksum(
            hdr.ipv4.isValid(),
            { hdr.ipv4.version, hdr.ipv4.ihl, hdr.ipv4.diffserv, hdr.ipv4.totalLen,
              hdr.ipv4.identification, hdr.ipv4.flags, hdr.ipv4.fragOffset,
              hdr.ipv4.ttl, hdr.ipv4.protocol, hdr.ipv4.srcAddr, hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16
        );
    }
}

/* -------------------------------------------------------------------------
   8. Deparser
   ------------------------------------------------------------------------- */
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

/* -------------------------------------------------------------------------
   9. Switch Instantiation
   ------------------------------------------------------------------------- */
V1Switch(
    MyParser(),
    MyVerifyChecksum(),
    MyIngress(),
    MyEgress(),
    MyComputeChecksum(),
    MyDeparser()
) main;