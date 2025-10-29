/***************** M A T C H - A C T I O N  *********************/
control Ingress(
    /* User */
    inout ingress_headers_t                       hdr,
    inout ingress_metadata_t                      meta,
    /* Intrinsic */
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md) {


    CRCPolynomial<bit<16>>(SWITCH_ID, false, false, false, 16w0x0000, 16w0x0000) crc16d;
    Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc16d) hash3;

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    action send(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
#ifdef BYPASS_EGRESS
        ig_tm_md.bypass_egress = 1;
#endif      // BYPASS_EGRESS
    }

    action srcRoute_nhop() {

        bit<16> nbase=0;
        bit<64> ncount=4294967296*2;
        bit<16> nresult;
        bit<16> nport;

        routeid_t ndata = meta.routeId >> 16;
        bit<16> dif = (bit<16>) (meta.routeId ^ (ndata << 16));

        //nresult = hash3.get((routeid_t) ndata);
        nresult = meta.hash_result;

        bit<16> nlabel = nresult ^ dif;

        bit<16> porta_saida = nlabel >> 3;
        bit<16> qid_temp = nlabel << 13;

        meta.port = (bit<9>) porta_saida;
        meta.queue_id = (bit<3>)(qid_temp >> 13); 

    }

    apply {

        if (meta.apply_sr == 1) {

            meta.hash_result = hash3.get((routeid_t) meta.routeId >> 16);
            srcRoute_nhop();

            ig_tm_md.qid = (bit<7>)meta.queue_id; //ig_tm_md.qid usa 7 bits ao inves de 3 do v1model.
            send(meta.port);

        } else {

            drop();
        }
    }
}