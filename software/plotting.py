import matplotlib.pyplot as plt
import numpy as np
#plt.ion()

def convert_to_bitmap(byte):
    '''
    Generates a list of (bit, bit_idx) pairs for a bit map
    '''
    binary = format(byte,'08b')
    values = []
    for i,bit in enumerate(binary):
        values += [(int(bit), i)]
    return values

def find_bit_errors(expected_byte, actual_byte):
    '''
    inputs should be convertable to 8-bit string via format(<>,'08b')
    return list of (error type, bit index)
    '''
    expected_binary = format(expected_byte,'08b')
    actual_binary = format(actual_byte,'08b')
    errors = []
    for i,bit in enumerate(actual_binary):
        if bit != expected_binary[i]:
            bit_idx = i
            expected_bit = expected_binary[i]
            error = int(bit) - int(expected_bit)
            errors += [(error, bit_idx)]
    return errors

def collect_bit_errors(fault_list):
    '''
    fault_list should be formatted (addr, expected, actual)
    returns list of (addr, bit_idx, bit error type)
    '''
    collected_bit_error_list = []
    for addr, expected, actual in fault_list:
        bit_error_list = find_bit_errors(expected, actual)
        for error_type, bit_idx in bit_error_list:
            collected_bit_error_list += [(addr, bit_idx, error_type)]
    return collected_bit_error_list

def plot_bit_map(bit_map, label='Bit map', show=True):
    '''
    Visualizes the memory described by bit_map
    Effectively this is a bit "intensity" plot
    Bit_map should be a list of (addr, byte) pairs
    '''
    x = []
    y = []
    w = []
    bins = [np.linspace(0,8,65),range(0,65)]
    for addr, byte in bit_map:
        for bit, bit_idx in convert_to_bitmap(byte):
            x += [bit_idx/8. + int(addr/64)]
            y += [addr%64]
            w += [2*bit - 1]
    plt.figure(label)
    plt.subplot(2,1,1)
    bmax = max(abs(np.histogram2d(x,y,bins,weights=w)[0]).max(),1)
    plt1 = plt.hist2d(x,y,bins,weights=w,cmap='seismic',vmin=-bmax,vmax=bmax)
    plt1_lines = plt.vlines(range(0,8),0,64,linestyles='dashed')
    cb1 = plt.colorbar(ticks=[-bmax,0,bmax])
    cb1.set_label('value')
    cb1.ax.set_yticklabels(['0','','1'])
    plt.ylabel('address[5:0]')

    plt.subplot(2,1,2)
    plt2 = plt.hist2d(x,y,bins,cmap='Greys')
    plt2_lines = plt.vlines(range(0,8),0,64,linestyles='dashed')
    cb2 = plt.colorbar()
    cb2.set_label('count')
    plt.ylabel('address[5:0]')
    
    plt.xlabel('address[8:6]')
    if show:
        plt.show()

def plot_bit_error_map(fault_list, label='Bit error map', weight_by_error=False, show=True):
    '''
    Expects a standard fault_list formatted (addr, expected, actual)
    Generates 2D histograms of bit errors
    Use `weight_by_error` to display net bit error (+1 for 1 and -1 for 0)

    '''
    bit_error_list = collect_bit_errors(fault_list)
    x = []
    y = []
    w = []
    bins = [np.linspace(0,8,65),range(0,65)]
    for addr, bit_idx, bit_error in bit_error_list:
        x += [bit_idx/8. + int(addr/64)]
        y += [addr%64]
        w += [bit_error]
    plt.figure(label)
    if weight_by_error:
        ax1 = plt.subplot(2,1,1)
    nmax = max(np.histogram2d(x,y,bins)[0].max(), 1)
    plt1 = plt.hist2d(x,y,bins,cmap='Greys',vmin=0,vmax=nmax)
    plt1_lines = plt.vlines(range(0,8),0,64,linestyles='dashed')
    cb1 = plt.colorbar()
    cb1.set_label('errors')
    plt.ylabel('address[5:0]')
    
    if weight_by_error:
        ax2 = plt.subplot(2,1,2)
        wmax = max(abs(np.histogram2d(x,y,weights=w,bins=bins)[0]).max(), 1)
        plt2 = plt.hist2d(x,y,bins,weights=w,cmap='seismic',vmin=-wmax,vmax=wmax)
        plt2_lines = plt.vlines(range(0,8),0,64,linestyles='dashed')
        cb2 = plt.colorbar(ticks=[-wmax,0,wmax])
        cb2.set_label('net error type')
        cb2.ax.set_yticklabels(['0','','1'])
        plt.ylabel('address[5:0]')

    plt.xlabel('address[8:6]')
    if show:
        plt.show()

def plot_test_scan(faults, desc, label='Test scan', xlabel='', show=True):
    '''
    Generates a plot of bit/byte errors from a test scan
    Expects faults to be of the form:
    {
      <x value> : {
        <desc> : [
          (<address>, <expected>, <actual>),
          ...
        ]
      },
      ...
    }
    '''
    x = sorted(faults.keys())
    bit_errors = []
    byte_errors = []
    for value in x:
        test_results = faults[value]
        bit_errors += [len(collect_bit_errors(test_results[desc]))]
        byte_errors += [len(test_results[desc])]

    plt.figure(label)
    plt.plot(x, byte_errors, '.-', label='Byte errors')
    plt.plot(x, bit_errors, '.-', label='Bit errors')
    plt.legend()
    plt.ylabel('Count')
    plt.xlabel(xlabel)

    if show:
        plt.show()
