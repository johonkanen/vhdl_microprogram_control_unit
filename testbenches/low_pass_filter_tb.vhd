LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.microinstruction_pkg.all;
    use work.microcode_processor_pkg.all;
    use work.multi_port_ram_pkg.all;

entity low_pass_filter_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of low_pass_filter_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 5e3;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    ------------------------------------------------------------------------

    constant reg_offset : natural := work.ram_configuration_pkg.ram_array'high;
------------------------------------------------------------------------

    function low_pass_filter
    (
        gain_address   : natural;
        result_address : natural;
        input_address  : natural
    )
    return program_array
    is
        constant y    : natural := 1;
        constant g    : natural := 2;
        constant temp : natural := 3;
        constant u    : natural := 4;

        constant program : program_array := (
        write_instruction(load , y    , result_address) ,
        write_instruction(load , g    , gain_address)   ,
        write_instruction(load , u    , input_address)   ,
        write_instruction(nop) ,
        write_instruction(sub  , temp , u , y) ,
        write_instruction(nop) ,
        write_instruction(nop) ,
        write_instruction(mpy  , temp , temp , g) ,
        write_instruction(nop) ,
        write_instruction(nop) ,
        write_instruction(nop) ,
        write_instruction(nop) ,
        write_instruction(add  , y, temp , y),
        write_instruction(nop) ,
        write_instruction(nop) ,
        write_instruction(save, y, result_address)
    );
    begin
        return program;
        
    end low_pass_filter;

    constant program : program_array := (
        low_pass_filter(gain_address => 100 , result_address => 101 , input_address => 102) ,
        low_pass_filter(gain_address => 103 , result_address => 104 , input_address => 102) ,
        low_pass_filter(gain_address => 105 , result_address => 106 , input_address => 102) ,
        write_instruction(program_end) 
    );
------------------------------------------------------------------------

