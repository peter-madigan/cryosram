#!/usr/bin/python
import time
from datetime import datetime
import struct
import os
import sys
import logging
import gzip
from random import randint
from bitarray import bitarray

class CryoLogger :
    '''
    Helper class for logging msg and serial comms
    '''
    filename_fmt = '%Y_%m_%d_%H_%M_%S'
    msgtime_fmt = '%Y_%m_%d_%H_%M_%S_%f'
    log_level = logging.DEBUG

    def __init__(self, directory='.', max_buffer_len=10e3):
        self.directory = directory

        self.filename = time.strftime(CryoLogger.filename_fmt)
        self.log_filename = self.filename + '.log'
        self.dat_filename = self.filename + '.csv.gz'

        self.formatter = logging.Formatter(fmt='%(asctime)s %(levelname)s: %(message)s',
                                           datefmt='%d-%b-%y %H:%M:%S')
        self.stdout = logging.StreamHandler(stream=sys.stdout)
        self.stdout.setFormatter(self.formatter)
        self.stdout.setLevel(self.log_level)
        self.logfile = logging.FileHandler(filename=self.directory + '/' + self.log_filename)
        self.logfile.setFormatter(self.formatter)
        self.logfile.setLevel(self.log_level)
        self.logger = logging.getLogger('CryoLogger')
        self.logger.setLevel(self.log_level)
        self.logger.addHandler(self.stdout)
        self.logger.addHandler(self.logfile)

        self.dat_file = gzip.open(self.directory + '/' + self.dat_filename, 'wt')
        self.max_buffer_len = max_buffer_len
        self.write_buffer = []
        self.captured_read_method = None
        self.captured_write_method = None

        self.info('Logging to %s', self.directory)
        self.info('data: %s', self.dat_filename)
        self.info('log: %s', self.log_filename)

    def __del__(self):
        '''
        This is just to insure any remaining data is flushed to file
        '''
        self.close()

    def close(self):
        '''
        Closes file after flushing buffer
        '''
        if self.dat_file and not self.dat_file.closed:
            self.flush_buffer()
            self.dat_file.close()
        if self.logfile:
            self.logfile.close()

    def format_msg(self, msg):
        '''
        writes data msg to file
        msg should be a tuple of values that can be converted to strings
        '''
        write_string = ', '.join([str(word) for word in msg])
        write_string += '\n'
        return write_string

    def flush_buffer(self):
        '''
        writes full buffer to file, clearing buffer
        '''
        data = ''.join([self.format_msg(msg) for msg in self.write_buffer])
        self.dat_file.write(data)
        self.write_buffer = []

    def capture_read(self, method):
        '''
        create new read method that captures result of read
        '''
        self.captured_read_method = method
        def new_method(*args, **kwargs):
            return_value = method(*args, **kwargs)
            data = bitarray()
            data.frombytes(return_value)
            self.write_buffer += [(datetime.now().strftime(self.msgtime_fmt),
                                   'RX', data.to01())]
            if len(self.write_buffer) > self.max_buffer_len:
                self.flush_buffer()
            return return_value
        return new_method

    def release_read(self):
        '''
        return original read method
        '''
        if self.captured_read_method is not None:
            return_method = self.captured_read_method
            self.captured_read_method = None
            return return_method
        else:
            raise ValueError('No captured method to release')

    def capture_write(self, method):
        '''
        create new write method that captures first argument of write
        '''
        self.captured_write_method = method
        def new_method(*args, **kwargs):
            data = bitarray()
            data.frombytes(args[0])
            self.write_buffer += [(datetime.now().strftime(self.msgtime_fmt),
                                   'TX', data.to01())]
            if len(self.write_buffer) > self.max_buffer_len:
                self.flush_buffer()
            return method(*args, **kwargs)
        return new_method

    def release_write(self):
        '''
        return original write method
        '''
        if self.captured_write_method is not None:
            return_method = self.captured_write_method
            self.captured_write_method = None
            return return_method
        else:
            raise ValueError('No captured method to release')

    # Wrappers for accessing logging
    def debug(self, *args, **kwargs):
        self.logger.debug(*args, **kwargs)

    def info(self, *args, **kwargs):
        self.logger.info(*args, **kwargs)

    def warning(self, *args, **kwargs):
        self.logger.warning(*args, **kwargs)

    def error(self, *args, **kwargs):
        self.logger.error(*args, **kwargs)

    def critical(self, *args, **kwargs):
        self.logger.critical(*args, **kwargs)

