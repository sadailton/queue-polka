-- Autor: Adailton Saraiva
-- Data: 2025-09-06
-- Descrição: NSSAI dissector for Wireshark
-- Versão: 0.1
--    This program is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--    This program is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--    You should have received a copy of the GNU General Public License
--    along with this program.  If not, see <https://www.gnu.org/licenses/>.


nssai_proto = Proto ("nssai","NSSAI")

local sst = ProtoField.uint8("nssai.sst", "SST (Slice/Service Type)", base.DEC)
local sd = ProtoField.uint24("nssai.sd", "SD (Slice/Differentiator)", base.DEC)
local next_proto = ProtoField.uint16("nssai.next_proto", "Next Protocol", base.HEX)

nssai_proto.fields = {sst, sd, next_proto}

local nssai_dissector_table = DissectorTable.new(
	"nssai.next_proto", "NSSAI Next Protocol", ftypes.UINT16, base.HEX
	)

-- nssaiproto dissector function
function nssai_proto.dissector (buf, pkt, root)
  -- validate packet length is adequate, otherwise quit
  pkt.cols.protocol = nssai_proto.name
  -- create subtree for nssaiproto
  subtree = root:add(nssai_proto, buf(0,6),"NSSAI Header")
  -- add protocol fields to subtree
  subtree:add(sst, buf(0,1)):append_text(" :SST (Slice/Service Type)")
  subtree:add(sd, buf(1,3)):append_text(" :SD (Slice Diffferentiator)")
  subtree:add(next_proto, buf(4,2)):append_text(" :Next Protocol")
  subtree:append_text(" Protocol")

  local next_proto_val = buf(4,2):uint()
  
  local next_buffer = buf(6):tvb()
  local polka_dissector = nssai_dissector_table:try(next_proto_val, next_buffer, pkt, root)

end

-- Initialization routine
function nssai_proto.init()
end

-- subscribe for Ethernet packets on type 9029 (0x2345).
local eth_table = DissectorTable.get("ethertype")
eth_table:add(9029, nssai_proto)
