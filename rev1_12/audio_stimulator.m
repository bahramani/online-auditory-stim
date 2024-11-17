% In the name of Allah

classdef audio_stimulator < audio_stim_ui
    properties
        rev = 1.11

        songs_folder
        sessions_folder

        step_interval
        
        operation_mode
        
        scope
        mic_device
        audio_writer
        audio_fs
        recorded_samples

        stim_sil_interval
        stim_duration
        stim_id

        trig_index = 0
        event_list = []
        
        my_event_detector
        cont_data_fs

        % raster plotter
%         plotter
        spike_ch
        event_ch
        counter

        % internal
        run_flag
        trial_event_fid
        trial_neuron_fid
        stim_timer = uint64(0);
        stim_flag = false;
        prevent_from_play = false;
        songs_info_txt
    end
    methods
        %         Constructor
        function this = audio_stimulator(operation_mode, songs_folder,...
                all_sessions_folder, sp_ch, ev_ch, cont_data_fs)
            this.step_interval = 0.2; % seconds
            
            this.operation_mode = operation_mode;

            this.spike_ch = sp_ch;
            this.event_ch = ev_ch;
            this.stim_id = -1;
            this.stim_sil_interval = this.IntervalsEditField.Value; % seconds
            this.stim_duration = 0;
            this.stim_flag = false;
            this.counter = uint32(0);
            
            this.cont_data_fs = cont_data_fs;
%             this.plotter = birdslab.psth_plotter();
            this.my_event_detector = birdslab.event_detector(this.cont_data_fs,...
                this.event_ch, this.spike_ch, 0.45, @this.stim_detected);
            today_folder = datestr(now, 'yyyy-mm-dd');
            if (~exist(fullfile(all_sessions_folder, today_folder), 'dir'))
                mkdir(fullfile(all_sessions_folder, today_folder));
            end
            this.sessions_folder = fullfile(all_sessions_folder, today_folder);
            this.songs_folder = songs_folder;
            this.populate_songs();


            if strcmp(this.operation_mode, 'neural-stim')
                
            elseif strcmp(this.operation_mode, 'behave-stim')
                this.audio_fs = 48000;
                this.mic_device = audioDeviceReader( ...
                    'SamplesPerFrame', this.step_interval*this.audio_fs,...
                    'SampleRate', this.audio_fs);


                scope = timescope(...
                    'SampleRate', this.audio_fs,...
                    'TimeSpan', 5.5,...
                    'BufferLength', this.step_interval*this.audio_fs, ...
                    'YLimits', [-1, 1], ...
                    'TimeSpanSource', 'property',...
                    'TimeSpanOverrunAction', "Scroll");

                scope.TimeDisplayOffset = 0;

                this.scope = scope;
            end
        end
        
        function play_song(app, node)
            node.NodeData.play(0);
            %node.NodeData.TotalSamples/node.NodeData.SampleRate
        end

        function populate_songs(app)
            app.SessionName.Value = datestr(now, 'hh-MM-ss');
            app.songs_info_txt = [];
%             mkdir(fullfile(app.sessions_folder, app.session_folder));
%             file_name = fullfile(app.sessions_folder, app.session_folder, 'songs_info.txt');
%             fid = fopen(file_name, 'w');
            txt = sprintf('In the name of Allah\n\n');                                   app.songs_info_txt = [app.songs_info_txt, txt];
            txt = sprintf('IPM Birdslab - Audio Stimulator - rev%2.1f\n', app.rev);      app.songs_info_txt = [app.songs_info_txt, txt];
            txt = sprintf('PWD: %s\n', pwd);                                             app.songs_info_txt = [app.songs_info_txt, txt];
            txt = sprintf('Current Session: %s\n', '*1*2*3*e*d*c');                      app.songs_info_txt = [app.songs_info_txt, txt];
            txt = sprintf('Songs Folder: %s\n', app.songs_folder);                       app.songs_info_txt = [app.songs_info_txt, txt];
            txt = sprintf('Session Starts: %s\n', '*1*2*3*e*d*d');                                 app.songs_info_txt = [app.songs_info_txt, txt];
            files = dir([app.songs_folder, '*.*']);
            nodes = [];
            cntr = 0;
            for i = 1:length(files)                
                if (~files(i).isdir)
                    cntr = cntr + 1;
                    temp_node = uitreenode(app.Files);
                    temp_node.Text = sprintf('%s (id = %d)', files(i).name, cntr);
                    temp_node.NodeData = birdslab.audio_event(cntr, [app.songs_folder, files(i).name], app.cont_data_fs);
