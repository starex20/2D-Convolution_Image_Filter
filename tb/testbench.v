`timescale 1 ns / 1 ps

`define HEADER 1080
`define IMAGE_WIDTH 512
`define IMAGE_HEIGHT 512

module tb();

parameter AXI_CONTROL_DATA_WIDTH = 32;
parameter AXI_CONTROL_ADDR_WIDTH = 4;
parameter AXIS_DATA_WIDTH = 8;
parameter IMAGE_WIDTH_SIZE = 512; // 512x512 image
parameter IMAGE_WIDTH_LOG2_SIZE = 9;
parameter FIFO_DEPTH = 4;
parameter FIFO_LOG2_DEPTH = 2;

// Control Register Map
parameter CTRL   = 4'h00,
          STATUS = 4'h04,
          FILTER = 4'h08;

// 3x3 filter weights (gaussian filter)
parameter W1 = 3'd1, W2 = 3'd2, W3 = 3'd1,
          W4 = 3'd2, W5 = 3'd4, W6 = 3'd2,
          W7 = 3'd1, W8 = 3'd2, W9 = 3'd1;

// System Signals
reg clk = 0;
reg rst_n = 1;

always begin
	#5 clk = ~clk;
end

initial begin
    #5; rst_n = 0;
    #20; rst_n = 1;
end

//axi4-stream ports
reg                               m_axis_tvalid;
wire                              m_axis_tready;
reg  [AXIS_DATA_WIDTH-1:0]        m_axis_tdata;
reg                               m_axis_tuser; // EOL(End Of Line) 
reg                               m_axis_tlast; // last of frame 

wire                              s_axis_tvalid;
reg                               s_axis_tready;
wire [AXIS_DATA_WIDTH-1:0]        s_axis_tdata;
wire                              s_axis_tuser; // EOL 
wire                              s_axis_tlast; // last of frame


// axi4-lite ports
reg                               m_axi_control_awvalid;
wire                              m_axi_control_awready;
reg  [AXI_CONTROL_ADDR_WIDTH-1:0] m_axi_control_awaddr;
reg                               m_axi_control_wvalid;
wire                              m_axi_control_wready;
reg  [AXI_CONTROL_DATA_WIDTH-1:0] m_axi_control_wdata;
reg                               m_axi_control_arvalid;
wire                              m_axi_control_arready;
reg [AXI_CONTROL_ADDR_WIDTH-1:0]  m_axi_control_araddr;
wire                              m_axi_control_rvalid;
reg                               m_axi_control_rready;
wire [AXI_CONTROL_DATA_WIDTH-1:0] m_axi_control_rdata;
wire [1:0]                        m_axi_control_rresp;
wire                              m_axi_control_bvalid;
reg                               m_axi_control_bready;
wire [1:0]                        m_axi_control_bresp;

integer file_in, file_out, i;
integer counter_width = 0, counter_height = 0;
integer img_writing = 0;


//DUT
imageFilterTop #(
    .AXI_CONTROL_DATA_WIDTH(AXI_CONTROL_DATA_WIDTH),
    .AXI_CONTROL_ADDR_WIDTH(AXI_CONTROL_ADDR_WIDTH),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .IMAGE_WIDTH_SIZE(IMAGE_WIDTH_SIZE),
    .IMAGE_WIDTH_LOG2_SIZE(IMAGE_WIDTH_LOG2_SIZE),
    .FIFO_DEPTH(FIFO_DEPTH),
    .FIFO_LOG2_DEPTH(FIFO_LOG2_DEPTH)  
) DUT (
    .clk(clk),
    .rst_n(rst_n),

    .s_axis_tvalid(m_axis_tvalid),
    .s_axis_tdata(m_axis_tdata),
    .s_axis_tready(m_axis_tready),
    .s_axis_tuser(m_axis_tuser),
    .s_axis_tlast(m_axis_tlast),

    .m_axis_tvalid(s_axis_tvalid),
    .m_axis_tdata(s_axis_tdata),
    .m_axis_tready(s_axis_tready),
    .m_axis_tuser(s_axis_tuser),
    .m_axis_tlast(s_axis_tlast),

    .s_axi_control_awaddr(m_axi_control_awaddr),
    .s_axi_control_awvalid(m_axi_control_awvalid),
    .s_axi_control_awready(m_axi_control_awready),

    .s_axi_control_wdata(m_axi_control_wdata),
    .s_axi_control_wvalid(m_axi_control_wvalid),
    .s_axi_control_wready(m_axi_control_wready),

    .s_axi_control_bresp(m_axi_control_bresp),
    .s_axi_control_bvalid(m_axi_control_bvalid),
    .s_axi_control_bready(m_axi_control_bready),

    .s_axi_control_araddr(m_axi_control_araddr),
    .s_axi_control_arvalid(m_axi_control_arvalid),
    .s_axi_control_arready(m_axi_control_arready),

    .s_axi_control_rdata(m_axi_control_rdata),
    .s_axi_control_rresp(m_axi_control_rresp),
    .s_axi_control_rvalid(m_axi_control_rvalid),
    .s_axi_control_rready(m_axi_control_rready)
  
);



