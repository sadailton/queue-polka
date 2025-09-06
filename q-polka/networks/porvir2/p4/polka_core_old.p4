/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x800;
const bit<16> TYPE_SR_POLKA = 0x1234;


//Ethernet frame payload padding and P4
//https://github.com/p4lang/p4-spec/issues/587

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
    bit<160>   routeId;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
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
    bit<160>  routeId;
    bit<16>   etherType;
    bit<1> apply_sr;
    bit<1> apply_decap;
    bit<9> port;
    bit<3> qid;
    bit<8> qos;
}

struct polka_t_top {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
    bit<160>   routeId;
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
        meta.apply_sr = 0;
        transition verify_ethernet;
    }

    state verify_ethernet {
        //meta.etherType = packet.lookahead<polka_t_top>().etherType;
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_SR_POLKA: get_routeId;
            default: accept;
        }
    }

    state get_routeId {
		meta.apply_sr = 1;
        packet.extract(hdr.srcRoute);
        meta.routeId = hdr.srcRoute.routeId;
        //meta.routeId = packet.lookahead<polka_t_top>().routeId;
        //meta.qos = packet.lookahead<headers>().ipv4.diffserv;
        transition parser_ipv4;
    }

    state parser_ipv4 {
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
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    action drop() {
        mark_to_drop(standard_metadata);
    }

    action srcRoute_nhop() {

        bit<16> nbase=0;
        bit<64> ncount=4294967296*2;
        bit<16> nresult;
        bit<16> nport;

        bit<160>routeid = meta.routeId;

        bit<160>ndata = routeid >> 16;
        bit<16> dif = (bit<16>) (routeid ^ (ndata << 16));

        hash(nresult,
        HashAlgorithm.crc16_custom,
        nbase,
        {ndata},ncount);

        bit<16>nlabel = nresult ^ dif;
        nport = nlabel >> 3;
        bit<16>qid = nlabel << 13;
        
        //meta.qid = (bit<3>) (qid >> 13);
        meta.port = (bit<9>) nport;
    }

    apply {

		if (meta.apply_sr == 1) {

			srcRoute_nhop();
            standard_metadata.egress_spec = meta.port;
            
            if (hdr.ipv4.srcAddr == 0x0a000001) {
                standard_metadata.priority = (bit<3>)7; //h1

            } else if (hdr.ipv4.srcAddr == 0x0a000002) {

                standard_metadata.priority = (bit<3>)0; //h2
            } else {
                meta.qid = 0;
            }

		} else {
			drop();
		}

    }
}



/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

    apply {  hdr.ipv4.diffserv = (bit<8>)standard_metadata.qid; 
    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply {  
        update_checksum(
	    hdr.ipv4.isValid(),
            { 
                hdr.ipv4.version,
                hdr.ipv4.ihl,
                hdr.ipv4.diffserv,
                hdr.ipv4.totalLen,
                hdr.ipv4.identification,
                hdr.ipv4.flags,
                hdr.ipv4.fragOffset,
                hdr.ipv4.ttl,
                hdr.ipv4.protocol,
                hdr.ipv4.srcAddr,
                hdr.ipv4.dstAddr 
            },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
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