%                     temp_node.NodeData = audioplayer(y*3, fs); %#ok<TNMLP>
%                     temp_node.UserData = cntr;
                    nodes = [nodes, temp_node]; %#ok<AGROW>
                    txt = sprintf('%d, %s, %3.1f s\n', cntr,...
                        files(i).name, temp_node.NodeData.duration);
                    app.songs_info_txt = [app.songs_info_txt, txt];
                end                
            end
%             app.Files.CheckedNodes = nodes;            
        end

        function stop_and_close(app)
            app.run_flag = false;
        end
        
        function update_selected_events(app)
            res = cell(length(app.Files.CheckedNodes), 1);
            for i = 1:length(app.Files.CheckedNodes)
                res{i} = app.Files.CheckedNodes(i).NodeData.to_string(); 
            end
            app.SelectedEventsListBox.Items = res;
            app.Played0outof0Label.Text = sprintf('Played %d out of %d',...
                app.trig_index, length(app.event_list));
        end
        
        function stim_detected(app, ev_id, time_in_samples, log)
%             app.plotter.add_event(ev_id,...
%                 time_in_samples/app.cont_data_fs*1000); % times are in ms
%             fprintf('id=%d, time=%2.3fs\n', ev_id, time_in_samples/app.cont_data_fs);
            fprintf(app.trial_event_fid, '%s, %6.3f, %d\n', log,...
                    time_in_samples/app.cont_data_fs, ev_id);
        end

        function start_stim(app)
            if (exist(fullfile(app.sessions_folder, app.SessionName.Value), 'dir'))
                choice = questdlg('Session exists. Do you want to continue?', ...
                    'Warning', ...
                    'Yes', 'No', 'No');
                switch choice
                    case 'No'
                        return;
                end
            else
                mkdir(fullfile(app.sessions_folder, app.SessionName.Value));
            end
            if (isempty(app.Files.CheckedNodes))
                msgbox("At least one stimulation must be selected", "No stim");
                return;
            end

            % strim starts here
            ids = zeros(1, length(app.Files.CheckedNodes));
            for i = 1:length(ids)
                ids(i) = app.Files.CheckedNodes(i).NodeData.id;
            end
%             app.plotter.available_events = ids;
            dstr = datestr(now, 'hh-MM-ss');
            app.songs_info_txt = strrep(app.songs_info_txt, '*1*2*3*e*d*d', dstr);
            app.ofeachEditField.Enable = 'off';
            app.StartStimButton.Enable = 'off';
            app.CloseButton.Enable = 'off';
            app.StopStimButton.Enable = 'on';
            app.SessionName.Enable = 'off';
            res = [];
            for i = 1:length(app.Files.CheckedNodes)
                res = [res, repmat(app.Files.CheckedNodes(i).NodeData.id, [1, app.ofeachEditField.Value])]; %#ok<AGROW> 
            end
            ind = randperm(length(res));
            res = res(ind);
            app.event_list = res;
            app.update_selected_events();
%             dstr = datestr(now, 'hh-MM-ss');
            file_name = fullfile(app.sessions_folder, app.SessionName.Value,...
                'trial-events.txt');
            app.trial_event_fid = fopen(file_name, 'w');
            file_name = fullfile(app.sessions_folder, app.SessionName.Value,...
                'trial-neurons.txt');
            app.trial_neuron_fid = fopen(file_name, 'w');
            
            fprintf(app.trial_neuron_fid, 'our ts (seconds), neuron id (0 unsorted, 1 1st neuron, ...)\n');

            if strcmp(app.operation_mode, 'neural-stim')
                fprintf(app.trial_event_fid, 'pc timestamp (RTC), blrck ts (seconds), our ts (seconds), song id\n');
            elseif strcmp(app.operation_mode, 'behave-stim')
                fprintf(app.trial_event_fid, 'pc timestamp (RTC), wavfile(samples), song id\n');

                audio_filename = fullfile(app.sessions_folder, app.SessionName.Value,...
                    'rec.wav');
                app.audio_writer = dsp.AudioFileWriter(audio_filename,...
                    'SampleRate', app.audio_fs, 'FileFormat', 'WAV');
                app.recorded_samples = 0;
            end
            
            

            einfo = struct();
            einfo.fs = app.cont_data_fs;
            for i = 1:length(app.Files.CheckedNodes)
                einfo.events(i) = app.Files.CheckedNodes(i).NodeData;
            end
            file_name = fullfile(app.sessions_folder, app.SessionName.Value,...
                'events-info.mat');
            save(file_name, 'einfo');

