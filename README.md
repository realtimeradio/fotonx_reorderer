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


