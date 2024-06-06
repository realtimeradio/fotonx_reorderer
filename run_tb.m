SIM_LEN = 30000; % Simulation length, in clock cycles
RNG_SEED = 12345; % Random number generator seed
N_OUT_CHANS = 1024; % Number of output channels after downselect

% Input vector initialization
t = [0:SIM_LEN-1];
chan_in_id2k = timeseries(zeros(SIM_LEN, 1), t);
chan_in_id4k = timeseries(zeros(SIM_LEN, 1), t);
chan_out_id = timeseries(zeros(SIM_LEN, 1), t);
map_we = timeseries(zeros(SIM_LEN, 1), t);

% Create a random map

rng(RNG_SEED);
r4k = randi([0, 4096], N_OUT_CHANS, 1); % random numbers for 4k input channels.
r2k = randi([0, 2048], N_OUT_CHANS, 1); % random numbers for 4k input channels.

chan_in_id2k.Data(1:N_OUT_CHANS) = r2k;
chan_in_id4k.Data(1:N_OUT_CHANS) = r4k;
chan_out_id.Data(1:N_OUT_CHANS) = [0:N_OUT_CHANS-1];
map_we.Data(1:N_OUT_CHANS) = 1;
chan_out_id.Data(N_OUT_CHANS+1 : 2*N_OUT_CHANS) = [0:N_OUT_CHANS-1]; % for readback


%save('chan_in_id2k.mat', 'chan_in_id2k', '-v7.3');
%save('chan_in_id4k.mat', 'chan_in_id4k', '-v7.3');
%save('chan_out_id.mat', 'chan_out_id', '-v7.3');
%save('map_we.mat', 'map_we', '-v7.3');

model = 'reorderer4x';

set_param(model, 'StopTime', num2str(SIM_LEN));
clear('out');
out = sim(model);

% Get sync period -- this is the periodicity with which simulated data
% resets
sync_gen = [bdroot '/sync_gen'];
sync_period_str = get_param(sync_gen, 'AttributesFormatString');
sync_period = sscanf(sync_period_str, 'sim_sync_period=%d ')
sync_period_blocks = sync_period / (N_OUT_CHANS/2)

% Check the map readback, which should reflect the input, read one
% cycle after it is written
readback_map = out.chan_map.Data(N_OUT_CHANS+2 : 2*N_OUT_CHANS+1);
if all(readback_map == chan_in_id2k.Data(1:N_OUT_CHANS))
    disp('Map readback OK')
else
    error('Map readback failed')
end

% Find the output where sync went high and start checking data from here
sync_index = find(out.sync_out.Data == 1, 1);
disp('sync found at:');
disp(sync_index);

% Build combined output streams starting after sync
dout = zeros(2*max(size(out.dout0.Data(sync_index+1:end))),1);
dout(1:2:end) = out.dout0.Data(sync_index+1:end);
dout(2:2:end) = out.dout1.Data(sync_index+1:end);

for i = [0:2*sync_period_blocks]
    expected_data = readback_map + 2048 * mod(i, sync_period_blocks);
    observed_data = dout(i * N_OUT_CHANS + 1 : (i+1) * N_OUT_CHANS);
    if all(observed_data == expected_data)
        disp('Data readback OK')
    else
        i
        disp('Observed data:')
        observed_data(1:20)
        disp('Expected data:')
        expected_data(1:20)
        error('Data readback failed')
    end
end
