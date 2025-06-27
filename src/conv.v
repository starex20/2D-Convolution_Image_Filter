`timescale 1ns / 1ps


module conv #(
    parameter DATA_WIDTH = 8
)(
    input wire                           clk,
    input wire                           rst_n,
    input wire [DATA_WIDTH*9-1:0]        s_data,
    input wire                           s_valid,
    output wire                          s_ready,
    output wire [DATA_WIDTH-1:0]         m_data,
    output wire                          m_valid,
    input wire                           m_ready,
    input wire                           i_EOL,
    output wire                          o_EOL,
    input wire                           i_tlast,
    output wire                          o_tlast,
    input wire                           start,
    input wire [26:0]                    filter_weights
);
    

//----------------------- Local signal -------------------
    localparam                D_IDLE=1'b0, D_ADD=1'b1;
    reg [DATA_WIDTH-1:0]      kernel [8:0];
    reg [DATA_WIDTH*2-1:0]    multData[8:0];
    reg [DATA_WIDTH*2-1:0]    sumDataTmp;
    reg [DATA_WIDTH*2-1:0]    sumData;
    reg [DATA_WIDTH-1:0]      convolved_data;
    reg                       mult_valid;
    reg                       sum_valid;
    reg                       convolved_data_valid;
    reg                       mult_EOL, add_EOL, divide_EOL;
    reg                       mult_tlast, add_tlast, divide_tlast;
    reg [5:0]                 divisor;
    wire [5:0]                nextDivisor;          
    reg                       divisorAddState, nextDivisorAddState;
    reg [3:0]                 divisorAddCounter;
    wire                      addCountDone;
    integer i; 


assign m_valid = convolved_data_valid;
assign m_data = convolved_data;
assign s_ready = m_ready | !m_valid;
 

//------------- kernel weight initialization ----------------
always @(posedge clk)
begin
    if(start) begin
        for(i=0; i<9; i=i+1)
            kernel[i] <= filter_weights[3*i +: 3];
    end
end

always @(posedge clk)
begin
    if(!rst_n) 
        divisorAddState <= D_IDLE;
    else 
        divisorAddState <= nextDivisorAddState;
end

always @(*)
begin
    case(divisorAddState)
        D_IDLE:
            if (start)
                nextDivisorAddState = D_ADD;
            else
                nextDivisorAddState = D_IDLE;
        D_ADD:
            if (addCountDone)
                nextDivisorAddState = D_IDLE;
            else
                nextDivisorAddState = D_ADD;
    endcase
end

// weight sum counter
always @(posedge clk)
begin
    if(!rst_n) 
        divisorAddCounter <= 4'd0;
    else if(divisorAddState == D_ADD) begin
        if(addCountDone)
            divisorAddCounter <= 4'd0;
        else
            divisorAddCounter <= divisorAddCounter + 1;
    end
end

always @(posedge clk)
begin
    if(!rst_n) 
        divisor <= 6'b0;
    else if(divisorAddState == D_ADD) begin 
        divisor <= nextDivisor; //divisor + filter_weights[3*i +: 3];
    end
end

assign nextDivisor = divisorAddState == D_ADD ? divisor + filter_weights[divisorAddCounter*3 +: 3] : divisor;
assign addCountDone = (divisorAddCounter == 4'd8);

    
//-------------------- Multiplication stage ----------------------
always @(posedge clk)
begin
    for(i=0; i<9; i=i+1) begin
        multData[i] <= kernel[i]*s_data[i*8+:8];
    end
    mult_valid <= s_valid;
    
end

always @(posedge clk) 
begin
    mult_EOL <= i_EOL;
    mult_tlast <= i_tlast;
end

//-------------------- Add stage -------------------------
always @(*)
begin
    sumDataTmp = 0;
    for(i=0; i<9; i=i+1) begin
        sumDataTmp = sumDataTmp + multData[i];
    end
end

always @(posedge clk)
begin
    sumData <= sumDataTmp;
    sum_valid <= mult_valid;
end
    
always @(posedge clk) 
begin
    add_EOL <= mult_EOL;
    add_tlast <= mult_tlast;
end

//-------------------- Divider stage -------------------------
always @(posedge clk)
begin
    convolved_data <= sumData / divisor;
    convolved_data_valid <= sum_valid;
end

always @(posedge clk) 
begin
    divide_EOL <= add_EOL;
    divide_tlast <= add_tlast;
end

assign o_EOL = divide_EOL;
assign o_tlast = divide_tlast;
    
endmodule
