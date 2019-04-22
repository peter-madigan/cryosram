# Overview
`cryoCMOS/py/` provides a platform for performing basic tests of the cryoSRAM component of the cryoCMOS chip

# Installation
To setup, insure that you have some basic requirements:
```
sudo apt-get install python-tk
```
Then install this software
```
pip install -e .
```

# Quick operation
To have a testing environment automatically set up, run:
```
./test_suite.py
```
which will enter into an interactive session with a `cryoCMOS.CryoSRAM` object (`c`).
To verify connectivity with the cryoSRAM FPGA, run
```
faults = c.serial_test()
```
There should be no faults regardless of the cryoSRAM chip status. In the event that connectivity could not be established (either many faults or an error on startup), run
```
list_ports()
```
This will print a list of available ports for serial communication. Exit from the interactive session and try again with
```
./test_suite.py <serial port to try>
```
After successfully connecting to the FPGA, you may now issue read/write commands via the `c` object.
Example:
```
c.set_addr(255) # set FPGA read/write address to 255
c.read_addr() # read the current FPGA address (should return 255)
c.write_value(127) # write 127 to the address 255
c.read_value() # read the value at the address 255 (should return 127)
c.set_clk(clk_factor=5) # change SRAM driving frequency = 100MHz/(4*clk_factor)
c.read_clk() # read the set clk_factor (should be 5)
```
There are some standard cryoSRAM tests available:
 - `c.mats_test()`: perform a standard MATS test
 - `c.pattern_test(test_values)`: write the pattern described by test_values and verify
 - `c.single_bit_test(test_values)`: at each memory address write `test_values`, verifying each
 - `c.rand_test(n_static, n_dynamic)`: perform `n_static` complete memory writes with verification, then perform n_dynamic random read/write operations (verifying read operations)

To run all the tests using default values across standard clk frequencies, use:
```
results = run_test_suite(c)
```
After this completes, you can automatically generate and save a variety of plots via
```
generate_plots(c, results)
```

# `plotting`
The helper library `plotting` contains a handful of helpful functions for plotting bit errors. To view a map of the bit error locations use:
```
plot_bit_error_map(fault_list)
```

# `CryoSRAM`
The `CryoSRAM class provides access to:
 - Transmission formatting for the fpga
 - A `memory` object that keeps track of the expected cryoSRAM state
 - Standard tests
To create a new `CryoSRAM` object:
```
c = CryoSRAM(reg_val_map=None, io=None, log=None)
```
The `reg_val_map` should be a map from addr : value, if this is known. Otherwise, all addresses are initialized to `None`. The `io` should be communication object with `read(<n bytes>)` and `write(<bytes>)` methods (the interface has be designed to use `Serial` objects). And finally the `log` should be an object with standard python `logging` message calls (`debug()`, `info()`, etc.).

# `CryoLogger`
This is a helper class for providing nicely formatted log messages to a `CryoSRAM` object, as well as storing read/write messages in an easy-to-parse method. After creating a `CryoLogger` instance:
```
log = CryoLogger(directory=<logging directory>)
```
You can track read/writes of an `io` object with
```
io.read = self.log.capture_read(io.read)
io.write = self.log.capture_write(io.write)
```
So far, this hasn't been implemented in a nice format (it overwrites the previously generated method), but for the quick tests that we are planning on doing, it should suffice.

# FPGA comms
The communication between the computer and FPGA relies on a standard 8-bit, 1MBaud serial UART protocol. Each complete message consists of 2-bytes. They are broken down as follows:
byte0[7:4] = message type
byte0[3:0] = message[11:8]
btye1[11:0] = message[7:0]

The message types the FPGA responds to are:
SET_ADDR : 0001
WRITE_VAL : 0010
READ_ADDR : 0011
READ_VAL : 0100
SET_CLK : 0101
READ_CLK : 0110
