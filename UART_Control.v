module UART_Control
(
	input CLK,
	input RST,
	
	input GPS_OEM_PPS,
	
	input [2:1] EX_COM3_RD,
//	output [2:1] EX_COM3_TD,
	output EX_COM3_MODE,
	output EX_COM3_HF,
	
	output [15:0] Out_ms,
	output ISR_ms
//	output [7:0] IMU_Data
);

	parameter OSC_FREQ = 25'd20_000_000;

/******************设置RS232模式***********************/
	reg rEX_COM3_MODE;
	reg rEX_COM3_HF;
	always@( posedge CLK )
	begin
		if( !RST )
		begin
			rEX_COM3_MODE <= 1'b0;
			rEX_COM3_HF <= 1'b0;
		end 
		else
		begin
			rEX_COM3_MODE <= 1'b0;
			rEX_COM3_HF <= 1'b0;
		end
	end 
	
	assign EX_COM3_MODE = rEX_COM3_MODE;
	assign EX_COM3_HF = rEX_COM3_HF;

/******************检测PPS同步信号***********************/
	reg PPS1,PPS2;
	always@( posedge CLK )
	begin
		if( !RST )
		begin
			PPS1 <= 1'b0;
			PPS2 <= 1'b0;
		end 
		else
		begin
			PPS1 <= GPS_OEM_PPS;
			PPS2 <= PPS1;
		end 
	end 
	
//	wire PPS_EN = ( !PPS2 ) && PPS1;
	wire PPS_Clear = ( !PPS1 ) && PPS2;
	
/*****************1ms计数器************************/	
	parameter PPS_T1ms = OSC_FREQ / 1000;
	
	reg [14:0] PPS_CNT;
	always@( posedge CLK )
	begin
		if( !RST )
			PPS_CNT <= 15'd0;
		else
		begin
			if( ( PPS_CNT == PPS_T1ms - 1'b1 ) || PPS_Clear )
				PPS_CNT <= 15'd0;
			else 
				PPS_CNT <= PPS_CNT + 1'b1;
		end		
	end 
	
	wire PPS_CNT_EN = PPS_CNT == ( PPS_T1ms - 1'b1 );
	
/******************检测IMU 0x55aa信号***********************/	
	wire [7:0] IMU_Data;
	wire IMU_Vlid;
	reg [7:0] IMU_Data1;
	reg IMU_EN;
	always@( posedge CLK )
	begin
		if( !RST )
		begin
			IMU_Data1 <= 8'd0;
			IMU_EN <= 1'b0;
		end 
		else if( IMU_Vlid )
		begin
			IMU_Data1 <= IMU_Data;
			if( ( IMU_Data == 8'haa ) && ( IMU_Data1 == 8'h55 ) )
			IMU_EN <= 1'b1;
		end 
		else
			IMU_EN <= 1'b0;
	end 
	
//	wire IMU_EN = ( IMU_Data1 == 8'haa ) && ( IMU_Data2 == 8'h55 );
	
/******************同步毫秒计数器***********************/	
	reg [15:0] PPS_CNT_ms;
	always@( posedge CLK )
	begin
		if( !RST )
			PPS_CNT_ms <= 16'd0;
		else
		begin
			if( PPS_CNT_ms == 16'd999 || PPS_Clear )
				PPS_CNT_ms <= 16'd0;
			else if( PPS_CNT_EN )
				PPS_CNT_ms <= PPS_CNT_ms + 1'b1;
		end		
	end 
	
/***************输出IMU到时的毫秒时间并给出1毫秒中断信号**************************/	
	reg [15:0] rOut_ms;
	reg rISR_ms;
	reg [14:0] ISR_CNT;
	reg ISR_CNT_EN;
	always@( posedge CLK )
	begin
		if( !RST )
		begin 
			rISR_ms <= 1'b0;
			rOut_ms <= 16'd0;
			ISR_CNT <= 15'd0;
			ISR_CNT_EN <= 1'b0;
		end 
		else if( IMU_EN )
		begin 
			rISR_ms <= 1'b1;
			ISR_CNT_EN <= 1'b1;
			rOut_ms <= PPS_CNT_ms;
		end 
		else if( ISR_CNT_EN )
		begin
			if( ISR_CNT == PPS_T1ms -1'b1 )
			begin 
				rISR_ms <= 1'b0;
				ISR_CNT <= 15'd0;
				ISR_CNT_EN <= 1'b0;
			end 
			else 
				ISR_CNT <= ISR_CNT + 1'b1;
		end 
	end 
	
	assign Out_ms = rOut_ms;
	assign ISR_ms = rISR_ms;	
	
/****************串口接收模块*************************/		
	uart_Parity IMU
	(
		.clk( CLK ),
		.rst_n( RST ),
		
		/*.ld_tx_data( 1 ),
		.tx_data( 8'h88 ),
		.tx_enable( 1 ),
		.tx_out( EX_COM3_TD1 ),
		.tx_empty( EX_COM3_empty ),*/
		
		.rx_data_vlid( IMU_Vlid ),
		.rx_data( IMU_Data ),
		.rx_enable( 1 ),
		.rx_in( EX_COM3_RD[2] )
	);
	
endmodule