------------------------------------------------------------------------
    function init_ram_data_with_indices return ram_array
    is
        variable retval : ram_array;
    begin

        for i in retval'range loop
            retval(i) := std_logic_vector(to_unsigned(i,retval(0)'length));
        end loop;

        return retval;
        
    end init_ram_data_with_indices;

    function build_sw return ram_array
    is
        variable retval : ram_array := init_ram_data_with_indices;
    begin

        for i in program'range loop
            retval(i) := program(i);
        end loop;
        retval(100) := std_logic_vector(to_signed(integer(0.1*2**19),20));
        retval(101) := std_logic_vector(to_signed(integer(0.0*2**19),20));
        retval(102) := std_logic_vector(to_signed(integer(0.5*2**19),20));

        retval(103) := std_logic_vector(to_signed(integer(0.2*2**19),20));
        retval(104) := std_logic_vector(to_signed(integer(0.0*2**19),20));

        retval(105) := std_logic_vector(to_signed(integer(0.3*2**19),20));
        retval(106) := std_logic_vector(to_signed(integer(0.0*2**19),20));
            
        return retval;
        
    end build_sw;
------------------------------------------------------------------------

    constant ram_contents : ram_array := build_sw;

    signal self                     : processor_with_ram_record := init_processor(100, false);
    signal ram_read_instruction_in  : ram_read_in_record  := (0, '0');
    signal ram_read_instruction_out : ram_read_out_record ;
    signal ram_read_data_in         : ram_read_in_record  := (0, '0');
    signal ram_read_data_out        : ram_read_out_record ;
    signal ram_write_port           : ram_write_in_record ;
    signal ram_write_port2          : ram_write_in_record ;

    signal state_counter : natural := 0;

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------

    stimulus : process(simulator_clock)
    ------------------------------------------------------------------------
    ------------------------------------------------------------------------
        variable used_instruction : t_instruction;

        procedure request_program is
        begin
            self.program_counter <= 0;
            self.processor_enabled <= true;
        end request_program;


    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            --------------------
            init_ram(ram_read_instruction_in, ram_read_data_in, ram_write_port);
        --------------------------------------------------
        ------------------------------------------------------------------------
            --stage -1

            if self.processor_enabled then
                request_data_from_ram(ram_read_instruction_in, self.program_counter);

                if ram_read_is_ready(ram_read_instruction_out) then
                    used_instruction := get_ram_data(ram_read_instruction_out);
                end if;

                if decode(used_instruction) = program_end then
                    self.processor_enabled <= false;
                    used_instruction := write_instruction(nop);
                else
                    self.program_counter <= self.program_counter + 1;
                end if;
            else
                used_instruction := write_instruction(nop);
            end if;


            CASE decode(used_instruction) is
                WHEN load =>
                    request_data_from_ram(ram_read_data_in, get_sigle_argument(used_instruction));

                WHEN stall =>
                    self.stall_counter   <= get_long_argument(used_instruction);
                    self.program_counter <= self.program_counter - 3;
                    used_instruction := write_instruction(nop);

                WHEN write_pc =>
                    self.registers(0) <= std_logic_vector(to_unsigned(self.program_counter-3,self.registers(0)'length));
                WHEN others => -- do nothing
            end CASE;


            if self.stall_counter > 0 then
                self.stall_counter   <= self.stall_counter - 1;
                self.program_counter <= self.program_counter;
                used_instruction := write_instruction(nop);
            end if;

            self.instruction_pipeline <= used_instruction & self.instruction_pipeline(0 to self.instruction_pipeline'high-1);
        ------------------------------------------------------------------------
        ------------------------------------------------------------------------
            --stage 0
            used_instruction := self.instruction_pipeline(0);

            CASE decode(used_instruction) is
                WHEN add =>
                    self.add_a <= self.registers(get_arg1(used_instruction));
                    self.add_b <= self.registers(get_arg2(used_instruction));
                WHEN sub =>
                    self.add_a <=  self.registers(get_arg1(used_instruction));
                    self.add_b <= -self.registers(get_arg2(used_instruction));
                WHEN mpy =>
                    self.mpy_a <= self.registers(get_arg1(used_instruction));
                    self.mpy_b <= self.registers(get_arg2(used_instruction));

                WHEN jump =>
                    self.program_counter <= get_long_argument(self.instruction_pipeline(0));

                WHEN others => -- do nothing
            end CASE;

        ------------------------------------------------------------------------
            --stage 1
            used_instruction := self.instruction_pipeline(1);
            self.add_result <= self.add_a + self.add_b;
            self.mpy_a1     <= self.mpy_a;
            self.mpy_b1     <= self.mpy_b;


        ------------------------------------------------------------------------
            --stage 2
            used_instruction := self.instruction_pipeline(2);
            self.mpy_raw_result <= signed(self.mpy_a1) * signed(self.mpy_b1);

            CASE decode(used_instruction) is
                WHEN load =>
                    self.registers(get_dest(used_instruction)) <= get_ram_data(ram_read_data_out);
                WHEN add | sub =>
                    self.registers(get_dest(used_instruction)) <= self.add_result;

                WHEN others => -- do nothing
            end CASE;

        ------------------------------------------------------------------------
            --stage 3
            used_instruction := self.instruction_pipeline(3);
            self.mpy_result <= std_logic_vector(self.mpy_raw_result(38 downto 38-19));

            CASE decode(used_instruction) is
                WHEN save =>
                    write_data_to_ram(ram_write_port, get_sigle_argument(used_instruction), self.registers(get_dest(used_instruction)));

                WHEN others => -- do nothing
            end CASE;
        ------------------------------------------------------------------------
            --stage 4
            used_instruction := self.instruction_pipeline(4);
            CASE decode(used_instruction) is
                WHEN mpy =>
                    self.registers(get_dest(used_instruction)) <= self.mpy_result;
                WHEN others => -- do nothing
            end CASE;
        ------------------------------------------------------------------------
            --stage 5
            used_instruction := self.instruction_pipeline(5);
        ------------------------------------------------------------------------

        ------------------------------------------------------------------------
        ------------------------------------------------------------------------
            if simulation_counter mod 80 = 0 then
                request_program;
            end if;
        ------------------------------------------------------------------------
        -- test signals
        ------------------------------------------------------------------------

        end if; -- rising_edge
    end process stimulus;	

------------------------------------------------------------------------
    u_mpram : entity work.ram_read_x2_write_x1
    generic map(ram_contents)
    port map(
    simulator_clock          ,
    ram_read_instruction_in  ,
    ram_read_instruction_out ,
    ram_read_data_in         ,
    ram_read_data_out        ,
    ram_write_port);
------------------------------------------------------------------------
end vunit_simulation;
