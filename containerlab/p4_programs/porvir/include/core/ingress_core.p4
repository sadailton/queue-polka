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


    CRCPolynomial<bit<16>>(ROUTE_ID, false, false, false, 16w0x0000, 16w0x0000) crc16d;
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

        routeid_t routeid = meta.routeId;
        //routeid = 57851202663303480771156315372;

        routeid_t ndata = routeid >> 16;
        bit<16> dif = (bit<16>) (routeid ^ (ndata << 16));

        nresult = hash3.get((routeid_t) ndata);
        nport = nresult ^ dif;

        meta.port = (bit<9>) nport;
    }

    apply {

        if (meta.apply_sr == 1) {

            srcRoute_nhop();
            send(meta.port);

        } else {

            drop();
        }
    }
}