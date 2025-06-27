`timescale 1ns / 1ps


module outputFIFO #(
	parameter   DATA_WIDTH      = 8,
	parameter   FIFO_DEPTH      = 4,
	parameter   FIFO_LOG2_DEPTH = 2
)
(
	input           				clk,
	input           				rst_n,

	input           				s_valid,
	output         				 	s_ready,
	input  [DATA_WIDTH-1:0]     	s_data,

	output          				m_valid,
	input           				m_ready,
	output [DATA_WIDTH-1:0]     	m_data,

    input wire                      i_EOL,
    output wire                     o_EOL,
    input wire                      i_tlast,
    output wire                     o_tlast
);


wire o_empty; // buffer empty
wire o_full;  // buffer full

wire i_hs = s_valid & s_ready; // input handshake
wire o_hs = m_valid & m_ready; // output handshake


reg  [FIFO_LOG2_DEPTH-1:0]   	wptr, wptr_next;
reg             				wptr_round, wptr_round_next;
reg  [FIFO_LOG2_DEPTH-1:0]   	rptr, rptr_next;
reg             				rptr_round, rptr_round_next;

// FIFO
reg  [DATA_WIDTH-1:0]       	data_fifo [FIFO_DEPTH-1:0]; 
reg                             EOL_fifo  [FIFO_DEPTH-1:0];
reg                             tlast_fifo[FIFO_DEPTH-1:0];

integer i;


// ------------------------- FIFO -----------------------------
always @(posedge clk) 
begin
	if (!rst_n) begin
		for (i=0; i<FIFO_DEPTH; i=i+1) begin
			data_fifo[i] <= {(DATA_WIDTH){1'b0}};
            EOL_fifo[i] <= 1'b0;
            tlast_fifo[i] <= 1'b0;
        end
	end else if (i_hs) begin
		data_fifo[wptr] <= s_data;
        EOL_fifo[wptr] <= i_EOL;
        tlast_fifo[wptr] <= i_tlast;
	end
end


// --------------------- write pointer ------------------------
always @(posedge clk) 
begin
	if (!rst_n) begin
		wptr <= 0;
		wptr_round <= 0;
	end 
	else if (i_hs) begin
		{wptr_round,wptr} <= {wptr_round_next,wptr_next};
	end
end

always @(*) 
begin
	if (wptr == (FIFO_DEPTH-1)) begin
		wptr_next = 0;
		wptr_round_next = ~wptr_round;
	end else begin
		wptr_next = wptr + 'd1;
		wptr_round_next = wptr_round;
	end
end


// --------------------- read pointer --------------------------
always @(posedge clk) 
begin
	if (!rst_n) begin
		rptr <= 0;
		rptr_round <= 0;
	end else if (o_hs) begin
		{rptr_round,rptr} <= {rptr_round_next,rptr_next};
	end
end

always @(*) 
begin
	if (rptr == (FIFO_DEPTH-1)) begin
		rptr_next = 0;
		rptr_round_next = ~rptr_round;
	end else begin
		rptr_next = rptr + 'd1;
		rptr_round_next = rptr_round;
	end
end


// output logic
assign m_data = data_fifo[rptr];
assign o_EOL = EOL_fifo[rptr];
assign o_tlast = tlast_fifo[rptr];

assign o_empty = (wptr_round == rptr_round) && (wptr == rptr);
assign o_full = (wptr_round != rptr_round) && (wptr == rptr);

assign s_ready = ~o_full;
assign m_valid = ~o_empty;

endmodule