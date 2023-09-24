library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.ram_configuration_pkg.all;

package ram_port_pkg is

    -- move these to separate package
    subtype ramtype is std_logic_vector(ram_bit_width-1 downto 0);
    subtype ram_address is natural range 0 to ram_depth-1;

    type ram_read_in_record is record
        address : ram_address;
        read_is_requested : std_logic;
    end record;

    type ram_read_out_record is record
        data          : std_logic_vector(ramtype'range);
        data_is_ready : std_logic;
    end record;

    type ram_write_in_record is record
        address         : ram_address;
        data            : std_logic_vector(ramtype'range);
        write_requested : std_logic;
    end record;

    procedure init_ram (
        signal self_read_in : out ram_read_in_record);

    procedure init_ram (
        signal self_write_in : out ram_write_in_record);

    procedure init_ram (
        signal self_read_in : out ram_read_in_record;
        signal self_write_in : out ram_write_in_record);

    procedure request_data_from_ram (
        signal self_read_in : out ram_read_in_record;
        address : in natural);

    function ram_read_is_ready ( self_read_out : ram_read_out_record)
        return boolean;

    function get_ram_data ( self_read_out : ram_read_out_record)
        return std_logic_vector;
------------------------------------------------------------------------
------------------------------------------------------------------------
    procedure write_data_to_ram (
        signal self_write_in : out ram_write_in_record;
        address : in natural;
        data : in std_logic_vector);
        -- clka  : in std_logic;                                       -- Clock
        -- ena   : in std_logic;                                       -- Port A RAM Enable
        -- wea   : in std_logic;                                       -- Port A Write enable
        -- dina  : in std_logic_vector(RAM_WIDTH-1 downto 0);          -- Port A RAM input data
        -- rsta  : in std_logic;                                       -- Port A Output reset
        -- regcea: in std_logic;                                       -- Port A Output register enable
        -- douta : out std_logic_vector(RAM_WIDTH-1 downto 0);         -- Port A RAM output data

        -- addrb : in std_logic_vector((logb2(RAM_DEPTH)-1) downto 0);     -- Port B Address
        -- dinb  : in std_logic_vector(RAM_WIDTH-1 downto 0);		-- Port B RAM input data
        -- web   : in std_logic;                       			-- Port B Write enable
        -- enb   : in std_logic;                       			-- Port B RAM Enable
        -- rstb  : in std_logic;                       			-- Port B Output reset 
        -- regceb: in std_logic;                       			-- Port B Output register enable
        -- doutb : out std_logic_vector(RAM_WIDTH-1 downto 0)   		-- Port B RAM output data

end package ram_port_pkg;

package body ram_port_pkg is

------------------------------------------------------------------------
    procedure init_ram
    (
        signal self_read_in : out ram_read_in_record
    ) is
    begin
        self_read_in.read_is_requested <= '0';
    end init_ram;

    procedure init_ram
    (
        signal self_write_in : out ram_write_in_record
    ) is
    begin
        self_write_in.write_requested  <= '0';
    end init_ram;

    procedure init_ram
    (
        signal self_read_in : out ram_read_in_record;
        signal self_write_in : out ram_write_in_record
    ) is
    begin
        init_ram(self_read_in);
        init_ram(self_write_in);
    end init_ram;
------------------------------
------------------------------
    procedure request_data_from_ram
    (
        signal self_read_in : out ram_read_in_record;
        address : in natural
    ) is
    begin
        self_read_in.address <= address;
        self_read_in.read_is_requested <= '1';
    end request_data_from_ram;
------------------------------
    function ram_read_is_ready
    (
        self_read_out : ram_read_out_record
    )
    return boolean
    is
    begin
        return self_read_out.data_is_ready = '1';
        
    end ram_read_is_ready;
------------------------------
    function get_ram_data
    (
        self_read_out : ram_read_out_record
    )
    return std_logic_vector 
    is
    begin
        return self_read_out.data;
    end get_ram_data;
------------------------------------------------------------------------
------------------------------------------------------------------------
    procedure write_data_to_ram
    (
        signal self_write_in : out ram_write_in_record;
        address : in natural;
        data : in std_logic_vector
    ) is
    begin
        self_write_in.address <= address;
        self_write_in.data <= data;
        self_write_in.write_requested <= '1';
    end write_data_to_ram;
------------------------------------------------------------------------


end package body ram_port_pkg;
------------------------------------------------------------------------
------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.ram_read_pkg.all;
    use work.ram_write_pkg.all;
    use work.ram_port_pkg.all;

entity dual_port_ram is
    generic(init_program : ram_array);
    port (
        clock : in std_logic;
        ram_read_a_in  : in ram_read_in_record;
        ram_read_a_out : out ram_read_out_record;
        ram_write_a_in : in ram_write_in_record;
        --------------------
        ram_read_b_in  : in ram_read_in_record;
        ram_read_b_out : out ram_read_out_record;
        ram_write_b_in : in ram_write_in_record
    );
end entity dual_port_ram;

architecture rtl of dual_port_ram is

------------------------------------------------------------------------
    alias ram_data_array is ram_array;

------------------------------------------------------------------------
    type dp_ram is protected

    ------------------------------
        procedure write_ram(
            address : in natural;
            data :    in std_logic_vector);
    ------------------------------
        impure function read_data(address : natural)
            return std_logic_vector;
    ------------------------------

    end protected dp_ram;

------------------------------------------------------------------------
    type dp_ram is protected body
    ------------------------------
        impure function init_ram
        (
            ram_init_values : ram_array
        )
        return ram_data_array
        is
            variable retval : ram_data_array := (others => (others => '0'));
        begin

            for i in ram_init_values'range loop
                retval(i) := ram_init_values(i);
            end loop;

            return retval;
            
        end init_ram;

        variable ram_contents : ram_data_array := init_ram(init_program);

    ------------------------------
        impure function read_data
        (
            address : natural
        )
        return std_logic_vector 
        is
        begin
            return ram_contents(address);
        end read_data;

    ------------------------------
        procedure write_ram
        (
            address : in natural;
            data    : in std_logic_vector
        ) is
        begin
            ram_contents(address) := data;
        end write_ram;


    ------------------------------
    end protected body;
------------------------------------------------------------------------

    shared variable dual_port_ram_array : dp_ram;

begin

    create_ram_a_port : process(clock)
    begin
        if(rising_edge(clock)) then
            if (ram_read_a_in.read_is_requested = '1') or (ram_write_a_in.write_requested = '1') then
                ram_read_a_out.data <= dual_port_ram_array.read_data(ram_read_a_in.address);
                if ram_write_a_in.write_requested = '1' then
                    dual_port_ram_array.write_ram(ram_write_a_in.address, ram_write_a_in.data);
                end if;
            end if;
        end if;
    end process;

    create_ram_b_port : process(clock)
    begin
        if(rising_edge(clock)) then
            if (ram_read_b_in.read_is_requested = '1') or (ram_write_b_in.write_requested = '1') then
                ram_read_b_out.data <= dual_port_ram_array.read_data(ram_read_b_in.address);
                if ram_write_b_in.write_requested = '1' then
                    dual_port_ram_array.write_ram(ram_write_b_in.address, ram_write_b_in.data);
                end if;
            end if;
        end if;
    end process;

end rtl;
