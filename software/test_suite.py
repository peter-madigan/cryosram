#!/usr/bin/ipython -i
import os
import sys
from cryoCMOS import *
from plotting import *
from serial import Serial, SerialException
from serial.tools.list_ports import comports

def list_ports():
    '''
    Lists available ports
    '''
    for port in comports():
        print(port)

def quick_serial(port='/dev/ttyUSB1',baudrate=1e6, timeout=1):
    '''
    Wrapper for Serial constructor class with my standard values
    '''
    return Serial(port=port, baudrate=baudrate, timeout=timeout)    

def run_test_suite(c, clk_factors=[25, 10, 5, 3, 2, 1]):
    '''
    Runs primary tests on `CryoSRAM` object
    These are:
     - `mats_test`
     - `pattern_test`
     - `single_bit_test`
     - `rand_test`
    For each test, the clk speed is scanned over the values specified by 
      `clk_factors`
    '''
    tests = [
        c.mats_test,
        c.pattern_test,
        c.single_bit_test,
        c.rand_test
    ]
    faults = {}
    bitmaps = {}
    c.log.info(' ~~ Test suite start ~~')
    for test in tests:
        faults[test.__name__], bitmaps[test.__name__] = run_clk_scan(c, test, clk_factors=clk_factors)
    c.log.info(' ~~ Test suite end ~~')
    return faults, bitmaps

def run_clk_scan(c, test, clk_factors=[25, 10, 5, 3, 2, 1]):
    '''
    Repeats test while scanning the clk through specified values
    '''
    faults = {}
    bitmaps = {}
    c.log.info(' ~~ Clock scan start ~~')
    for clk_factor in clk_factors:
        c.log.info('Set clk to {} MHz'.format(100/(4*clk_factor)))
        c.set_clk(clk_factor)
        if c.read_clk() != clk_factor:
            c.log.error('Clk not set! Is {} MHz'.format(100/(4*c.clk_factor)))
            raise RuntimeError
        faults[clk_factor], bitmaps[clk_factor] = test()
    c.log.info(' ~~ Clock scan end ~~')
    return faults, bitmaps

def generate_plots(c, test_suite_results, show_plots=False):
    '''
    Basic method to generate basic plots from run_test_suite
    '''
    outdir = c.log.directory + '/plots_'+ c.log.filename
    try:
        os.mkdir(outdir)
        c.log.info('Saving plots to {}'.format(outdir))
    except OSError:
        pass

    faults = test_suite_results[0]
    bitmaps = test_suite_results[1]
    
    tests = faults.keys()
    for test in tests:
        c.log.info('Saving {} results'.format(test))
        test_outdir = outdir + '/' + test
        try:
            os.mkdir(test_outdir)
            c.log.info('Saving to {}'.format(test_outdir))
        except OSError:
            pass

        clk_speeds = faults[test].keys()
        test_stages = faults[test][clk_speeds[0]].keys()
        for test_stage in test_stages:
            plot_test_scan(faults[test], test_stage, label='Clk test scan ({} - stage {})'.format(test, test_stage), xlabel='clk factor', show=show_plots)
            plt.savefig(test_outdir + '/clk_scan_{}.pdf'.replace(' ','_').replace('->','to').format(test_stage))
            if not show_plots:
                plt.close()
            
            for clk_speed in clk_speeds:
                plot_bit_map(bitmaps[test][clk_speed][test_stage], label='Bit map ({} - stage {}) @ {} clk factor'.format(test, test_stage, clk_speed), show=show_plots)
                plt.savefig(test_outdir + '/bit_map_{}_{}.pdf'.format(test_stage.replace(' ','_').replace('->','to'), clk_speed))
                if not show_plots:
                    plt.close()
                plot_bit_error_map(faults[test][clk_speed][test_stage], label='Bit error map ({} - stage {}) @ {} clk factor'.format(test, test_stage, clk_speed), weight_by_error=True, show=show_plots)
                plt.savefig(test_outdir + '/bit_errors_{}_{}.pdf'.format(test_stage.replace(' ','_').replace('->','to'), clk_speed))
                if not show_plots:
                    plt.close()

def main(args):
    out_dir = 'data/'+time.strftime('%Y_%m_%d')
    try:
        os.mkdir(out_dir)
    except OSError:
        pass
    log = CryoLogger(directory=out_dir)
    c = None
    try:
        c = CryoSRAM(io=quick_serial(port=args[1]), log=log)
    except IndexError:
        try:
            c = CryoSRAM(io=quick_serial(), log=log)
        except SerialException:
            c = CryoSRAM(io=None, log=log, test=True)
            c.log.error('Failed to open serial port! Running in test mode!')
    c.set_delay(4)
    
    print('')
    print('Available helper functions:')
    print(' list_ports() - {}'.format(list_ports))
    print(' quick_serial() - {}'.format(quick_serial))
    print(' run_test_suite(<cryoSRAM obj>, clk_factors=[25,10,5,3,2,1]) - {}'.format(run_test_suite))
    print(' run_clk_scan(<cryoSRAM obj>, <cryoSRAM test method>, clk_factors=[25,10,5,3,2,1]) - {}'.format(run_clk_scan))
    print(' generate_plots(<cryoSRAM obj>, <run_test_suite results>) - {}'.format(generate_plots))
    print('')
    print('Available objects:')
    print(' c - {}'.format(c))
    print('')
    print('Logging:')
    print(' c.log.[debug info warning error critical](<msg>)')
    print('')
    print('Standard tests:')
    print(' c.serial_test() - test serial comms with fpga')
    print(' c.mats_test() - standard MATS++ test')
    print(' c.pattern_test(test_values=[<85,1,2,4...128,170>]) - write pattern '
          ' and verify')
    print(' c.single_bit_test(test_values=[<1,2,4...128>]) - flips the specified'
          ' bits at each address')
    print(' c.rand_test(n_static=5, n_dynamic=10e3) - issues random read / writes')
    print('')
    print('Plotting help:')
    print(' plot_bit_error_map(fault_list, label="Bit error map", weight_by_error=False) - Show 2D histogram counting bit errors')
    print('plot_test_scan(faults, desc, label="Test scan", xlabel="") - Plot bit and byte errors across scan')
    print('')
    print('To perform EVERYTHING, just type:')
    print('results = run_test_suite(c); generate_plots(c, results)')
    print('and press enter!')
    print('')

    if c.test:
        c.log.warning('Running in test mode - FPGA communication is not occurring!')

    plt.ion()
    return c

if __name__ == '__main__':
    c = main(sys.argv)
