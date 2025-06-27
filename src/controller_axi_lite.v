`timescale 1ns / 1ps



module controller_axi_lite #(
 parameter DATA_WIDTH = 32, ADDR_WIDTH = 2
)(
    input  wire                          clk,
    input  wire                          rst_n,

    input  wire [ADDR_WIDTH-1:0]         s_axi_control_awaddr,
    input  wire                          s_axi_control_awvalid,
    output wire                          s_axi_control_awready,

    input  wire [DATA_WIDTH-1:0]         s_axi_control_wdata,
    input  wire                          s_axi_control_wvalid,
    output wire                          s_axi_control_wready,

    output wire [1:0]                    s_axi_control_bresp,
    output wire                          s_axi_control_bvalid,
    input  wire                          s_axi_control_bready,

    input  wire [ADDR_WIDTH-1:0]         s_axi_control_araddr,
    input  wire                          s_axi_control_arvalid,
    output wire                          s_axi_control_arready,

    output wire [DATA_WIDTH-1:0]         s_axi_control_rdata,
    output wire [1:0]                    s_axi_control_rresp,
    output wire                          s_axi_control_rvalid,
    input  wire                          s_axi_control_rready,

    input wire                           tlast,
    output wire                          start,
    output wire                          run,
 output wire [26:0]                      filter_weights

);

// --------------------- parameter -----------------------
localparam
    // Register
    CTRL                   = 2'd0,
    STATUS                 = 2'd1,
    FILTER                 = 2'd2,

    //write FSM
    WRIDLE                 = 2'd0,
    WRDATA                 = 2'd1,
    WRRESP                 = 2'd2,
    WRRESET                = 2'd3,

    // read FSM
    RDIDLE                 = 2'd0,
    RDDATA                 = 2'd1,
    RDRESET                = 2'd2,
    
    // CTRL FSM
    STOP                   = 1'b0,
    START                  = 1'b1,
    
    // STATUS FSM
    IDLE                   = 2'd0,
    RUN                    = 2'd1,
    DONE                   = 2'd2;


//------------------------ Local signal -------------------
    reg  [1:0]                    wState = WRRESET;
    reg  [1:0]                    wNextState;
    reg  [ADDR_WIDTH-1:0]         wAddr;
    wire                          aw_hs;
    wire                          w_hs;
    reg  [1:0]                    rState = RDRESET;
    reg  [1:0]                    rNextState;
    reg  [DATA_WIDTH-1:0]         rData;
    wire                          ar_hs;
    wire [ADDR_WIDTH-1:0]         rAddr;

    // registers
    reg [DATA_WIDTH-1:0]          registers [0:ADDR_WIDTH*2-1];
    
    reg [1:0]                     statNextState;

    
// register initialization
always @(posedge clk) begin
    if(!rst_n) begin
        registers[CTRL] <= 0;
        registers[STATUS] <= 0;
        registers[FILTER] <= 0;
    end
    else begin
        registers[STATUS][1:0] <= statNextState;
    end
end


// status FSM
always @(*) begin
    case (registers[STATUS][1:0])
        IDLE:
            if (registers[CTRL][0]==START) 
                statNextState = RUN;
            else
                statNextState = IDLE;
        RUN:
            if (tlast) 
                statNextState = DONE;
            else
                statNextState = RUN;
        DONE:
            if (registers[CTRL][0]==STOP) 
                statNextState = IDLE;
            else
                statNextState = DONE;
        default:
            statNextState = IDLE;
    endcase
end

assign run = (registers[STATUS][1:0] == RUN);
assign start = (!run && statNextState == RUN); 
 assign filter_weights = registers[FILTER][26:0];

//--------------------- Write FSM --------------------

// write state register
always @(posedge clk) begin
    if (!rst_n)
        wState <= WRRESET;
    else 
        wState <= wNextState;
end

// write next state
always @(*) begin
    case (wState)
        WRIDLE:
            if (s_axi_control_awvalid)
                wNextState = WRDATA;
            else
                wNextState = WRIDLE;
        WRDATA:
            if (s_axi_control_wvalid)
                wNextState = WRRESP;
            else
                wNextState = WRDATA;
        WRRESP:
            if (s_axi_control_bready)
                wNextState = WRIDLE;
            else
                wNextState = WRRESP;
        default:
            wNextState = WRIDLE;
    endcase
end

// write addr
always @(posedge clk) begin
    if (aw_hs)
        wAddr <= s_axi_control_awaddr;
end

// write data
always @(posedge clk) begin 
    if(w_hs) 
        registers[wAddr] = s_axi_control_wdata;
end

// output logic
assign s_axi_control_awready = (wState == WRIDLE);
assign s_axi_control_wready  = (wState == WRDATA);
assign s_axi_control_bresp   = 2'b00;  // OKAY
assign s_axi_control_bvalid  = (wState == WRRESP);
assign aw_hs = s_axi_control_awvalid & s_axi_control_awready;
assign w_hs = s_axi_control_wvalid & s_axi_control_wready;




//---------------------- read FSM ----------------------

// read state register
always @(posedge clk) begin
    if (!rst_n)
        rState <= RDRESET;
    else 
        rState <= rNextState;
end

// read next state
always @(*) begin
    case (rState)
        RDIDLE:
            if (s_axi_control_arvalid)
                rNextState = RDDATA;
            else
                rNextState = RDIDLE;
        RDDATA:
            if (s_axi_control_rready & s_axi_control_rvalid) 
                rNextState = RDIDLE;
            else
                rNextState = RDDATA;
        default:
            rNextState = RDIDLE;
    endcase
end

// rdata
always @(posedge clk) begin
    if (ar_hs) begin
        case (rAddr)
            CTRL: begin
                rData <= registers[CTRL];
            end
            STATUS: begin
                rData <= registers[STATUS];
            end
            FILTER: begin
                rData <= registers[FILTER];
            end
            default: begin
                rData <= 32'b0;
            end
        endcase
    end
end

// output logic
assign s_axi_control_arready = (rState == RDIDLE);
assign s_axi_control_rdata   = rData;
assign s_axi_control_rresp   = 2'b00;  // OKAY
assign s_axi_control_rvalid  = (rState == RDDATA);
assign ar_hs   = s_axi_control_arvalid & s_axi_control_arready;
assign rAddr   = s_axi_control_araddr;

endmodule
