/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x800;
const bit<16> TYPE_SRCROUTING = 0x1234;


//Ethernet frame payload padding and P4
//https://github.com/p4lang/p4-spec/issues/587

// Define macros para o v1model
#define READ_REG(reg_instance, out_var, index)  reg_instance.read(out_var, index)
#define WRITE_REG(reg_instance, index, in_var)  reg_instance.write(index, in_var)

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header srcRoute_t {
    bit<160>    routeId;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<2>    ecn;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

struct metadata {
    bit<160>   routeId;
    bit<16>   etherType;
    bit<1> apply_sr;
    bit<9> port;
    bit<48> ts;
    bit<32> slice_id;
    bit<1> dropFlag;
}

struct polka_t_top {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
    bit<160>    routeId;
}

struct headers {
    ethernet_t  ethernet;
    srcRoute_t  srcRoute;
    ipv4_t      ipv4;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

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
            TYPE_IPV4: parse_ipv4;
            TYPE_SRCROUTING: parse_srcRouting;
            default: accept;
        }
    }

    state parse_srcRouting {
        packet.extract(hdr.srcRoute);
        transition accept;
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }


}


/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}


/*************************************************************************
**********************  T U N N E L   E N C A P   ************************
*************************************************************************/
control process_tunnel_encap(inout headers hdr,
                            inout metadata meta,
                            inout standard_metadata_t standard_metadata) {

    // Exemplo (assumindo 256 slices e timestamp de 64 bits)
    register<bit<64>>(256) slice_ts;
    //
    // Exemplo (assumindo 256 slices e delay de 32 bits)
    register<bit<32>>(256) slice_delay;

   
    
    action tdrop() {
        mark_to_drop(standard_metadata);
    }

    action add_sourcerouting_header (   egressSpec_t port, bit<1> sr, macAddr_t dmac,
                                        bit<160>  routeIdPacket) {

        standard_metadata.egress_spec = port;
        meta.apply_sr = sr;

        hdr.ethernet.dstAddr = dmac;

        hdr.srcRoute.setValid();
        hdr.srcRoute.routeId = routeIdPacket;
        
    }

    action queue_management(bit<64> T_DELAY, bit<64> C_DELAY, bit<64> M_DELAY) {

        bit<48> delay = 0;
        //meta.ts = intrinsic_metadata.ingress_global_timestamp;
        meta.ts = standard_metadata.ingress_global_timestamp;
        bit<48> c_ts = meta.ts;
        bit<48> p_ts;
        bit<48> delta = 0;

        @atomic {
            READ_REG(slice_ts, p_ts, meta.slice_id);
            WRITE_REG(slice_ts, meta.slice_id, c_ts);
        }

        if ((p_ts == 0) || (p_ts > c_ts)) {
            p_ts = c_ts;
        }

        delta = c_ts - p_ts;
        
        if (delta >= 3294967296) {
            delta = delta - 3294967296;
        }

        @atomic {
            READ_REG(slice_delay, delay, meta.slice_id);
            if (delta > delay) {
                delay = 0;
            } else {
                delay = delay - delta;
            }
            if (delay + T_DELAY > C_DELAY) {
                meta.dropFlag = 1;
            } else {
                delay = delay + T_DELAY;
            }

            WRITE_REG(slice_delay, meta.slice_id, delay);
        }

        if ((meta.dropFlag == 0) && (hdr.ipv4.ecn != 0) && (delay > M_DELAY)) {
            hdr.ipv4.ecn = 3;
        }
    }

    table tunnel_encap_process_sr {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            add_sourcerouting_header;
            tdrop;
        }
        size = 1024;
        default_action = tdrop();
    }

    apply {

        tunnel_encap_process_sr.apply();

        if (meta.apply_sr!=1) {
            
            hdr.srcRoute.setInvalid();

        } else {

            hdr.ethernet.etherType = TYPE_SRCROUTING;
        }
    }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    
    action drop() {
        mark_to_drop(standard_metadata);
    }

    apply {

    	if (hdr.ipv4.isValid() && hdr.ethernet.etherType != TYPE_SRCROUTING) {
            process_tunnel_encap.apply(hdr, meta, standard_metadata);
        } else if (hdr.ethernet.etherType == TYPE_SRCROUTING) {
            hdr.ethernet.etherType = TYPE_IPV4;
            hdr.srcRoute.setInvalid();
            standard_metadata.egress_spec = 1;

            //standard_metadata.priority = (bit<3>)hdr.ipv4.diffserv;
		}

    }
}



/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
                    
    apply { }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
    apply {   }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.srcRoute);
        packet.emit(hdr.ipv4);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;