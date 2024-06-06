function configure_test(model_name)

% Usage: configure_test(model_name, n_serial_chan_bits, n_parallel_chan_bits)
%
% model_name: A valid .slx simulink file containing a reorder module to be
% simulated. Do not include the .slx extension.
    
SIM_LEN = 150000; % Simulation length, in clock cycles
RNG_SEED = 12345; % Random number generator seed

% Input vector initialization
t = [0 : SIM_LEN - 1];
chan_in_id = timeseries(zeros(SIM_LEN, 1), t);
chan_out_id = timeseries(zeros(SIM_LEN, 1), t);
map_we = timeseries(zeros(SIM_LEN, 1), t);

% Open the model if it isn't open
% Keep track of if we opened model so that we can close it.
close_slx_when_done = 0;
try
    % Check if the model is already open
    if ~bdIsLoaded(model_name)
        % Model is not open, open it
        disp(['Opening ', model_name]);
        open_system(model_name);
        close_slx_when_done = 1;
    else
        % Model is already open
        disp(['Model ', model_name, ' is already open.']);
    end
catch ME
    % Handle errors gracefully
    disp(['Error: Unable to open model ', model_name]);
    disp(['Details: ', ME.message]);
end

% Get module parameters
inst = [model_name '/chan_select']; % module instance name
n_serial_chan_bits = str2num(get_param(inst, 'serial_chan_bits'));
n_parallel_chan_bits = str2num(get_param(inst, 'parallel_chan_bits'));
n_input_channels = 2^(n_serial_chan_bits + n_parallel_chan_bits);
n_parallel_out_chans = 2^str2num(get_param(inst, 'parallel_samp_bits'));
n_out_chans = n_parallel_out_chans * 2^n_serial_chan_bits;

fprintf('Detected %d input channels\n', n_input_channels);
fprintf('Detected %d parallel inputs\n', 2^n_parallel_chan_bits);

% Create a random map

rng(RNG_SEED);
% Create a map placing random channels in each of N_OUT_CHANS slots
r = randi([0, n_input_channels], n_out_chans, 1);

% Write the channel map in the first N_OUT_CHANS clock cycles
chan_in_id.Data(1:n_out_chans) = r;
chan_out_id.Data(1:n_out_chans) = [0 : n_out_chans - 1];
map_we.Data(1:n_out_chans) = 1;
% Cycle through the map LUT address, with write-enable low for readback
chan_out_id.Data(n_out_chans + 1 : 2*n_out_chans) = [0 : n_out_chans - 1];

% Send these variable to the main workspace so simulink can see them
assignin('base', 'chan_in_id', chan_in_id);
assignin('base', 'chan_out_id', chan_out_id);
assignin('base', 'map_we', map_we);

% Configure simulation length and start simulation
set_param(model_name, 'StopTime', num2str(SIM_LEN));
clear('out');
out = sim(model_name);

% Get sync period -- this is the periodicity with which simulated data
% resets
sync_gen = [model_name '/sync_gen'];
sync_period_str = get_param(sync_gen, 'AttributesFormatString');
sync_period = sscanf(sync_period_str, 'sim_sync_period=%d ');
sync_period_blocks = sync_period / (n_out_chans / n_parallel_out_chans);
fprintf('Sync period is %d\n', sync_period);
fprintf('Number of data blocks is %d\n', sync_period_blocks);

% Check the map readback, which should reflect the input, read one
% cycle after it is written
readback_map = out.chan_map.Data(n_out_chans + 2 : 2 * n_out_chans + 1);
if all(readback_map == chan_in_id.Data(1 : n_out_chans))
    disp('Map readback OK')
else
    error('Map readback failed')
end

% Find the output where sync went high and start checking data from here
sync_index = find(out.sync_out.Data == 1, 1);
fprintf('sync found at: %d\n', sync_index);

% Build combined output streams starting after sync
dout = zeros(n_parallel_out_chans*max(size(out.dout0.Data(sync_index+1:end))),1);
dout(1 : 2 : end) = out.dout0.Data(sync_index+1:end);
dout(2 : 2 : end) = out.dout1.Data(sync_index+1:end);

% Cycle through blocks of output spectra checking data.
% The simulated data has value=channel_number, where channel numbers
% keep counting up until after a sync. I.e., after a sync, the first
% n_input_channels take values [0 : n_input_channels - 1] and the second
% n_input_channels take values [n_input_channels : 2 * n_input_channels -1]
for i = [0 : 2 * sync_period_blocks]
    expected_data = readback_map + n_input_channels * mod(i, sync_period_blocks);
    observed_data = dout(i * n_out_chans + 1 : (i+1) * n_out_chans);
    if all(observed_data == expected_data)
        continue
    else
        i
        disp('Observed data:')
        observed_data(1:20)
        disp('Expected data:')
        expected_data(1:20)
        error('Data readback failed')
    end
end
disp('Channel Selection Data Check OK');
disp('********************');
disp('* Testbench PASSED *');
disp('********************');

% close simulink model if it wasn't open already
if close_slx_when_done == 1
    close_system(model_name, 0) % close without saving
end
