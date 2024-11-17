classdef bare_stimulator < handle
    properties
        step_interval
        spike_ch
        event_ch
        cont_data_fs
        
        session_folder

        my_event_detector

        main_loop_flag = false;

        audio_file_reader
        audio_player
    end
    
    methods
        function this = bare_stimulator(cfg)
            this.step_interval = 0.01;
            this.spike_ch = cfg.spikes_channel;
            this.event_ch = cfg.audio_channel;
            
%             this.stim_flag = false;
%             this.counter = uint32(0);
            
            this.cont_data_fs = cfg.cont_data_fs;
            all_sessions_folder = cfg.sessions_folder;

            this.my_event_detector = birdslab.event_detector(this.cont_data_fs,...
                this.event_ch, this.spike_ch, 0.45, @this.stim_detected);

            today_folder = datestr(now, 'yyyy-mm-dd');
            if (~exist(fullfile(all_sessions_folder, today_folder), 'dir'))
                mkdir(fullfile(all_sessions_folder, today_folder));
            end
            this.session_folder = fullfile(all_sessions_folder, today_folder);

            [this.audio_file_reader, this.audio_player] =...
                init_reader_player(this, cfg.cont_stims_folder,...
                cfg.cont_stim_id);
        end
        
        function read_events(this)
            
        end

        function [afr, ap] = init_reader_player(this, fldr, file_id)            
            source_file = fullfile(fldr, file_id, [file_id, '.wav']);
            fileInfo = audioinfo(source_file);
%             fs_ = 48000; % TODO: must find beforehand
            frame_size = ceil(this.step_interval*fileInfo.SampleRate);
            afr = dsp.AudioFileReader(source_file, 'ReadRange', [1, inf],...
                'SamplesPerFrame', frame_size);

            ap = audioDeviceWriter('SampleRate', fileInfo.SampleRate);            
        end

        function stim_detected(this, ev_id, time_in_samples, log)
            fprintf(this.trial_event_fid, '%s, %6.3f, %d\n', log,...
                    time_in_samples/app.cont_data_fs, ev_id);
        end
        

        function handle_black_rock_data(app, event_data, time, cont_data)
            all_spikes = event_data(app.spike_ch, :);
            max_spikes = app.step_interval*1000*100;
            spike_matrix = zeros(max_spikes, 2); %this.step_interval
%             app.my_event_detector.step(cont_data, time);
            cntr = 0;
            for i = 2:size(all_spikes, 2)
                specific_neuron_spikes = all_spikes{i};
                if (~isempty(specific_neuron_spikes))
                    for j = 1:length(specific_neuron_spikes)
%                         app.plotter.add_spike(i - 1, ... % id 1 means not identified neuron
%                             (double(specific_neuron_spikes(j) + app.counter))/app.cont_data_fs*1000.0); % times are in milliseconds

                        cntr = cntr + 1;
                        spike_matrix(cntr, 1) =...
                            (double(specific_neuron_spikes(j) + app.counter))/app.cont_data_fs;
                        spike_matrix(cntr, 2) = i - 2; % id zero mean not sorted neuron
                    end
                end
            end
            app.counter = app.my_event_detector.step(cont_data, app.counter);
            if (app.stim_flag)
                if (cntr > 0)
                    spike_matrix = spike_matrix(1:cntr, :);
                    spike_matrix = sort(spike_matrix, 1);
                    fprintf(app.trial_neuron_fid, '%9.5f, %d\n', spike_matrix');
                end
            end
        end

        function main_loop(this)
            totalUnderrun = 0;
            totalPlayed = 0;
            while this.main_loop_flag && ~isDone(this.audio_file_reader)
%                 [event_data, time, cont_data] = cbmex('trialdata', 1);
%                     this.handle_black_rock_data(event_data, time, cont_data);
                samples = this.audio_file_reader();
%                 tic;
                numUnderrun = this.audio_player(samples);
                totalPlayed = totalPlayed + length(samples);
%                 t = toc;
%                 fprintf('seconds: %3.1f\n', t);

                totalUnderrun = totalUnderrun + numUnderrun;
                if numUnderrun > 0
                    fprintf('underrun samples %d @ %d (%4.1fs)\n',...
                        numUnderrun, totalPlayed,...
                        totalPlayed/this.audio_player.SampleRate);
                end
            end
            this.closing();
        end

        function start(this)
            cleanupObj = onCleanup(@this.closing);
%             birdslab.config_black_rock();
%             cbmex('trialdata', 1); % free buffer
            this.main_loop_flag = true;
            this.main_loop();
        end

        function closing(this)
            fprintf('closing ...\n');
            this.main_loop_flag = false;
%             cbmex('close');
            release(this.audio_file_reader);
            release(this.audio_player);



%             % saves data to file (or could save to workspace)
%             fprintf('saving variables to file...\n');
%             filename = [datestr(now,'yyyy-mm-dd_HHMMSS') '.mat'];
%             save(filename,'I','Z','U');
            fprintf('done.\n');
        end
    end
end

