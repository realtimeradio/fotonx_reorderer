# fotonx_reorderer
A Simulink FFT reorderer based on requirements provided by FotonX

## Dependencies

- Vivado / Model Composer 2021.1
- MATLAB / Simulink R2021a
- Ubuntu 20.04.6 (Tested OS)

## Clone this repository

```bash
git clone https://github.com/realtimeradio/fotonx_reorderer
# If you wish to develop using the bundled mlib_devel, clone that too
cd fotonx_reorderer
git submodule init
git submodule update
```

## Modify cores

1. Clone the repository and its submodules, as above.
2. Create a custom `startsg.local` file, defining paths to Vivado and MATLAB installations (see startst.local.rtr for an example)
3. Start simulink

  ```bash
  ./startsg <custom_startsg.local>
  ```

## Module Description

The supplied module takes input spectra -- supplied as a bus of `2^parallel_chan_bits` parallel FFT channels, cycling over a full FFT spectra in `2^serial_chan_bits` clock cycles -- and outputs a bus of subselected channels -- output as a bus of `2^parallel_samp_bits`, cycling over `2^serial_chan_bits` clock cycles.

The module can arbitrarily map input channels to output positions and may repeat inputs in multiple output channel indices.

Two cores are provided for the cases `2^parallel_chan_bits=4` and `2^parallel_chan_bits=8`.
In both cases, `2^serial_chan_bits=512` and `2^parallel_samp_bits=2`.

In the first case, 2048 channels are subselected to 1024, configured for an FPGA "Simulink" clock 1/4 the upstream ADC sampling rate. 
This module is named `chan_select4x`.

In the second case, 4096 channels are subselected to 1024, configured for an FPGA "Simulink" clock 1/8 the upstream ADC sampling rate.
This module is named `chan_select8x`.

### Theory of Operation

There are many ways to make a module which arbitrarily reorders and subselects `N` parallel inputs to `M` parallel outputs.
If the reorder can be constrained, for example, by requiring that for `M` parallel inputs only `N` of them shall ever be part of the selection map, various optimisations can be made.
In the general case, optimisations are more difficult to find.
The core provided here uses the most general reordering and subselection requirements, and is designed so as to be easy to understand, and easy to modify.

The steps of the reordering and selection process are as follows:

