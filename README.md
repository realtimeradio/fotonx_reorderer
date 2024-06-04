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
  ./startsg <custom_startsh.local>
  ```

