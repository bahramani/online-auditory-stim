% In the name of Allah

cfg = struct();
cfg.cont_stims_folder = '..\sessions\resources\continuous_stims\';
cfg.cont_stim_id = 'ZF008AM_neural_stim_01';
cfg.sessions_folder = '..\sessions\';

cfg.spikes_channel = 6; % headstage channel
cfg.audio_channel = 23; % 23 means 7
cfg.cont_data_fs = 30000;

bare_stim = birdslab.bare_stimulator(cfg);
bare_stim.start();