// device drivers
task read_register(input [AXI_CONTROL_ADDR_WIDTH-1:0] addr, output [AXI_CONTROL_DATA_WIDTH-1:0] data_out);
begin
    // 1. Read Address
    m_axi_control_araddr  = addr;
    m_axi_control_arvalid = 1;
    wait (m_axi_control_arready == 1);
    #20;
    m_axi_control_arvalid = 0;

    // 2. wait rvalid
    m_axi_control_rready = 1;
    wait (m_axi_control_rvalid == 1);

    // 3. read data
    data_out = m_axi_control_rdata;
    #20;
    m_axi_control_rready = 0;
end
endtask

task write_register(input [AXI_CONTROL_ADDR_WIDTH-1:0] addr, input [AXI_CONTROL_DATA_WIDTH-1:0] data);
begin
    // 1. Write Address
    m_axi_control_awaddr = addr;
    m_axi_control_awvalid = 1;
    wait (m_axi_control_awready); 
    #20;
    m_axi_control_awvalid = 0;

    // 2. Write Data
    m_axi_control_wdata = data;
    m_axi_control_wvalid = 1;
    wait (m_axi_control_wready);  
    #20;
    m_axi_control_wvalid = 0;

    // 3. Write Response
    m_axi_control_bready = 1;
    wait (m_axi_control_bvalid);   
    #20;
    m_axi_control_bready = 0;
end
endtask

// -------------------- main function ---------------------
reg [AXI_CONTROL_DATA_WIDTH-1:0] rddata;
reg [AXI_CONTROL_DATA_WIDTH-1:0] filter;
reg [AXIS_DATA_WIDTH-1:0] imgData;

initial begin
    
    #30; 
     // write header in advance
    file_in = $fopen("lena_gray.bmp","rb");
    file_out = $fopen("blurred_lena.bmp","wb");
    for (i=0; i<`HEADER; i=i+1) begin // write header
        $fscanf(file_in,"%c",imgData);
        $fwrite(file_out,"%c",imgData);
    end
    #30;
    for (i=0; i<`IMAGE_WIDTH*2; i=i+1) begin // write dummy line
        $fwrite(file_out,"%c",0);
    end
    
    #30;
    
    // 1. check idle
    read_register(STATUS, rddata);
    while(rddata != 32'd0) begin // IDLE
        read_register(STATUS, rddata);
        //if(rddata == 32'd0) break;
    end

    #30;

    // 2. register setting (kernel value initialization)
    filter = {W9,W8,W7,W6,W5,W4,W3,W2,W1};
    write_register(FILTER,filter);
    
    #30;
    
    // 3. start ip
    write_register(CTRL, 32'b1); // start

    #30;
    m_axis_tvalid = 1'b1;
    s_axis_tready = 1'b1;


    // 4. wait done
    read_register(STATUS, rddata);
    while(rddata != 32'd2) begin // DONE
        read_register(STATUS, rddata);
    end
    write_register(CTRL, 32'b0); // stop
    

    wait(img_writing);
    repeat(10) @(posedge clk);
    $finish;

end



//////////////////////////////// Stimulus //////////////////////////////////////////

always @(posedge clk) // write pixel data
begin
    if((m_axis_tvalid==1)&&(m_axis_tready==1)) begin // input handshake

        $fscanf(file_in, "%c", m_axis_tdata); // 1 pixel read
       
        if(counter_width == IMAGE_WIDTH_SIZE-1) begin
            counter_width = 0;

            if(counter_height == IMAGE_WIDTH_SIZE-1) begin
                counter_height = 0;
                m_axis_tlast = 1'b1;
            end
            else begin
                counter_height = counter_height + 1;
                m_axis_tlast = 1'b0;
            end
            m_axis_tuser = 1'b1; // end of line         
        end
        else begin
            counter_width = counter_width + 1;
            m_axis_tlast = 1'b0;
            m_axis_tuser = 1'b0;
        end
  
    end
    else begin
         m_axis_tlast = 1'b0;
         m_axis_tuser = 1'b0;
    end
end



//////////////////////////////// Response //////////////////////////////////////////

initial begin // read convolved data
    
   while(img_writing == 0) 
   begin
        @(posedge clk)
        #1;
       if((s_axis_tvalid==1)&&(s_axis_tready==1)) begin // output handshake 

            $fwrite(file_out, "%c", s_axis_tdata); // 1 pixel write
            
            if(s_axis_tlast==1) begin // end of line
                $fclose(file_in);
                $fclose(file_out);
                img_writing = 1;    
            end
        end
    end
end



endmodule
