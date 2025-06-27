`timescale 1 ns / 1 ps


module imageFilterTop #(
    parameter AXI_CONTROL_DATA_WIDTH = 32,
              AXI_CONTROL_ADDR_WIDTH = 2,
              AXIS_DATA_WIDTH        = 8,
              IMAGE_WIDTH_SIZE       = 512,
              IMAGE_WIDTH_LOG2_SIZE  = 9,
              FIFO_DEPTH             = 4,
              FIFO_LOG2_DEPTH        = 2
)(    
    input wire                           clk,
    input wire                           rst_n,

    // axi4-stream slave interface
    input wire                           s_axis_tvalid, 
    input wire [AXIS_DATA_WIDTH-1:0]     s_axis_tdata, 
    output wire                          s_axis_tready, 
    input wire                           s_axis_tuser, 
    input wire                           s_axis_tlast,

    // axi4-stream master interface
    output wire                          m_axis_tvalid, 
    output wire [AXIS_DATA_WIDTH-1:0]    m_axis_tdata, 
    input wire                           m_axis_tready, 
    output wire                          m_axis_tuser,
    output wire                          m_axis_tlast,

    // axi4-lite slave interface
    input  wire [AXI_CONTROL_ADDR_WIDTH-1:0]  s_axi_control_awaddr,
    input  wire                               s_axi_control_awvalid,
    output wire                               s_axi_control_awready,
    input  wire [AXI_CONTROL_DATA_WIDTH-1:0]  s_axi_control_wdata,
    input  wire                               s_axi_control_wvalid,
    output wire                               s_axi_control_wready,
    output wire [1:0]                         s_axi_control_bresp,
    output wire                               s_axi_control_bvalid,
    input  wire                               s_axi_control_bready,
    input  wire [AXI_CONTROL_ADDR_WIDTH-1:0]  s_axi_control_araddr,
    input  wire                               s_axi_control_arvalid,
    output wire                               s_axi_control_arready,
    output wire [AXI_CONTROL_DATA_WIDTH-1:0]  s_axi_control_rdata,
    output wire [1:0]                         s_axi_control_rresp,
    output wire                               s_axi_control_rvalid,
    input  wire                               s_axi_control_rready

);

//---------------------- Local signal -------------------
    wire [AXIS_DATA_WIDTH*9-1:0]  pixel_3x3_data;
    wire                          pixel_3x3_data_valid;
    wire                          pixel_3x3_data_ready;
    wire                          pixel_3x3_data_EOL;
    wire                          pixel_3x3_data_tlast;

    wire [AXIS_DATA_WIDTH-1:0]    convolved_data;
    wire                          convolved_data_valid;
    wire                          convolved_data_ready;
    wire                          convolved_data_EOL;
    wire                          convolved_data_tlast;

    wire [26:0]                   filter_weights;
    wire                          start;
    wire                          run;


    
imageControl #(
    .DATA_WIDTH(AXIS_DATA_WIDTH),
    .IMAGE_WIDTH_SIZE(IMAGE_WIDTH_SIZE),
    .IMAGE_WIDTH_LOG2_SIZE(IMAGE_WIDTH_LOG2_SIZE) 
) IC(
    .clk(clk),
    .rst_n(rst_n),
    .s_data(s_axis_tdata),
    .s_valid(s_axis_tvalid),
    .s_ready(s_axis_tready),
    .m_data(pixel_3x3_data),
    .m_valid(pixel_3x3_data_valid),
    .m_ready(pixel_3x3_data_ready),
    .i_EOL(s_axis_tuser),
    .o_EOL(pixel_3x3_data_EOL),
    .o_tlast(pixel_3x3_data_tlast),
    .run(run)
  );    
  
 conv #(.DATA_WIDTH(AXIS_DATA_WIDTH)
) CONV( 
     .clk(clk),
     .rst_n(rst_n),
     .s_data(pixel_3x3_data),
     .s_valid(pixel_3x3_data_valid),
     .s_ready(pixel_3x3_data_ready),
     .m_data(convolved_data),
     .m_valid(convolved_data_valid),
     .m_ready(convolved_data_ready),
     .i_EOL(pixel_3x3_data_EOL),
     .o_EOL(convolved_data_EOL),
     .i_tlast(pixel_3x3_data_tlast),
     .o_tlast(convolved_data_tlast),
     .start(start),
     .filter_weights(filter_weights)
 ); 
 
 outputFIFO #(
    .DATA_WIDTH(AXIS_DATA_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH),
    .FIFO_LOG2_DEPTH(FIFO_LOG2_DEPTH) 
) OF(
     .clk(clk),
     .rst_n(rst_n),
     .s_data(convolved_data),
     .s_valid(convolved_data_valid),
     .s_ready(convolved_data_ready),
     .m_data(m_axis_tdata),
     .m_valid(m_axis_tvalid),
     .m_ready(m_axis_tready),
     .i_EOL(convolved_data_EOL),
     .o_EOL(m_axis_tuser),
     .i_tlast(convolved_data_tlast),
     .o_tlast(m_axis_tlast)
 );
  
controller_axi_lite #(
    .DATA_WIDTH(AXI_CONTROL_DATA_WIDTH),
    .ADDR_WIDTH(AXI_CONTROL_ADDR_WIDTH)
) CONTROLLER (
    .clk(clk),
    .rst_n(rst_n),
    .s_axi_control_awaddr(s_axi_control_awaddr),
    .s_axi_control_awvalid(s_axi_control_awvalid),
    .s_axi_control_awready(s_axi_control_awready),
    .s_axi_control_wdata(s_axi_control_wdata),
    .s_axi_control_wvalid(s_axi_control_wvalid),
    .s_axi_control_wready(s_axi_control_wready),
    .s_axi_control_bresp(s_axi_control_bresp),
    .s_axi_control_bvalid(s_axi_control_bvalid),
    .s_axi_control_bready(s_axi_control_bready),
    .s_axi_control_araddr(s_axi_control_araddr),
    .s_axi_control_arvalid(s_axi_control_arvalid),
    .s_axi_control_arready(s_axi_control_arready),
    .s_axi_control_rdata(s_axi_control_rdata),
    .s_axi_control_rresp(s_axi_control_rresp),
    .s_axi_control_rvalid(s_axi_control_rvalid),
    .s_axi_control_rready(s_axi_control_rready),
    .tlast(s_axis_tlast), 
    .start(start),
    .run(run), 
    .filter_weights(filter_weights)
); 

    
endmodule