1. Transpose `M` input spectra such that on each FPGA clock cycle, the FPGA deals with a single FFT bin index, but `M` successive time samples.
2. Perform a runtime-defined remapping of input to output channel number, such that any input FFT channel ID may be remapped to a different position (including mapping a single input to multiple outputs.
3. Undo the data transpose so that the output ordering is once again single time samples, but now `N` parallel channels.
4. Discard `M/N` of the output channels so that only the desired subset of the input channels remain.

(In actual fact, steps 3 and 4 and partially swapped, such that most of the final data transpose is performed only on the channels which are not being discarded).

The entire reordering and subselection pipeline is based on CASPER's `square_transpose` block -- which transposes square blocks of `n` by `n` parallel by serial samples -- and CASPER's `reorder` block, which reorders serial data samples.
Using only these two blocks means that the pipeline is relatively easy to understand and verify, for anyone familiar with the CASPER DSP blockset.

#### Note 1: In-place reordering

The CASPER `reorder` block has the ability to reorder in-place rather than double buffering.
This halves the amount of RAM needed for data storage, but also means that it takes many reorder cycles for the block to return to its initial state.
This is rarely a problem in designs, but it should be noted that this places requirements on the allowed periodicity of the block's `sync` input.
See the [CASPER Sync Pulse Usage Memo](https://github.com/casper-astro/publications/blob/master/Memos/files/sync_memo_v1.pdf) for more information.

### Parameters

_NB: The parameters exposed in Simulink are provided to aid in porting the module to new configurations. However, without modifications to the CASPER `mlib_devel` library and creation of a full draw script, changing parameters alone is not adequate to completely regenerate a new configuration._

| Parameter            | Description |
| :------------------: | :---------- |
| `serial_chan_bits`   | `log2` of the number of clock cycles required to input a full FFT spectrum |
| `parallel_chan_bits` | `log2` of the number of parallel FFT channels presented on the `din` port each clock cycle |
| `parallel_samp_bits` | `log2` of the number of parallel channels output on the `dout` port each clock cycle |
| `bitwidth`           | Number of bits per real/imag component of each FFT channel data |

### Ports

| Port Name      | Direction | Data Type | Description |
| :------------- | :-------: | :-------: | :---------- |
| `sync`         | input     | Bool      | Synchronization pulse. Should be high for one cycle before the first channel of a spectra. Duty cycle should respect the periodicity requirements outlined in the [CASPER Sync Pulse Usage Memo](https://github.com/casper-astro/publications/blob/master/Memos/files/sync_memo_v1.pdf). See example models for settings.|
| `din`          | input     | UFix<`2 x bitwidth x 2^parallel_chan_bits`>\_0 | FFT data. `2^parallel_chan_bits` channels should be presented in parallel, with the lowest-index channel in the most significant bits.|
| `chan_out_id`  | input     | UFix<`serial_chan_bits x parallel_samp_bits`>\_0 | The output index to be assigned to FFT channel with index `chan_in_id`|
| `chan_in_id`   | input     | UFix<`serial_chan_bits x parallel_chan_bits`>\_0 | The FFT channel index to be assigned to output index `chan_out_id` |
| `map_we`       | input     | Bool | Active-high write enable triggering a write of the channel map presented on `chan_out_id` and `chan_in_id`. |
| `sync_out`     | output    | Bool | Synchronization pulse output. High for one cycle before the first channel of an output spectra corresponding to the input spectra preceded by a sync. |
| `dout`         | output    | UFix<`2 x bitwdith x 2^parallel_samp_bits`>\_0 | Sub-selected output data. `2^parallel_samp_bits` are presented on every clock cycle, with the lowest-index sample in the most significant bits|
| `chan_map_out` | output    | UFix<`serial_chan_bits x parallel_chan_bits`>\_0 | Selection map readout. The FFT channel being output with output index `chan_out_id`. Data on this port reflects the value of `chan_out_id` on the previous clock cycle. I.e., the lookup table has latency 1.|

## Examples and Testbenches

4-parallel input and 8-parallel input flavours of the reorder module are provided in `reorderer4x.slx` and `reorderer8x.slx`, respectively.

These models also serve as test benches, which can be executed with:

```matlab
>> run_tb
Testing 4-parallel input reorder/selection module
Model reorderer4x is already open.
Detected 2048 input channels
Detected 4 parallel inputs
Sync period is 45056
Number of data blocks is 88
Map readback OK
sync found at: 6170
Channel Selection Data Check OK
********************
* Testbench PASSED *
********************
Testing 8-parallel input reorder/selection module
Model reorderer8x is already open.
Detected 4096 input channels
Detected 8 parallel inputs
Sync period is 49152
Number of data blocks is 96
Map readback OK
sync found at: 16324
Channel Selection Data Check OK
********************
* Testbench PASSED *
********************
```

These test benches generate artificial test data, load a random channel selection map into the block, and verify that the output data are as expected.

Pay particular note to the sync periodicity in the test models, which guarantees glitchless operation.

## Control interface

Assuming that the `chan_out_id`, `chan_in_id`, `map_we` and `chan_map_out` ports are connected to software-controlled registers (driven by `casperfpga` or `Pynq` or similar), the following is an example Python method to load and read a channel selection map.

```python

# Example functions to set inputs and read outputs.
# These should be implemented by the user based on the environment being used.

def write_chan_out_id(n):
   """
   Set the chan_out_id input to value n
   """
   raise NotImplementedError

def write_chan_in_id(n):
   """
   Set the chan_in_id input to value n
   """
   raise NotImplementedError

def write_map_we(n):
   """
   Set the map_we input to value n
   """
   raise NotImplementedError

def read_chan_map_out():
   """
   Return the current integer value on the chan_map_out output.
   """
   raise NotImplementedError

# Higher-level control functions

def set_map_entry(input_id, output_id):
   """
   Configure the core to output FFT input channel index `input_id`
   in output position index `output_id`
   """
   write_map_we(0) # Disable map write-enable
   # Configure new entry
   write_chan_in_id(input_id)
   write_chan_out_id(output_id)
   # Strobe write-enable
   write_map_we(1)
   write_map_we(0)

def get_map_entry(output_id):
   """
   Get the FFT input channel index of the channel being output
   in position index `output_id`
   """
   write_map_we(0) # Disable map write-enable
   # Address map look-up-table to return desired entry
   write_chan_out_id(output_id)
   # Read look-up-table contents
   return read_chan_map_out()

def set_output_map(input_ids):
   """
   Given a list, `input_ids` whose i-th entry
   contains the FFT channel which should be output
   in position `i`, write a complete map to the
   selection core.
   """
   for output_id, input_id in enumerate(input_ids):
       set_map_entry(input_id, output_id)

def get_output_map(n=1024):
   """
   Get the input FFT channel indices of the channels
   being output in positions `0` to `n-1`.
   These are returned as a list where the i-th entry
   contains the channel which is being output in position `i`.
   """
   current_map = []
   for i in range(n):
       current_map += [get_map_entry(i)]
   return current_map
```
   