class CryoSRAM :
    '''
    Main class for communicating with cryoSRAM chip
    Handles io and keeps track of cryoSRAM state
    '''
    addr_range = [0,2**9]
    val_range = [0,2**8]
    rw_delay = 0.001 # [s] minimum time between commands

    SET_ADDR = bitarray('0001')
    WRITE_VAL = bitarray('0010')
    READ_ADDR = bitarray('0011')
    READ_VAL =  bitarray('0100')
    SET_CLK =  bitarray('0101')
    READ_CLK =  bitarray('0110')
    SET_DELAY =  bitarray('0111')

    def __init__(self, reg_val_map=None, io=None, log=None, clk_factor=25, test=False, delay_factor=0):
        '''
        `log` should be a `CryoLogger` or `logging.getLogger(<name>)` object
        `reg_val_map` should be a map of addr : val
          missing values are initialized to None
        `io` should be an io class with `read(<nbytes>)` and `write(<bytes>)`
          methods
        `test` can be used to test functionality without FPGA (overrides `io` with a `TestIO`)
        '''
        self.test = test
        self.io = io

        if log is None:
            self.log = CryoLogger()
        else:
            self.log = log

        if self.test:
            self.io = TestIO()
        self.io.read = self.log.capture_read(self.io.read)
        self.io.write = self.log.capture_write(self.io.write)

        self.clk_factor = clk_factor
        self.delay_factor = delay_factor
        self.curr_addr = 0;
        self.memory = {}
        if reg_val_map is None:
            for addr in range(*CryoSRAM.addr_range):
                self.memory[addr] = None
        elif isinstance(reg_val_map, map):
            for addr in range(*CryoSRAM.addr_range):
                try:
                    self.memory[addr] = reg_val_map[addr]
                except IndexError:
                    self.memory[addr] = None
        else:
            raise ValueException('invalid type for initialization')

    def __str__(self):
        '''
        return string of self
        '''
        return_str = 'CryoSRAM(io={io}, log={log}, clk_factor={clk_factor}, curr_addr={curr_addr})'.format(**vars(self))
        return return_str

    def set_addr(self, addr):
        '''
        Set address
        '''
        binary_word = format(addr,'09b')
        header = self.SET_ADDR + bitarray('0'*3) + bitarray(binary_word[0])
        word = bitarray(binary_word[1:])
        #self.log.debug('TX - {} {}'.format(header, word))
        self.io.write(header.tobytes() + word.tobytes())
        time.sleep(self.rw_delay)
        self.curr_addr = addr

    def write_value(self, val):
        '''
        Write value to current address
        '''
        header = self.WRITE_VAL + bitarray('0'*4)
        binary_word = format(val,'08b')
        word = bitarray(binary_word)
        #self.log.debug('TX - {} {}'.format(header, word))
        self.io.write(header.tobytes() + word.tobytes())
        time.sleep(self.rw_delay)
        self.memory[self.curr_addr] = val

    def read_addr(self):
        '''
        Read current address from fpga
        '''
        tx_header, tx_word = self.READ_ADDR + bitarray('0'*4), bitarray('0'*8)
        rx_header, rx_word = bitarray(''), bitarray('')
        #self.log.debug('TX - {} {}'.format(tx_header, tx_word))
        self.io.write(tx_header.tobytes() + tx_word.tobytes())
        read_bytes = self.io.read(2)
        time.sleep(self.rw_delay)
        if len(read_bytes) != 2:
            self.log.warning('rx bytes {}, expected 2'.format(len(read_bytes)))
            self.curr_addr = None
            return None
        rx_header.frombytes(read_bytes[0])
        rx_word.frombytes(read_bytes[1])
        #self.log.debug('RX - {} {}'.format(rx_header, rx_word))
        read = rx_header + rx_word
        self.curr_addr = int(read[-10:].to01(),2)
        return self.curr_addr

    def read_value(self):
        '''
        Read value from current address
        '''
        tx_header, tx_word = self.READ_VAL + bitarray('0'*4), bitarray('0'*8)
        rx_header, rx_word = bitarray(''), bitarray('')
        #self.log.debug('TX - {} {}'.format(tx_header, tx_word))
        self.io.write(tx_header.tobytes() + tx_word.tobytes())
        read_bytes = self.io.read(2)
        time.sleep(self.rw_delay)
        if len(read_bytes) != 2:
            self.log.warning('rx bytes {}, expected 2'.format(len(read_bytes)))
            self.memory[self.curr_addr] = None
            return None
        rx_header.frombytes(read_bytes[0])
        rx_word.frombytes(read_bytes[1])
        #self.log.debug('RX - {} {}'.format(rx_header, rx_word))
        self.memory[self.curr_addr] = int(rx_word.to01(),2)
        return self.memory[self.curr_addr]

    def set_clk(self, clk_factor):
        '''
        Set driving clk speed
        clk_factor = 1   : 25.00 MHz
        clk_factor = 2   : 12.50 MHz
        clk_factor = 3   : 8.333 MHz
        clk_factor = 5   : 5.000 MHz
        clk_factor = 10  : 2.500 MHz
        clk_factor = 25  : 1.000 MHz
        ...
        clk_factor = 255 : 0.098 MHz
        '''
        header = self.SET_CLK + bitarray('0'*4)
        word = bitarray(format(clk_factor,'08b'))
        #self.log.debug('TX - {} {}'.format(header, word))
        self.io.write(header.tobytes() + word.tobytes())
        time.sleep(self.rw_delay)
        self.clk_factor = clk_factor

    def read_clk(self):
        '''
        Read current clk from fpga
        '''
        tx_header, tx_word = self.READ_CLK + bitarray('0'*4), bitarray('0'*8)
        rx_header, rx_word = bitarray(''), bitarray('')
        #self.log.debug('TX - {} {}'.format(tx_header, tx_word))
        self.io.write(tx_header.tobytes() + tx_word.tobytes())
        read_bytes = self.io.read(2)
        time.sleep(self.rw_delay)
        if len(read_bytes) != 2:
            self.log.warning('rx bytes {}, expected 2'.format(len(read_bytes)))
            self.clk_factor = None
            return None
        rx_header.frombytes(read_bytes[0])
        rx_word.frombytes(read_bytes[1])
        #self.log.debug('RX - {} {}'.format(rx_header, rx_word))
        self.clk_factor = int(rx_word.to01(),2)
        return self.clk_factor

    def set_delay(self, delay_factor):
        '''
        Set delay for read in 100MHz clk ticks after CEN goes high
        '''
        header = self.SET_DELAY + bitarray('0'*4)
        word = bitarray(format(delay_factor,'08b'))
        #self.log.debug('TX - {} {}'.format(header, word))
        self.io.write(header.tobytes() + word.tobytes())
        time.sleep(self.rw_delay)
        self.delay_factor = delay_factor

    def test_summary(self, faults):
        '''
        Prints a basic summary of faults
        '''
        self.log.info('Summary:')
        self.log.info('stage\tfaults')
        for key in sorted(faults.keys()):
            self.log.info('{}\t{}'.format(key,len(faults[key])))

    def serial_test(self):
        '''
        Runs serial io test (independent of cryoSRAM)
        - set and read back fpga address
        '''
        self.log.info(' ~ Start serial test ~')
        faults = {
            'serial': []
        }
        self.log.info('Set addr and read back')
        for addr in range(*self.addr_range):
            self.set_addr(addr)
            self.read_addr()
            if self.curr_addr != addr:
                faults['serial'] += [(addr, addr, self.curr_addr)]

        self.test_summary(faults)
        self.log.info(' ~ End serial test ~')
        return faults, None

    def mats_test(self):
        '''
        Runs basic MATS++ test :
        - write all to 0
        - verify and write all to 1
        - verify and write all to 0
        - verify
        returns a dict :
          '-> 0' - faults after write 0
          '0 -> 1' - faults after 0 -> 1 transition
          '1 -> 0' - faults after 1 -> 0 transition
        fault lists are tuples of :
          (addr, expected, read)
        '''
        self.log.info(' ~ Start MATS++ test ~')
        stages = ['-> 0', '0 -> 1', '1 -> 0']
        faults = dict([(stage, []) for stage in stages])
        bitmaps = dict([(stage, []) for stage in stages])
        # First -> 0
        self.log.info('Set -> 0')
        w = 0
        for addr in range(*self.addr_range):
            self.set_addr(addr)
            self.write_value(w)

        # Now 0 -> 1
        w = 255
        self.log.info('Verify 0 and set 0 -> 1')
        for addr in range(*self.addr_range):
            self.set_addr(addr)
            expected = self.memory[addr]
            self.read_value()
            bitmaps[stages[0]] += [(addr, self.memory[addr])]
            if self.memory[addr] != expected:
                faults[stages[0]] += [(addr, expected, self.memory[addr])]
            self.write_value(w)

        # Now 1 -> 0
        w = 0
        self.log.info('Verify 1 and set 1 -> 0')
        for addr in range(*self.addr_range):
            self.set_addr(addr)
            expected = self.memory[addr]
            self.read_value()
            bitmaps[stages[1]] += [(addr, self.memory[addr])]
            if self.memory[addr] != expected:
                faults[stages[1]] += [(addr, expected, self.memory[addr])]
            self.write_value(w)

        # Final readback
        self.log.info('Verify 0')
        for addr in range(*self.addr_range):
            self.set_addr(addr)
            expected = self.memory[addr]
            self.read_value()
            bitmaps[stages[2]] += [(addr, self.memory[addr])]
            if self.memory[addr] != expected:
                faults[stages[2]] += [(addr, expected, self.memory[addr])]

        self.test_summary(faults)
        self.log.info(' ~ End MATS++ test ~')
        return faults, bitmaps

    def pattern_test(self, test_values=[85,1,2,4,8,16,32,64,128,170]):
        '''
        Executes a pattern test:
         - write pattern described by `test_values`
         - verify
        returns a dict :
          'pattern' - faults identified
        fault lists are tuples of :
          (addr, expected, read)
        '''
        self.log.info(' ~ Start pattern test ~')
        stages = ['pattern']
        faults = dict([(stage, []) for stage in stages])
        bitmaps = dict([(stage, []) for stage in stages])

        doubled_pattern = test_values + list(reversed(test_values))
        self.log.info('Write pattern:')
        for value in doubled_pattern:
            self.log.info(format(value,'08b'))
        for addr in range(*self.addr_range):
            w = doubled_pattern[addr%(len(doubled_pattern))]
            self.set_addr(addr)
            self.write_value(w)

        self.log.info('Verify')
        for addr in range(*self.addr_range):
            self.set_addr(addr)
            expected = self.memory[addr]
            self.read_value()
            bitmaps[stages[0]] += [(addr, self.memory[addr])]
            if self.memory[addr] != expected:
                faults[stages[0]] += [(addr, expected, self.memory[addr])]

        self.test_summary(faults)
        self.log.info(' ~ End pattern test ~')
        return faults, bitmaps

    def single_bit_test(self, test_values=[1,2,4,8,16,32,64,128]):
        '''
        Runs a sigle bit test:
         - write all to 0
         - for each test_value, write and verify, then write 0 and verify
        returns a dict :
          '0i' - faults during initial write to 0
          '<test value>' - faults during write to test value
          '00000000' - faults during return to 0
        fault lists are tuples of :
          (addr, expected, read)
        '''
        self.log.info(' ~ Start single bit test ~')
        self.log.info('Values: {}'.format([format(value,'08b') for value in test_values]))
        stages = ['-> 0']
        faults = dict([(stage,[]) for stage in stages])
        bitmaps = dict([(stage,[]) for stage in stages])
        for value in test_values + [0]:
            faults[format(value,'08b')] = []
            bitmaps[format(value,'08b')] = []

        self.log.info('Set -> 0')
        w = 0
        for addr in range(*self.addr_range):
            self.set_addr(addr)
            self.write_value(w)

        self.log.info('Perform single bit write and verification')
        for addr in range(*self.addr_range):
            self.set_addr(addr)

            # check initial value
            expected = self.memory[addr]
            self.read_value()
            bitmaps[stages[0]] += [(addr, self.memory[addr])]
            if self.memory[addr] != expected:
                faults[stages[0]] += [(addr, expected, self.memory[addr])]

            # write test values
            for w in test_values:
                self.write_value(w)
                expected = self.memory[addr]
                self.read_value()
                bitmaps[format(w,'08b')] += [(addr, self.memory[addr])]
                if self.memory[addr] != expected:
                    faults[format(w,'08b')] += [(addr, expected, self.memory[addr])]
            # check final value
            w = 0
            self.write_value(w)
            expected = self.memory[addr]
            self.read_value()
            bitmaps[format(w,'08b')] += [(addr, self.memory[addr])]
            if self.memory[addr] != expected:
                faults[format(w,'08b')] += [(addr, expected, self.memory[addr])]

        self.test_summary(faults)
        self.log.info(' ~ End single bit test ~')
        return faults, bitmaps

    def rand_test(self, n_static=2, n_dynamic=2.5e3):
        '''
        Issues n_static writes of complete memory, verifying each
        Issues n_dynamic random read and writes of memory verifying each read
        returns dicts :
          'rand_static' - faults with random written values
          'rand_dynamic' - faults during dynamic read/writes
        fault lists are tuples of :
          (addr, expected, read)
        '''
        self.log.info(' ~ Start random test ~')
        stages = ['rand_static', 'rand_dynamic']
        faults = dict([(stage,[]) for stage in stages])
        bitmaps = dict([(stage,[]) for stage in stages])

        # First read back the current state
        self.log.info('Store current state')
        for addr in range(*self.addr_range):
            self.set_addr(addr)
            self.read_value()

        # Issue N 'static' read/writes
        for i in range(int(n_static)):
            self.log.info('Static RW {}/{}'.format(i+1,n_static))
            for addr in range(*self.addr_range):
                self.set_addr(addr)
                w = randint(self.val_range[0], self.val_range[-1]-1)
                self.write_value(w)
            for addr in range(*self.addr_range):
                self.set_addr(addr)
                expected = self.memory[addr]
                self.read_value()
                bitmaps[stages[0]] += [(addr, self.memory[addr])]
                if self.memory[addr] != expected:
                    faults[stages[0]] += [(addr, expected, self.memory[addr])]

        # Issue N 'dynamic' read/writes
        for i in range(int(n_dynamic)):
            if i%(n_dynamic/10) == 0:
                self.log.info('Dynamic RW {}/{}'.format(i,n_dynamic))
            addr = randint(self.addr_range[0], self.addr_range[-1]-1)
            self.set_addr(addr)
            choose_write = randint(0,1)
            if choose_write:
                w = randint(self.val_range[0], self.val_range[-1]-1)
                self.write_value(w)
            else:
                expected = self.memory[addr]
                self.read_value()
                bitmaps[stages[1]] += [(addr, self.memory[addr])]
                if self.memory[addr] != expected:
                    faults[stages[1]] += [(addr, expected, self.memory[addr])]
        self.test_summary(faults)
        self.log.info(' ~ End random test ~')
        return faults, bitmaps

class TestIO:
    '''
    A dummy class for testing IO
    '''

    def __init__(self):
        self.queued_bytes = []

    def write(self, write_bytes):
        '''
        Mock write message
        '''
        print(write_bytes)

    def read(self, n_bytes):
        '''
        Mock read message
        '''
        read_bytes = 0
        return_bytes = b''
        for byte_idx in range(n_bytes):
            if len(self.queued_bytes):
                print(self.queued_bytes[0])
                return_bytes += self.queued_bytes[0]
                del self.queued_bytes
        return return_bytes
