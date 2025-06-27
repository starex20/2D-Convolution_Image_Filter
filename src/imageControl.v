`timescale 1ns / 1ps

module imageControl #(
    parameter DATA_WIDTH            = 8,
              IMAGE_WIDTH_SIZE      = 512,
              IMAGE_WIDTH_LOG2_SIZE = 9
)(  
    input wire                              clk,
    input wire                              rst_n,
    input wire [DATA_WIDTH-1:0]             s_data,
    input wire                              s_valid,
    output wire                             s_ready,
    output reg [DATA_WIDTH*9-1:0]           m_data,
    output wire                             m_valid,
    input wire                              m_ready,
    input wire                              i_EOL,
    output wire                             o_EOL,
    output wire                             o_tlast,
    output wire                             run
);


//----------------------- Local signal -------------------
    reg [1:0]                        currentWrLineCounter;
    reg [3:0]                        lineBuf_s_valid;
    reg [3:0]                        lineBuf_m_ready;
    reg [1:0]                        currentRdLineCounter;
    wire [DATA_WIDTH*3-1:0]          lb0data;
    wire [DATA_WIDTH*3-1:0]          lb1data;
    wire [DATA_WIDTH*3-1:0]          lb2data;
    wire [DATA_WIDTH*3-1:0]          lb3data;
    reg [IMAGE_WIDTH_LOG2_SIZE-1:0]  rdEOLCounter;
    //wire [IMAGE_WIDTH_LOG2_SIZE-1:0] nextRdEOL;
    wire                             threeLineBuf_ready;
    wire                             allLineBufFull;
    reg [2:0]                        totalEOLCounter;
    reg                              rdState;
    wire [3:0]                       lbEOL;

    localparam IDLE = 'b0, 
               READ = 'b1;


assign i_hs = s_valid & s_ready; // input handshake
assign o_hs = m_valid & m_ready; // output handshake

assign m_valid = threeLineBuf_ready;
assign s_ready = !allLineBufFull & run;

// total EOL counter
always @(posedge clk)
begin
    if(!rst_n)
        totalEOLCounter <= 0;
    else
    begin
        if(i_hs && i_EOL) begin
            if(!o_EOL)
                totalEOLCounter <= totalEOLCounter + 1;
        end
        else begin
            if(o_EOL)
                totalEOLCounter <= totalEOLCounter - 1;
        end
    end
end

assign allLineBufFull = (totalEOLCounter == 4);


always @(posedge clk)
begin
    if(!rst_n) 
        rdState <= IDLE;
    else 
    begin
        case(rdState)
            IDLE:begin
                if(totalEOLCounter >= 3)
                    rdState <= READ;
            end
            READ:begin
                if(o_EOL)
                    rdState <= IDLE;
            end
        endcase
    end
end

assign threeLineBuf_ready = (rdState == READ);
    


// write Line buffer position counter
always @(posedge clk)
begin
    if(!rst_n)
        currentWrLineCounter <= 0;
    else
    begin
        if(i_hs && i_EOL)
            currentWrLineCounter <= currentWrLineCounter + 1;
    end
end


always @(*)
begin
    lineBuf_s_valid = 4'h0;
    lineBuf_s_valid[currentWrLineCounter] = i_hs;
end


// read pixel counter
always @(posedge clk)
begin
    if(!rst_n)
        rdEOLCounter <= 0;
    else 
    begin
        if(o_EOL)
            rdEOLCounter <= rdEOLCounter + 1;
         else if(rdEOLCounter == IMAGE_WIDTH_SIZE - 2)
            rdEOLCounter <= 'b0;
    end
end

assign o_tlast = (rdEOLCounter == IMAGE_WIDTH_SIZE - 3) && o_EOL;


// read line buffer position counter
always @(posedge clk)
begin
    if(!rst_n)
        currentRdLineCounter <= 0;
    else begin
        if(o_EOL) 
            currentRdLineCounter <= currentRdLineCounter + 1;
    end
end


always @(*)
begin
    case(currentRdLineCounter)
        0:begin
            m_data = {lb2data,lb1data,lb0data};
        end
        1:begin
            m_data = {lb3data,lb2data,lb1data};
        end
        2:begin
            m_data = {lb0data,lb3data,lb2data};
        end
        3:begin
            m_data = {lb1data,lb0data,lb3data};
        end
    endcase
end

always @(*)
begin
    case(currentRdLineCounter)
        0:begin
            lineBuf_m_ready[0] = o_hs;
            lineBuf_m_ready[1] = o_hs;
            lineBuf_m_ready[2] = o_hs;
            lineBuf_m_ready[3] = 1'b0;
        end
       1:begin
            lineBuf_m_ready[0] = 1'b0;
            lineBuf_m_ready[1] = o_hs;
            lineBuf_m_ready[2] = o_hs;
            lineBuf_m_ready[3] = o_hs;
        end
       2:begin
             lineBuf_m_ready[0] = o_hs;
             lineBuf_m_ready[1] = 1'b0;
             lineBuf_m_ready[2] = o_hs;
             lineBuf_m_ready[3] = o_hs;
       end  
      3:begin
             lineBuf_m_ready[0] = o_hs;
             lineBuf_m_ready[1] = o_hs;
             lineBuf_m_ready[2] = 1'b0;
             lineBuf_m_ready[3] = o_hs;
       end        
    endcase
end

assign o_EOL = |lbEOL[3:0];
    
lineBuffer #(
   .DATA_WIDTH(DATA_WIDTH),
   .IMAGE_WIDTH_SIZE(IMAGE_WIDTH_SIZE),
   .IMAGE_WIDTH_LOG2_SIZE(IMAGE_WIDTH_LOG2_SIZE) 
) lB0(
   .clk(clk),
   .rst_n(rst_n),
   .s_data(s_data),
   .s_valid(lineBuf_s_valid[0]),
   .m_data(lb0data),
   .m_ready(lineBuf_m_ready[0]),
   .EOL(lbEOL[0])
); 
 
lineBuffer #(
   .DATA_WIDTH(DATA_WIDTH),
   .IMAGE_WIDTH_SIZE(IMAGE_WIDTH_SIZE),
   .IMAGE_WIDTH_LOG2_SIZE(IMAGE_WIDTH_LOG2_SIZE) 
) lB1(
   .clk(clk),
   .rst_n(rst_n),
   .s_data(s_data),
   .s_valid(lineBuf_s_valid[1]),
   .m_data(lb1data),
   .m_ready(lineBuf_m_ready[1]),
   .EOL(lbEOL[1])
); 
  
lineBuffer #(
   .DATA_WIDTH(DATA_WIDTH),
   .IMAGE_WIDTH_SIZE(IMAGE_WIDTH_SIZE),
   .IMAGE_WIDTH_LOG2_SIZE(IMAGE_WIDTH_LOG2_SIZE) 
) lB2(
  .clk(clk),
  .rst_n(rst_n),
  .s_data(s_data),
  .s_valid(lineBuf_s_valid[2]),
  .m_data(lb2data),
  .m_ready(lineBuf_m_ready[2]),
  .EOL(lbEOL[2])
); 
   
lineBuffer #(
   .DATA_WIDTH(DATA_WIDTH),
   .IMAGE_WIDTH_SIZE(IMAGE_WIDTH_SIZE),
   .IMAGE_WIDTH_LOG2_SIZE(IMAGE_WIDTH_LOG2_SIZE) 
) lB3(
   .clk(clk),
   .rst_n(rst_n),
   .s_data(s_data),
   .s_valid(lineBuf_s_valid[3]),
   .m_data(lb3data),
   .m_ready(lineBuf_m_ready[3]),
   .EOL(lbEOL[3])
);    
    
endmodule