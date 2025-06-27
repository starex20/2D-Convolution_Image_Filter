`timescale 1ns / 1ps


module lineBuffer #(
    parameter DATA_WIDTH            = 8,
              IMAGE_WIDTH_SIZE      = 512,
              IMAGE_WIDTH_LOG2_SIZE = 9
)(
    input wire                              clk,
    input wire                              rst_n,
    input wire [DATA_WIDTH-1:0]             s_data,
    input wire                              s_valid,
    output wire [DATA_WIDTH*3-1:0]          m_data,
    input wire                              m_ready,
    output wire                             EOL
);

    wire [IMAGE_WIDTH_LOG2_SIZE-1:0]  read_ptr1, read_ptr2, read_ptr3;

    reg [DATA_WIDTH-1:0]              line [IMAGE_WIDTH_SIZE-1:0]; //line buffer
    reg [IMAGE_WIDTH_LOG2_SIZE-1:0]   wptr;
    reg [IMAGE_WIDTH_LOG2_SIZE-1:0]   rptr;

always @(posedge clk)
begin
    if(s_valid)
        line[wptr] <= s_data;
end

always @(posedge clk)
begin
    if(!rst_n)
        wptr <= 'd0;
    else if(s_valid)
        wptr <= wptr + 'd1;
end

assign read_ptr1 = rptr;
assign read_ptr2 = rptr+1;
assign read_ptr3 = rptr+2;

//assign m_data = {line[rptr],line[rptr+1],line[rptr+2]};
assign m_data = {line[read_ptr1],line[read_ptr2],line[read_ptr3]};

always @(posedge clk)
begin
    if(!rst_n)
        rptr <= 'd0;
    else if(m_ready)
        rptr <= rptr + 'd1;
end

assign EOL = m_ready && (rptr == IMAGE_WIDTH_SIZE - 1); // when last bit of line read

endmodule