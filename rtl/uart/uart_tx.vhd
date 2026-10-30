--------------------------------------------------------------------------------
-- Developper: Michael Antabian
-- Design Name:
-- Module Name: uart_tx.vhd
-- Target Devices:
-- Description: UART Transmitter module
--
-- Dependencies:
-- Revision:    1.0 - File Created
--------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity uart_tx is
  generic (
    BAUD_RATE  : positive := 115_200;
    CLK_FREQ_HZ : positive := 100_000_000
  );
  port (
    clk   : in    std_logic;
    reset : in    std_logic;

    -- ctrl signals
    tx_valid : in    std_logic;
    tx_ready : out   std_logic;

    -- parallel data-in | serial data-out
    tx_data   : in    std_logic_vector(7 downto 0);
    tx_serial : out   std_logic
  );
end entity uart_tx;

architecture rtl of uart_tx is

    type state_t is (IDLE, START, DATA, STOP);
    signal curr_state, next_state : state_t := IDLE;

    signal fsm_tx_data : std_logic_vector(7 downto 0);
    signal tx_output   : std_logic := '1';

    constant DATA_WIDTH : positive := 8;
    constant CLKS_PER_BIT : positive := CLK_FREQ_HZ / BAUD_RATE;

    signal baud_cnt : integer range 0 to CLKS_PER_BIT - 1 := 0;
    signal bit_idx  : integer range 0 to 7 := 0;

    signal counter_done : std_logic;

begin

    baud_counter : process (clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') or (curr_state = IDLE) then
                baud_cnt <= 0;
                bit_idx <= 0;
            else
                if counter_done = '1' then
                    baud_cnt <= 0;

                    if curr_state = DATA then
                        bit_idx <= (bit_idx + 1) mod (DATA_WIDTH);
                    end if;
                else
                    baud_cnt <= baud_cnt + 1;
                end if;
            end if;
        end if;
    end process baud_counter;

    -- counter done strobe that asserts high on the final clk cycle of each bit
    counter_done <= '1' when (baud_cnt = CLKS_PER_BIT-1) else '0';

    -- Sequential next state process
    fsm_seq_state : process(clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                curr_state <= IDLE;
            else
                curr_state <= next_state;

                if (tx_ready = '1') and (tx_valid = '1') then
                    fsm_tx_data <= tx_data;
                end if;
            end if;
        end if;
    end process fsm_seq_state;

    -- Combinational process for transitioning state
    fsm_comb_state : process (all) 
    begin
        -- default fallback state
        next_state <= curr_state;
        tx_ready <= '0';
        
        case (curr_state) is
            when IDLE =>
                tx_ready <= '1';
                if (tx_valid = '1') then
                    next_state <= START;
                end if;
            when START =>
                if (counter_done = '1')then
                    next_state <= DATA;
                end if;    
            when DATA =>
                if bit_idx < 7 then 
                    next_state <= DATA;
                else
                    if (counter_done = '1')then
                        next_state <= STOP;
                    end if;  
                end if;
            when STOP =>
                if (counter_done = '1')then
                    next_state <= IDLE;
                end if;     
            when others =>
                next_state <= IDLE;
        end case;
    end process fsm_comb_state;

    tx_serial <= tx_output;

    fsm_output : process (clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                tx_output <= '1';
            else
                case (curr_state) is 
                    when IDLE =>
                        tx_output <= '1';
                    when START =>
                        tx_output <= '0'; 
                    when DATA =>
                        tx_output <= fsm_tx_data(bit_idx);
                    when STOP =>
                        tx_output <= '1'; 
                    when others =>
                        tx_output <= '1'; 
                end case;
            end if;
        end if;
    end process fsm_output;

end architecture rtl;

