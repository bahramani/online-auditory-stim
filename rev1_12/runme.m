% In the name of Allah

close all;

songs_folder = '..\ZF008AM_neural_stim\';
trials_folder = '..\sessions\';
spikes_channel = 6; % headstage channel
audio_channel = 23; % 23 means ainp7
cont_data_fs = 30000;
% operation_mode = 'behave-stim';
operation_mode = 'neural-stim';

if strcmp(operation_mode, 'neural-stim')
    birdslab.config_black_rock();
end

au_stim = audio_stimulator(operation_mode, songs_folder, trials_folder, spikes_channel, audio_channel, cont_data_fs);
au_stim.start();

if strcmp(operation_mode, 'neural-stim')
    cbmex('close');
end
% release(au_stim.mic_device);
