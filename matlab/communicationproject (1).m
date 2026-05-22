% =========================================================================
% Digital Half-Duplex Voice Communication System Utilizing GFSK Modulation
% (UPDATED WITH POST-DETECTION FILTERING FOR NOISE ROBUSTNESS)
% =========================================================================
clear; clc; close all;

%% 1. SIMULATION PARAMETERS & SETUP
fs_audio = 8000;         % Baseband audio sampling frequency (Hz)
n_bits = 8;              % ADC/DAC resolution (bits per sample)
Rb = fs_audio * n_bits;  % Bit rate (64,000 bps)

fs_rf = 640000;          % RF sampling frequency (Hz) - 10x oversampling
sps = fs_rf / Rb;        % Samples per bit (10)
fc = 100000;             % Carrier frequency (100 kHz, scaled for visibility)
freq_dev = 16000;        % GFSK Frequency deviation (16 kHz)

t_end = 0.02;            % Simulate 20 milliseconds of data
t_audio = 0 : 1/fs_audio : t_end - 1/fs_audio; 
N_audio = length(t_audio);

%% ==================== TRANSMITTER NODE ====================

% 1. Baseband Signal Generation (Human Voice Envelope Mockup)
audio_in = 1e-3 * (sin(2*pi*300*t_audio) + 0.5*sin(2*pi*1000*t_audio)); 

% 2. Pre-Amplification (Scale to 0 - 5V range)
min_sig = min(audio_in);
max_sig = max(audio_in);
audio_amp = 5 * (audio_in - min_sig) / (max_sig - min_sig);

% 3. ADC (Sampling & Quantization)
levels = 2^n_bits;
audio_quant = round((levels - 1) * audio_amp / 5); % 0 to 255 discrete levels