%             file_name = fullfile(app.sessions_folder, app.SessionName.Value,...
%                 'events-info.txt');
% 
%             res = [];
%             for i = 1:length(app.Files.CheckedNodes)
%                 res = [res, app.Files.CheckedNodes(i).NodeData.id]; %#ok<AGROW> 
%             end
% 
%             temp_fid = fopen(file_name, 'w');
%             fprintf(temp_fid, '%d,', res);
%             for i = 1:length(app.Files.CheckedNodes)
%                 fprintf(temp_fid, '%s,\n', files(i).name);
%             end
%             fclose(temp_fid);

            app.Status.Text = 'Started';
            app.Files.Enable = false;
            app.trig_index = 1;
            app.stim_flag = true;
        end

        function stop_stim(app)
            if app.stim_flag
                app.my_event_detector.ready_to_detect = false;
                fclose(app.trial_event_fid);
                fclose(app.trial_neuron_fid);
            end
            app.StopStimButton.Enable = 'off';
            app.CloseButton.Enable = 'on';
            app.Status.Text = 'Stopped';
            app.stim_flag = false;
            app.stim_timer = uint64(0);
            app.Files.Enable = true;

%             file_name = fullfile(app.sessions_folder, app.SessionName.Value,...
%                 ['trial-events-', dstr,  '.txt']);
            file_name = fullfile(app.sessions_folder, app.SessionName.Value, 'songs_info.txt');
            fid = fopen(file_name, 'w');
            app.songs_info_txt = strrep(app.songs_info_txt, '*1*2*3*e*d*c', app.SessionName.Value);
            dstr = datestr(now, 'hh-MM-ss');
            txt = sprintf('Session Ends: %s\n', dstr); app.songs_info_txt = [app.songs_info_txt, txt];
            fprintf(fid, '%s', app.songs_info_txt);
            fclose(fid);
        end
        
        function stim_trigg(app)
            if (app.stim_flag)
                if (toc(app.stim_timer) > (app.stim_sil_interval + app.stim_duration))
%                     song_to_play_id = randi(length(app.Files.CheckedNodes));
                    if (app.trig_index > length(app.event_list))                        
                        app.stop_stim();
                        return;
                    end
                    song_to_play_id = app.event_list(app.trig_index);
                    ae = app.Files.Children(song_to_play_id).NodeData;
                    app.stim_duration = ae.duration;
                    app.stim_id = ae.id;
                    if (app.FixedButton.Value)
                        app.stim_sil_interval = app.IntervalsEditField.Value;
                    elseif (app.UniformRandButton.Value)
                        a = app.FromsEditField.Value;
                        b = app.TosEditField.Value;
                        app.stim_sil_interval = rand*(b-a) + a;
                    end                    
                    
                    
                    ae.play(1);
                    if strcmp(app.operation_mode, 'neural-stim')
                        et = cbmex('time');
                        pending_log = sprintf('%s, %6.3f', datestr(now, 'hh-MM-ss.FFF'), et);
                        app.my_event_detector.set_last_event(ae, pending_log);
                    elseif strcmp(app.operation_mode, 'behave-stim')
                        rtc_now = datestr(now, 'HH:MM:SS.FFF');
                        fprintf(app.trial_event_fid, '%s, %d, %d\n', rtc_now, app.recorded_samples, ae.id);                        
                    end
                    
                    
                    app.update_selected_events();                    
%                     fprintf(app.trial_event_fid, '%s, %6.3f, %d\n', datestr(now, 'hh-MM-ss.FFF'), et, app.stim_id);
                    app.trig_index = app.trig_index + 1;
                    
% % %                     app.plotter.add_event(app.stim_id, et*1000); % times are in ms
                    app.stim_timer = tic;                    
                elseif (toc(app.stim_timer) > app.stim_duration)
                    app.Status.Text = 'Silence Interval';
                else
                    app.Status.Text = ['Playing id=', num2str(app.stim_id)];
                end
            end
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

        function start(app)
            fprintf('Start Main Loop - Use Close Button to Stop App.\n');
            app.run_flag = true;
            
            if strcmp(app.operation_mode, 'neural-stim')
                cbmex('trialdata', 1); % free buffer
                while app.run_flag
                    pause(app.step_interval);
                    [event_data, time, cont_data] = cbmex('trialdata', 1);
                    app.handle_black_rock_data(event_data, time, cont_data);
                    app.stim_trigg();
                end
            elseif strcmp(app.operation_mode, 'behave-stim')
                while app.run_flag
                    samples = app.mic_device();
                    samples = samples(:, 1);
                    app.scope.step(samples);
                    if app.stim_flag
                        app.audio_writer(samples);
                        app.recorded_samples = app.recorded_samples +...
                            length(samples);
                        app.stim_trigg();
                    end
                    pause(app.step_interval/2);
                end
                release(app.mic_device);
                release(app.audio_writer);
            end
            
%             close(app.AudioStimulatorUIFigure);
                delete(app.AudioStimulatorUIFigure);
            try
                
            catch ex
                disp(ex);
            end
        end
    end
end