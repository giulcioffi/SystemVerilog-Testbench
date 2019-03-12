interface bus_ifc (input bit clk);
	bit reset;
	bit I_valid;
	bit [7:0]      I_data;
    	bit            I_end;
   	bit            I_ready;
    	bit [2:0]      O_start;
    	bit [2:0][5:0] O_length;
    	bit [2:0][7:0] O_data;
    	bit [2:0]      O_end;
    	bit [2:0]      O_req;
   	bit [2:0]      O_grant;


	default clocking ck @(posedge clk);
		default input #100ps output #100ps; // reading and writing skew
     			output           reset;
     			output           I_valid;
     			output           I_data;
     			output           I_end;
     			input            I_ready;
     			input            O_start;
     			input            O_length;
     			input            O_data;
     			input            O_end;
     			input            O_req;
    			output           O_grant;
  	endclocking

	modport TEST (clocking ck);
	

	sequence startOfPacket;
			( (!(reset) ##1 (reset and !(I_valid))[*] ##1 I_valid) 
			or (I_end ##1 !(I_valid)[*2:$] ##1 I_valid)
			or (!(reset) ##1 (reset and I_valid)) );
	endsequence


	GOP0_start1: assert property (@(negedge clk)disable iff (reset==0) (O_grant[0] and O_req[0])[*2] |=> O_start[0]);
	GOP1_start1: assert property (@(negedge clk) disable iff (reset==0) (O_grant[1] and O_req[1])[*2] |=> O_start[1]);
	GOP2_start1: assert property (@(negedge clk) disable iff (reset==0) (O_grant[2] and O_req[2])[*2] |=> O_start[2]);

	GOP0_start0: assert property (@(negedge clk) disable iff (reset==0) !(O_grant[0]) |-> nexttime[2] !(O_start[0]));
	GOP1_start0: assert property (@(negedge clk) disable iff (reset==0) !(O_grant[1]) |-> nexttime[2] !(O_start[1]));
	GOP2_start0: assert property (@(negedge clk) disable iff (reset==0) !(O_grant[2]) |-> nexttime[2] !(O_start[2]));

	GOP0_endOutOfTran: assert property (@(negedge clk) disable iff (reset==0) O_end[0] |=> !(O_end[0]) until O_start[0]);
	GOP1_endOutOfTran: assert property (@(negedge clk) disable iff (reset==0) O_end[1] |=> !(O_end[1]) until O_start[1]);
	GOP2_endOutOfTran: assert property (@(negedge clk) disable iff (reset==0) O_end[2] |=> !(O_end[2]) until O_start[2]);

	GOP0_reqNoFall: assert property (@(negedge clk) disable iff (reset==0) O_req[0] |-> O_req[0] until O_start[0]);
	GOP1_reqNoFall: assert property (@(negedge clk) disable iff (reset==0) O_req[1] |-> O_req[1] until O_start[1]);
	GOP2_reqNoFall: assert property (@(negedge clk) disable iff (reset==0) O_req[2] |-> O_req[2] until O_start[2]);

	GOP0_reqFall: assert property (@(negedge clk) disable iff (reset==0) O_req[0] |-> O_req[0] until O_start[0] |-> !(O_req[0]) until_with O_end[0] |=> !(O_req[0]) );
	GOP1_reqFall: assert property (@(negedge clk) disable iff (reset==0) O_req[1] |-> O_req[1] until O_start[1] |-> !(O_req[1]) until_with O_end[1] |=> !(O_req[1]) );
	GOP2_reqFall: assert property (@(negedge clk) disable iff (reset==0) O_req[2] |-> O_req[2] until O_start[2] |-> !(O_req[2]) until_with O_end[2] |=> !(O_req[2]) );

	GOP0_lengthToggle: assert property (@(negedge clk) disable iff (reset==0) (O_req[0] |=> $stable(O_length[0]) until_with O_end[0]) and (O_end[0] ##1 1|=>  $stable(O_length[0]) until O_req[0]) );
	GOP1_lengthToggle: assert property (@(negedge clk) disable iff (reset==0) (O_req[1] |=> $stable(O_length[1]) until_with O_end[1]) and (O_end[1] ##1 1|=>  $stable(O_length[1]) until O_req[1]) );
	GOP2_lengthToggle: assert property (@(negedge clk) disable iff (reset==0) (O_req[2] |=> $stable(O_length[2]) until_with O_end[2]) and (O_end[2] ##1 1|=>  $stable(O_length[2]) until O_req[2]) );

	GOP0_length: assert property (@(negedge clk) disable iff (reset==0) O_end[0] |=> (O_length[0] == 0) until O_req[0]);
	GOP1_length: assert property (@(negedge clk) disable iff (reset==0) O_end[1] |=> (O_length[1] == 0) until O_req[1]);
	GOP2_length: assert property (@(negedge clk) disable iff (reset==0) O_end[2] |=> (O_length[2] == 0) until O_req[2]);

	GOP0_endDuringTran: assert property (@(negedge clk) disable iff (reset==0) O_start[0] |-> (O_length[0] == 1 and O_end[0]) or (!(O_end[0]) until (O_length[0] == 0) |-> O_end[0]) );
	GOP1_endDuringTran: assert property (@(negedge clk) disable iff (reset==0) O_start[1] |-> (O_length[1] == 1 and O_end[1]) or (!(O_end[1]) until (O_length[1] == 0) |-> O_end[1]) );
	GOP2_endDuringTran: assert property (@(negedge clk) disable iff (reset==0) O_start[2] |-> (O_length[2] == 1 and O_end[2]) or (!(O_end[2]) until (O_length[2] == 0) |-> O_end[2]) );


	GIP_header: assert property (@(negedge clk)startOfPacket |-> 0) else $info("sending header");

	GIP_noWaitCycleAfterHeader: assert property (@(negedge clk) disable iff (reset==0) startOfPacket |=> I_valid);

	GIP_noStartIfNotReady: assert property (@(negedge clk) disable iff (reset==0) startOfPacket |-> I_ready);

	GIP_headerPortCheck: assert property (@(negedge clk) disable iff (reset==0) startOfPacket |-> (I_data[1:0]!=3));

	GIP_headerLengthCheck: assert property (@(negedge clk) disable iff (reset==0) startOfPacket |-> (I_data[7:2]>0 and I_data[7:2]<=12));

	GIP_intraPacketDelay: assert property (@(negedge clk) disable iff (reset==0) startOfPacket |-> (I_end |=> !(I_valid)[*2]));

	GIP_endOutOfTrans: assert property (@(negedge clk) disable iff (reset==0) startOfPacket |-> (I_end |=> (!(I_valid) and !(I_end)) until I_valid));


endinterface : bus_ifc