% Convert quantized decimal levels to a serial binary stream
bin_char = dec2bin(audio_quant, n_bits); 
bin_stream = (bin_char' - '0');       
bin_stream = bin_stream(:)';          

% 4. GFSK Modulation
% Convert bits (0, 1) to NRZ (-1, 1) and upsample
nrz_stream = 2 * bin_stream - 1;
nrz_up = upsample(nrz_stream, sps);

% Gaussian Low-Pass Filter for Pulse Shaping
BT = 0.5;                             
alpha = sqrt(log(2)/2) / (BT * Rb);
t_g = -2/Rb : 1/fs_rf : 2/Rb;         
h_gauss = (sqrt(pi)/alpha) * exp(-(pi^2/alpha^2) * t_g.^2);
h_gauss = h_gauss / sum(h_gauss);     

% Shape pulses
pulse_shaped = conv(nrz_up, h_gauss, 'same');

% Frequency Modulation (FM) Integration
phase = 2*pi * freq_dev / fs_rf * cumsum(pulse_shaped);
t_rf = (0 : length(phase)-1) / fs_rf;
tx_rf_sig = cos(2*pi*fc*t_rf + phase);

%% ==================== WIRELESS CHANNEL ====================

% 5. Additive White Gaussian Noise (AWGN) Simulation
% Bumped SNR to 20dB to demonstrate a realistic, functioning channel
snr_db = 20;                                
snr_lin = 10^(snr_db/10);
sig_power = mean(tx_rf_sig.^2);
noise_power = sig_power / snr_lin;
noise = sqrt(noise_power) * randn(size(tx_rf_sig));

rx_rf_sig = tx_rf_sig + noise;              

%% ==================== RECEIVER NODE =======================

% 6. GFSK Demodulation (I/Q Downconversion)
i_rx = rx_rf_sig .* cos(2*pi*fc*t_rf);
q_rx = -rx_rf_sig .* sin(2*pi*fc*t_rf);

% --- FIX 1: TIGHTENED PRE-DETECTION FILTER ---
% Lowered cutoff from 1.5*Rb to 1.2*Rb to reject more noise before demodulation
[b_rf, a_rf] = butter(4, 1.2*Rb/(fs_rf/2)); 
i_flt = filtfilt(b_rf, a_rf, i_rx);
q_flt = filtfilt(b_rf, a_rf, q_rx);

% Extract instantaneous frequency
di_dt = diff(i_flt) * fs_rf; di_dt = [di_dt, di_dt(end)]; 
dq_dt = diff(q_flt) * fs_rf; dq_dt = [dq_dt, dq_dt(end)];
inst_freq_rad = (i_flt .* dq_dt - q_flt .* di_dt) ./ (i_flt.^2 + q_flt.^2 + 1e-10);
inst_freq_hz = inst_freq_rad / (2*pi);

% --- FIX 2: NEW POST-DETECTION FILTER ---
% Smooths out the massive noise spikes caused by the derivative calculation
[b_post, a_post] = butter(4, Rb/(fs_rf/2));
inst_freq_filtered = filtfilt(b_post, a_post, inst_freq_hz);

% Thresholding Decision Mechanism (Now using the FILTERED signal)
sample_indices = round(sps/2) : sps : length(inst_freq_filtered);
rx_samples = inst_freq_filtered(sample_indices);
rx_bits = rx_samples > 0;             

% 7. DAC Synthesis
num_valid_samples = floor(length(rx_bits) / n_bits);
rx_bits_trunc = rx_bits(1 : num_valid_samples * n_bits);

rx_matrix = reshape(rx_bits_trunc, n_bits, [])';
rx_dec = sum(rx_matrix .* (2.^(n_bits-1 : -1 : 0)), 2)';
rx_voltage = rx_dec * 5 / (levels - 1);

% 8. RC Low Pass Filtering & Power Amplification
[b_aud, a_aud] = butter(4, 2000/(fs_audio/2));
rx_audio_flt = filtfilt(b_aud, a_aud, rx_voltage);

rx_audio_ac = rx_audio_flt - mean(rx_audio_flt);
power_amp_gain = max(audio_in) / max(rx_audio_ac);
rx_final = rx_audio_ac * power_amp_gain;


%% ==================== OUTPUT PLOTTING =====================

figure('Name', 'GFSK Transceiver Workflow Simulation', 'Position', [100, 50, 1200, 900]);

lim_aud = [0, 0.01];   
lim_rf  = [0, 0.0015]; 

subplot(4,2,1);
plot(t_audio, audio_in * 1000, 'b', 'LineWidth', 1.5);
title('1. Original Analog Audio Input');
xlabel('Time (s)'); ylabel('Amplitude (mV)'); xlim(lim_aud); grid on;

subplot(4,2,2);
stairs(t_audio, audio_quant, 'm', 'LineWidth', 1.2);
title('2. Quantized Signal (ADC Output)');
xlabel('Time (s)'); ylabel('Discrete Level (0-255)'); xlim(lim_aud); grid on;

subplot(4,2,3);
plot(t_rf, pulse_shaped, 'k', 'LineWidth', 1.2);
title('3. Gaussian Shaped Baseband Pulses');
xlabel('Time (s)'); ylabel('Amplitude'); xlim(lim_rf); grid on;

subplot(4,2,4);
plot(t_rf, tx_rf_sig, 'r');
title('4. GFSK Modulated RF Signal');
xlabel('Time (s)'); ylabel('Amplitude'); xlim(lim_rf); grid on;

subplot(4,2,5);
plot(t_rf, rx_rf_sig, 'Color', [0.5 0.5 0.5]);
title(['5. Received Signal with AWGN (SNR = ', num2str(snr_db), 'dB)']);
xlabel('Time (s)'); ylabel('Amplitude'); xlim(lim_rf); grid on;

subplot(4,2,6);
% Plot the noisy signal in light grey, and the newly filtered signal in blue over it
plot(t_rf, inst_freq_hz, 'Color', [0.8 0.8 0.8]); hold on;
plot(t_rf, inst_freq_filtered, 'b', 'LineWidth', 1.5); 
yline(0, 'r--', 'Threshold', 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');
title('6. Post-Detection Filtered Baseband (Inst. Freq)');
xlabel('Time (s)'); ylabel('Freq Deviation (Hz)'); xlim(lim_rf); ylim([-freq_dev*1.5 freq_dev*1.5]); grid on;
legend('Noisy Demod', 'Filtered Demod');

subplot(4,2,7);
t_dac = t_audio(1:length(rx_voltage));
stairs(t_dac, rx_voltage, 'm', 'LineWidth', 1.2);
title('7. DAC Output (Discrete Voltage Levels)');
xlabel('Time (s)'); ylabel('Voltage (V)'); xlim(lim_aud); grid on;

subplot(4,2,8);
plot(t_audio, audio_in * 1000, 'k--', 'LineWidth', 1.5); hold on;
plot(t_dac, rx_final * 1000, 'b', 'LineWidth', 1.5);
title('8. Final Recovered & Filtered Audio vs. Original');
legend('Original Input', 'Recovered Output', 'Location', 'Best');
xlabel('Time (s)'); ylabel('Amplitude (mV)'); xlim(lim_aud); grid on;

sgtitle('Digital Half-Duplex Voice Comm System Utilizing GFSK Modulation', 'FontSize', 16, 'FontWeight', 'bold');