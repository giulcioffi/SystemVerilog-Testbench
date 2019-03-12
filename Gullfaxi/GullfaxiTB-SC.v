program Gullfaxi_tb (bus_ifc.TEST busif, input bit clk);
	parameter nrPkts = 15;
	parameter invProbWaitCycle = 25;
	parameter minWaitForSend = 2;
	parameter maxWaitForSend = 5;
	parameter minWaitForGrant = 1;
	parameter maxWaitForGrant = 4;
   
  typedef struct {bit [5:0] len; bit [1:0] port; byte payload[$];} packet_s;
  packet_s pack, packet_check, packet_rcv0, packet_rcv1, packet_rcv2, queue_pack_push[$];
  packet_s queue_pack_check[$];
  typedef enum int {A, F, N, S} source_packet_e;
  


  class Packet;
	rand bit [5:0] length;
	rand bit [1:0] out_port;
	rand byte payl[];
	rand source_packet_e source_packet;
	bit xor_value;


	
	constraint c_port { if (source_packet == A) {
							 out_port dist {0:=0, 1:=90, 2:=10, 3:=0}; 
							 length inside {2,4,6,8,10};
							 payl.size() == length; }
			    else if (source_packet == F) {
							 out_port dist {0:=0, 1:=90, 2:=10, 3:=0}; 
							 length inside {3,5,7,9,11};
							 payl.size() == length; }
			    else if (source_packet == N) {
							 out_port inside {0, 1, 2};
							 length dist {[1:4]:/0, 5:=22, [6:12]:/78};
							 payl.size() == length; }
			    else 			{
							  out_port inside {[1:2]};
							  if (out_port == 1) { length inside {[1:8]}; }
							  else { length inside {[1:10]}; }
							  payl.size() == length; }

				solve source_packet before out_port;
				solve out_port before length;
				solve length before payl;
			 }

	function void post_randomize();
		if (source_packet == F) payl[length-1]=payl.xor(x) with ((x.index() < (length-1))*x);
	endfunction

  endclass



  class Packet_read;
	bit [5:0] length;
	bit [1:0] out_port;
	byte payl[12];
  endclass;




  class Randoms;

        rand bit wait_state;
     	constraint c_wait { wait_state dist {0:=(100-invProbWaitCycle), 1:=(invProbWaitCycle)}; }
     	rand int w_cycles_send;
     	constraint c_cycles_send { w_cycles_send inside {[minWaitForSend:maxWaitForSend]}; }
	rand int w_cycles_grant;
	constraint c_cycles_grant {w_cycles_grant inside {[minWaitForGrant:maxWaitForGrant]}; }

  endclass


  class Generator;


	Packet p;
	mailbox #(packet_s) mbx_gen;
	mailbox #(packet_s) mbx_scor;
	covergroup cg; 
		source_packet: coverpoint p.source_packet {
				bins A = {A};
				bins F = {F};
				bins N = {N};
				bins S = {S};
				}
		out_port: coverpoint p.out_port {
				bins out_port_0 = {0};
				bins out_port_1 = {1};
				bins out_port_2 = {2};
				ignore_bins out_port = {3};
				}
		length:  coverpoint p.length {
				bins length[] = {[1:12]};
				ignore_bins length_not_val = {0, 13, 14, 15};
				}
		cross source_packet, out_port {
				ignore_bins pck_portA = binsof(source_packet.A) && binsof(out_port.out_port_0);
				ignore_bins pck_portF = binsof(source_packet.F) && binsof(out_port.out_port_0);
				ignore_bins pck_portS = binsof(source_packet.S) && binsof(out_port.out_port_0);
		}
		cross source_packet, length{
				ignore_bins pck_lenA = binsof(source_packet.A) && binsof(length) intersect {1,3,5,7,9,11};
				ignore_bins pck_lenF = binsof(source_packet.F) && binsof(length) intersect {1,2,4,6,8,10,12};
				ignore_bins pck_lenN = binsof(source_packet.N) && binsof(length) intersect {[0:4]};
				ignore_bins pck_lenS = binsof(source_packet.S) && binsof(length) intersect {[11:12]};
		}
		cross length, out_port{
				ignore_bins len_port = binsof(out_port.out_port_0) && binsof(length) intersect {[1:4]};
		}
		transitions: coverpoint p.source_packet {
				bins four_A = (A => A => A => A);
				bins four_F = (F => F => F => F);
				bins eight_A = (A => A => A => A => A => A => A => A);
				bins eight_F = (F => F => F => F => F => F => F => F);
				bins A_FFF_A = (A => F[*3] => A);
				bins A_FFFFFF_A = (A => F[*6] => A);
				bins A_XXXXXX_A = (A => A, F, N, S => A, F, N, S => A, F, N, S => A, F, N, S => A, F, N, S => A, F, N, S => A);	
				bins four_eight_N_A = (N[*4:8] => A);
				bins A_F_and_F_A = (A => F), (F => A);
				bins AorF_NNN_S = (A, F => N => N => N => S);
				bins ten_AorF = (A, F => A, F => A, F => A, F => A, F => A, F => A, F => A, F => A, F => A, F);
				}
	endgroup

	function new(input mailbox #(packet_s) mbx_gen, input mailbox #(packet_s) mbx_scor);
		this.mbx_gen = mbx_gen;
		this.mbx_scor = mbx_scor;
		cg = new();
	endfunction

	task generate_packets();
     		repeat (nrPkts) begin
			p = new();
			p.randomize();	// with {source_packet dist {A:=5, F:=75, N:=10, S:=10}; out_port dist {[0:2]:/100, 3:/0}; }; 
			cg.sample();
			pack.len = p.length;
			pack.port = p.out_port;
			for (int i = 0; i < p.length; i++) begin
				pack.payload[i] = p.payl[i];
			end
			
			mbx_gen.put(pack);
			mbx_scor.put(pack);
     		end
	endtask
  endclass



  class cover_DUTsignals;
	covergroup cg_DUT;
	
	I_ready1: coverpoint busif.ck.I_ready;
	I_ready2: coverpoint busif.ck.I_ready {
			bins one_zero_one = (1 => 0 => 1);
			bins one_zero_zero_one = (1 => 0 => 0 => 1);
			bins one_zero_zero_zero_one = (1 => 0[*3] => 1);
			bins one_fourtotwelvezeros_one = (1 => 0[*4:12] => 1);
			bins hundred0 = (0[*100]);
			bins hundred1 = (1[*100]);
		  }
	O_req	: coverpoint busif.ck.O_req {
			illegal_bins O_req = {3,5,6,7};
		  }
	O_start0: coverpoint busif.ck.O_start[0];
	O_start1: coverpoint busif.ck.O_start[1];
	O_start2: coverpoint busif.ck.O_start[2];
	O_end0	: coverpoint busif.ck.O_end[0];
	O_end1	: coverpoint busif.ck.O_end[1];
	O_end2	: coverpoint busif.ck.O_end[2];
	cross O_start0, O_end0;
	cross O_start1, O_end1;
	cross O_start2, O_end2;
	
	endgroup

	function new();
		cg_DUT = new();
	endfunction

	task cover_signals();
     		forever begin
			@(negedge clk);
			cg_DUT.sample();
     		end
	endtask
  endclass 
  

  class Driver; 

	packet_s packet_send;
	Packet p;
	int count;
	byte num;
	Randoms r;
	mailbox #(packet_s) mbx_gen;

	function new(input mailbox #(packet_s) mbx_gen);
		this.mbx_gen = mbx_gen;
	endfunction

	task GIP_driver();
     		while(mbx_gen.num()>0) begin
			count = 0;
			busif.ck.I_end <= 0;
			r = new();
			@(busif.ck);
			if (busif.ck.I_ready == 0) begin
				@(busif.ck.I_ready);
			end 
			mbx_gen.get(packet_send);
			
			//$display("Length: %d", packet_send.len);
			busif.ck.I_valid <= 1;
			num[7:2] <= packet_send.len;
			num[1:0] <= packet_send.port;
			busif.ck.I_data <= {packet_send.len, packet_send.port};
			//$display("Length,port: %h", num);
			@(busif.ck);

				while (count < packet_send.len) begin
					r.randomize();
						if (!r.wait_state) begin
							if (count == (packet_send.len-1)) begin
								busif.ck.I_data <= packet_send.payload[count];
								busif.ck.I_end <= 1;
								busif.ck.I_valid <= 1;
								@(busif.ck);
								count++;
								busif.ck.I_end <= 0;
								busif.ck.I_valid <= 0;
								repeat (r.w_cycles_send)
									@(busif.ck);
							end
							else begin
								busif.ck.I_data <= packet_send.payload[count];
								busif.ck.I_valid <= 1;
								@(busif.ck);
								count++;
							end
						end
						else begin
							if (count == 0) begin
								busif.ck.I_data <= packet_send.payload[0];
								busif.ck.I_valid <= 1;
								if (packet_send.len == 1) begin
									busif.ck.I_end <= 1;
									@(busif.ck);
									busif.ck.I_end <= 0;
									busif.ck.I_valid <= 0;
									count++;
									repeat (r.w_cycles_send)
										@(busif.ck);
								end
								@(busif.ck);
								count++;
							end
							else begin
								busif.ck.I_valid <= 0;
								busif.ck.I_end <= 0;
								@(busif.ck);
							end
						end	
				end
		end
	endtask

  endclass

	


  class Monitor;

	Packet_read p0, p1, p2;
	Randoms r_gen0;
	int count_length0;
	Randoms r_gen1;
	int count_length1;
	Randoms r_gen2;
	int count_length2;
	byte pack_read0, pack_read1, pack_read2;
	bit [5:0] length0, length1, length2;
	bit [1:0] port0, port1, port2;
	mailbox #(Packet_read) mbx;

	function new(input mailbox #(Packet_read) mbx);
		this.mbx = mbx;
	endfunction

	task GOP_0();
		forever begin
			p0 = new();
			r_gen0 = new();
			busif.ck.O_grant[0] <= 0;
			@(busif.ck.O_req[0]);
			count_length0 = 0;
  			r_gen0.randomize();
			repeat (r_gen0.w_cycles_grant)
			@(busif.ck);
			busif.ck.O_grant[0] <= 1;
			@(busif.ck.O_start[0]);
			busif.ck.O_grant[0] <= 0;
			//$display("Received packet on port 0.");

			while (busif.ck.O_end[0] != 1) begin
				if (count_length0 < 12) begin
					p0.payl[count_length0] <= busif.ck.O_data[0];
				end
				count_length0++;
				//$display("Byte received: %d.", busif.ck.O_data[0]);
				@(busif.ck);
			end
			p0.payl[count_length0] <= busif.ck.O_data[0];
			count_length0++;
			//$display("Byte received: %d.", busif.ck.O_data[0]);

			p0.length <= count_length0;
			p0.out_port <= 2'b00;

			mbx.put(p0);

			@(busif.ck);
			
		end		

	endtask


//GOP_1
	task GOP_1();
		forever begin
			p1 = new();
			r_gen1 = new();
			busif.ck.O_grant[1] <= 0;
			@(busif.ck.O_req[1]);
			count_length1 = 0;
  			r_gen1.randomize();
			repeat (r_gen1.w_cycles_grant)
				@(busif.ck);
			busif.ck.O_grant[1] <= 1;
			@(busif.ck.O_start[1]);
			busif.ck.O_grant[1] <= 0;
			p1.payl[0] <= busif.ck.O_data[1];
				
			//$display("Received packet on port 1.");
			
			if (busif.ck.O_end[1] == 1) begin
				count_length1++;
				//$display("Byte received: %d.", busif.ck.O_data[1]);

				p1.length <= 1;
				p1.out_port <= 2'b01;
				mbx.put(p1);				

				@(busif.ck);
			end
			else begin
				count_length1++;
				@(busif.ck);
				while (busif.ck.O_end[1] != 1) begin
					if (count_length1 < 12) begin
						p1.payl[count_length1] <= busif.ck.O_data[1];
					end
					count_length1++;
					//$display("Byte received: %d.", busif.ck.O_data[1]);
					@(busif.ck);
				end
				p1.payl[count_length1] <= busif.ck.O_data[1];
				count_length1++;
				//$display("Byte received: %d.", busif.ck.O_data[1]);

				p1.length <= count_length1;
				p1.out_port <= 2'b01;
				mbx.put(p1);

				@(busif.ck);
			end

		end		

	endtask




//GOP_2
	task GOP_2();
		forever begin
			p2 = new();
			r_gen2 = new();
			busif.ck.O_grant[2] <= 0;
			@(busif.ck.O_req[2]);
			count_length2 = 0;
  			r_gen2.randomize();
			repeat (r_gen2.w_cycles_grant)
				@(busif.ck);
			busif.ck.O_grant[2] <= 1;
			@(busif.ck.O_start[2]);
			busif.ck.O_grant[2] <= 0;
			p2.payl[0] <= busif.ck.O_data[2];
				
			//$display("Received packet on port 2.");
			
			if (busif.ck.O_end[2] == 1) begin
				count_length2++;
				//$display("Byte received: %d.", busif.ck.O_data[2]);

				p2.length <= 2;
				p2.out_port <= 2'b10;
				mbx.put(p2);				

				@(busif.ck);
			end
			else begin
				count_length2++;
				@(busif.ck);
				while (busif.ck.O_end[2] != 1) begin
					if (count_length2 < 12) begin
						p2.payl[count_length2] <= busif.ck.O_data[2];
					end
					count_length2++;
					//$display("Byte received: %d.", busif.ck.O_data[2]);
					@(busif.ck);
				end
				p2.payl[count_length2] <= busif.ck.O_data[2];
				count_length2++;
				//$display("Byte received: %d.", busif.ck.O_data[2]);

				p2.length <= count_length2;
				p2.out_port <= 2'b10;
				
				mbx.put(p2);

				@(busif.ck);
			end

		end		

	endtask


  endclass


  class Scoreboard;

	Packet_read p;
	mailbox #(Packet_read) mbx;
	mailbox #(packet_s) mbx_scor;
	int count_packets;

	function new(input mailbox #(Packet_read) mbx, input mailbox #(packet_s) mbx_scor);
		this.mbx = mbx;
		this.mbx_scor = mbx_scor;
	endfunction

	task check();
	count_packets = 0;
		while(mbx_scor.num()>0) begin
			mbx.get(p);
			mbx_scor.get(packet_check);
			count_packets++;
			if (packet_check.port != p.out_port) begin
				//$display("Packet %d received on the wrong port.", count_packets);
			end
			if (packet_check.len != p.length) begin
				//$display("Packet %d of the wrong length: length should be %d, but is %d.", count_packets, packet_check.len, p.length);
			end
		end
	endtask

  endclass




	mailbox #(Packet_read) mbx;
	mailbox #(packet_s) mbx_gen;
	mailbox #(packet_s) mbx_scor;
	Generator g;
	Driver dr;
	Monitor mon;
	Scoreboard s;
	cover_DUTsignals cDUTs;


   initial begin
	mbx = new();
	mbx_gen = new();
	mbx_scor = new();	
	g = new(mbx_gen, mbx_scor);
	dr = new(mbx_gen);
	mon = new(mbx);
	s = new(mbx, mbx_scor);
	cDUTs = new();
	busif.ck.reset <= 0;
	g.generate_packets();
	
        repeat (5)
	@(busif.ck);
	busif.ck.reset <= 1;
	@(busif.ck);

	fork
		cDUTs.cover_signals();
		fork
			dr.GIP_driver();
			mon.GOP_0();
			mon.GOP_1();
			mon.GOP_2();
			s.check();
		join
	join_any
	$assertkill;
   end


endprogram



