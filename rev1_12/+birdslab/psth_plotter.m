classdef psth_plotter < handle
    %PSTH_PLOTTER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        img_hndle;

        ax;

        fig_hndle_psth;
        axs_hndle_psth;

        fig_hndle_raster;
        axs_hndle_raster;

        is_enable;
        
        redis_client;
        events_key;
        fs;

        recent_spike_count = 5000; % TODO
        spikes_history; % 3 by M matrix - where M is #spikes
                        % M is equal to recent_spike_count
                        % 1st column is redis time stamp
                        % 2nd column is spike id
                        % 3rd neuron id (in this version is always 0)
        spikes_ts
        spike_insertion_pointer = 1;

        
        fetch_events_from;
        recent_event_count = 100; % TODO        
%         events_history

%         event_timer = uint64(0);
%         event_fetch_interval = 1.2; % seconds
        new_event_interval = 2;
        nof_new_events = 0;
        time_zero_ind;
        available_events
        available_neurons = 5 + 1
        event_map;
        raster_data; % M by T by avail_neurons tensor - where M is #event - T is # timebins
        events_time_id; % M by 2 matrix - where M is number of events
        raster_T;
%         last_processed_rds;
        % M is equal to recent_event_count
        time_before_event = 500; % ms
        time_after_event = 2500; % ms
        bin_timespan = 1; % ms
        raster_x_scale = 1;
        raster_y_scale = 5;
        bin_edges;

        color_map;
    end
    
    methods
        function this = psth_plotter()            
            this.is_enable = true;
            this.spikes_history = zeros(2, this.recent_spike_count, 'single');
            
            this.bin_edges = (-this.time_before_event):this.bin_timespan:this.time_after_event;
            this.raster_T = length(this.bin_edges) - 1;
            this.raster_data = zeros(this.recent_event_count, ...
                this.raster_T, this.available_neurons, 'logical');
            this.events_time_id = zeros(this.recent_event_count, 2);

            [~, this.time_zero_ind] = min(abs(this.bin_edges - 0));

           this.Open();
        end

        function add_spike(this, neuron_id, timestamp)
            if (this.is_enable)
                this.spikes_history = circshift(this.spikes_history, [0, -1]);
                this.spikes_history(1, end) = timestamp;                
                this.spikes_history(2, end) = neuron_id;
            end
        end

        function update_trigger(this)
%             if (toc(this.event_timer) > this.event_fetch_interval)
%                 this.event_timer = tic;
            if (this.nof_new_events >= this.new_event_interval)
                this.nof_new_events = 0;
                % updating this.raster_data
                for i = 0:(this.new_event_interval - 1)
                    if (this.events_time_id(end-i, 2) > 0)
                        this.raster_data(end-i, :, :) = 0; % remove all spikes
                        event_ts = this.events_time_id(end-i, 1);
                        ind1 = this.spikes_history(1, :) < event_ts + this.time_after_event;
                        ind2 = this.spikes_history(1, :) > event_ts - this.time_before_event;
                        ind = ind1 & ind2;
            
                        event_related_spikes = this.spikes_history(1, ind);
                        event_related_spikes = event_related_spikes - event_ts;
            
                        neuron_ids = this.spikes_history(2, ind);
                        neuron_groups = unique(neuron_ids);
                        for n = neuron_groups
                            ind_ng = neuron_ids == n;
            
                            spike_counts = histcounts(event_related_spikes(ind_ng),...
                                this.bin_edges);
                            ind_founded_spikes = spike_counts > 0;
                            this.raster_data(end-i, ind_founded_spikes, n) = 1;
                        end
                    end                    
                end
                this.update_plots();
            end
        end
        
        function add_event(this, event_id, time_stamp)
            if (this.is_enable)
                this.events_time_id = circshift(this.events_time_id, [-1, 0]);
                this.events_time_id(end, 1) = time_stamp;
                this.events_time_id(end, 2) = event_id; % simple event id

                
            end
        end

        function add_event_old(this, event_id, time_stamp)
            if (this.is_enable)
                this.nof_new_events = this.nof_new_events + 1;
                this.raster_data = circshift(this.raster_data, [-1, 0]);
                this.events_time_id = circshift(this.events_time_id, [-1, 0]);
                this.events_time_id(end, 1) = time_stamp;
                this.events_time_id(end, 2) = event_id; % simple event id
%                 this.raster_data(end, 2) = find(this.available_events == event_id);
                this.raster_data(end, :, :) = 0;
                this.update_trigger();
            end            
        end

        function update_plots(this)
            tVec = -this.time_before_event:1:this.time_after_event-1;
        
            % add a for loop for each eventID

            % Update Raster Plot
            subplot(this.ax(1))
            title('Raster Plot')
            xlabel('Time [ms]')
            ylabel('Trial #')
            xline(0, '-','Onset', 'Color', '#A2142F', 'LineWidth',2)
            hold on
            xlim([-this.time_before_event this.time_after_event])
            ylim([70 100])
            for i = 2:6 %num units
                for j = 1:this.recent_event_count                 
                    plot([tVec(this.raster_data(j,:,i)~=0)-0.5;tVec(this.raster_data(j,:,i)~=0)+0.5], ...
                        [(this.raster_data(j,this.raster_data(j,:,i)~=0,i)*j)-0.5;(this.raster_data(j,this.raster_data(j,:,i)~=0,i)*j)+0.5], ...
                        'Color', this.color_map(i+1,:))
                end
            end

            % Update PSTH Plot
            % add cla
            subplot(this.ax(3))
            title('Peri-Stimulus Time Histogram')
            xlabel('Time [ms]')
            ylabel('Firing rate [Hz]')
            xline(0, '-','Onset', 'Color', '#A2142F', 'LineWidth',2)
            hold on
            xlim([-this.time_before_event this.time_after_event])
            ylim([0 50])
            for i = 2:6 %num units                
                tmpPSTH = movmean(mean(this.raster_data(:,:,i), 1)*30000, 100); % not correct
                plot(tVec, tmpPSTH, 'Color', this.color_map(i+1,:), 'LineWidth', 1.5)
            end
            grid minor %todo








%             % Update Raster Plot
%             xline(this.axs_hndle_raster, 0, '-','Onset', 'Color', '#A2142F', 'LineWidth',2)
%             hold(this.axs_hndle_raster, 'on');
%             xlim(this.axs_hndle_raster,[-this.time_before_event this.time_after_event])
%             ylim(this.axs_hndle_raster,[70 100])
%             for i = 2:6 %num units
%                 for j = 1:this.recent_event_count                 
%                     plot(this.axs_hndle_raster, ...
%                         [tVec(this.raster_data(j,:,i)~=0)-0.5;tVec(this.raster_data(j,:,i)~=0)+0.5], ...
%                         [(this.raster_data(j,this.raster_data(j,:,i)~=0,i)*j)-0.5;(this.raster_data(j,this.raster_data(j,:,i)~=0,i)*j)+0.5], ...
%                         'Color', this.color_map(i+1,:))
%                 end
%             end
% 
%             % Update PSTH Plot
%             cla(this.axs_hndle_psth);
%             xline(this.axs_hndle_psth, 0, '-','Onset', 'Color', '#A2142F', 'LineWidth',2)
%             hold(this.axs_hndle_psth, 'on');
%             xlim(this.axs_hndle_psth,[-this.time_before_event this.time_after_event])
%             ylim(this.axs_hndle_psth,[0 50])
%             for i = 2:6 %num units                
%                 tmpPSTH = movmean(mean(this.raster_data(:,:,i), 1)*30000, 100);
%                 plot(this.axs_hndle_psth, tVec, tmpPSTH, 'Color', this.color_map(i+1,:), 'LineWidth', 1.5)
%             end

               



%             I = uint8(this.raster_data);
%             I(I(:, :, 1) > 0) = 1;
%             I(I(:, :, 2) > 0) = 2;
%             I(I(:, :, 3) > 0) = 3;
%             I(I(:, :, 4) > 0) = 4;
%             I(I(:, :, 5) > 0) = 5;
%             I(I(:, :, 6) > 0) = 6;
%             I = max(I, [], 3);
%             
% %             I = uint8(sum(uint8(this.raster_data), 3));
%             [m, n] = size(I);
%             I(:, this.time_zero_ind) = 7; % as neuron id 7 - event line
%             I = imresize(I, [m*this.raster_y_scale, n*this.raster_x_scale], 'box');
%             [H, W] = size(I);
%             this.img_hndle = imshow(I, this.color_map, 'XData', 1:W, 'YData', 1:H, 'Parent', this.axs_hndle_rstr);
%             axis(this.axs_hndle_rstr, 'on');
%             xticks(this.axs_hndle_rstr, linspace(1, W, 11));
%             xticklabels(this.axs_hndle_rstr, sprintfc('%d',...
%                 floor(linspace(-this.time_before_event, this.time_after_event, 11))));
%             xlabel(this.axs_hndle_rstr, 'time [ms]');
%             ylabel(this.axs_hndle_rstr, 'Trial');

            % 
%             if (true)
%                 event_colored_image = double(this.raster_data(:, 2) + 7) * ones(1, this.raster_T); % has event id for coloing
% %                 event_colored_image = double(this.raster_data(:, 2) + 7) * ones(1, this.raster_T); % has event id for coloing
%                 I = uint8(event_colored_image);
%                 I(I==7) = 0;
%                 rstr_data = uint8(this.raster_data(:, 3:end));
%                 ind = rstr_data > 0;
%                 I(ind) = rstr_data(ind);
%             else
%                 I = uint8(this.raster_data(:, 3:end));
%             end
% 
% %             I = uint8(this.raster_data(:, 3:end));
% %             I(I==1) = 0;
%             [m, n] = size(I);
% %             
% % 
% % %             ind = I > 0;
% % %             I(ind) = event_colored_image(ind);
%             I(:, this.time_zero_ind) = 7; % as neuron id 7 - event line
%             I = imresize(I, [m*this.raster_y_scale, n*this.raster_x_scale], 'box');
%             [H, W] = size(I);
%             this.img_hndle = imshow(I, this.color_map, 'XData', 1:W, 'YData', 1:H, 'Parent', this.axs_hndle_rstr);
%             axis(this.axs_hndle_rstr, 'on');
%             xticks(this.axs_hndle_rstr, linspace(1, W, 11));
%             xticklabels(this.axs_hndle_rstr, sprintfc('%d',...
%                 floor(linspace(-this.time_before_event, this.time_after_event, 11))));
%             xlabel(this.axs_hndle_rstr, 'time [ms]');
%             ylabel(this.axs_hndle_rstr, 'Trial');
% 
% %          psth plot update
%             cla(this.axs_hndle_psth);
%             xline(this.axs_hndle_psth, 0, 'DisplayName', 'Onset');
%             hold(this.axs_hndle_psth, 'on');
%             for i = 1:length(this.available_events)
%                 event_id = this.available_events(i);
%                 founded = this.raster_data(:, 2) == i;
%                 if (any(founded))
%                     data = double(this.raster_data(founded, 3:end));
%                     data = double(data > 1); % only consider sorted neurons (all sorted neurons together)
%                     psth = movmean(mean(data), 100)/(this.bin_timespan/1000);
%                     if (numel(psth) == (length(this.bin_edges) - 1))
%                         plot(this.axs_hndle_psth,...
%                             this.bin_edges(2:end),...
%                             psth,...
%                             'Color', this.color_map(1+8, :),... % TODO
%                             'DisplayName', ['Event ' num2str(event_id)],...
%                             'LineWidth', 2);
% 
%                     end
%                     
%                     
% 
% %                     hold(this.axs_hndle_psth, 'on');
%                 end
%             end
% %             [] = max(get(this.axs_hndle_psth, 'YLim'));
% 
% %             stem(this.axs_hndle_psth, 0, max(max_mins(:, 1))*1.1, 'r',...
% %                 'Marker', 'none', 'DisplayName', '');
%             
%             xlim(this.axs_hndle_psth, [-this.time_before_event this.time_after_event]);
%             title(this.axs_hndle_psth, 'Peri-Stimulus Time Histogram\newline(only sorted neurons - all sorted neurons together)');
%             xlabel(this.axs_hndle_psth, 'time [ms]');
%             ylabel(this.axs_hndle_psth, 'Firing rate [Hz]');
%             grid(this.axs_hndle_psth,'minor');
% 
%             grid(this.axs_hndle_psth, 'minor');
%             legend(this.axs_hndle_psth, 'show');
%             drawnow limitrate;
        end

%         function set_fetch_events_from(this)
%             [secs, micros] = redis.time(this.redis_client);
%             this.fetch_events_from = [secs,  micros(1:3)];
%         end

        function init_plots(this)
            this.color_map =          [80, 80, 80; % background 0
                                      0, 0, 0; % unclassified neuron 1                                     
                                      255, 96, 208; % pink - first neuron 2
                                      0, 240, 240; % cyan 3
                                      250, 250, 0; % yellow 4
                                      250, 0, 250; % magenta 5
                                      0, 250, 0; % green 6
                                      250, 0, 0; % event line 7
                                      80, 110, 80;  % 1st event type 8
                                      40, 40, 128;  % 2nd event type 9
                                      128, 0, 0;  % 3rd event type 10
                                      100, 118, 135;  % 4th event type 11
                                      255, 255, 255]; % 12


            this.color_map = this.color_map/255;

            %% raster plot
            this.fig_hndle_raster = figure;
            set(this.fig_hndle_raster, 'Name', 'Pesponse Figure', 'WindowState', 'maximized');
            num_events = 2; %todo
            for i = 1:2*num_events % num events
                this.ax(i) = subplot(2,num_events,i);
            end



                                            %    x1,     y1, width,  height
%             set(this.fig_hndle_raster, 'Position', [1050, 1080/2 - 100,   750,    400]);
%             set(this.fig_hndle_raster, 'Name', 'PSTH Plot');
%             set(this.fig_hndle_raster, 'NumberTitle', 'off');
% 
%             this.axs_hndle_raster = gca;
%             xlim([-this.time_before_event this.time_after_event])
%             title('Raster Plot')
%             xlabel('Time [ms]')
%             ylabel('Trial #')     
%             
%             %% psth plot
%             this.fig_hndle_psth = figure;
%                                             %    x1,     y1, width,  height
%             set(this.fig_hndle_psth, 'Position', [1050, 1080/2 - 100,   750,    400]);
%             set(this.fig_hndle_psth, 'Name', 'PSTH Plot');
%             set(this.fig_hndle_psth, 'NumberTitle', 'off');
% 
%             this.axs_hndle_psth = gca;
%             xlim([-this.time_before_event this.time_after_event])
%             title('Peri-Stimulus Time Histogram')
%             xlabel('Time [ms]')
%             ylabel('Firing rate [Hz]')
%             grid on
%             grid minor

            this.update_plots();
        end

        function Open(this)
            this.is_enable = true;
            this.init_plots();           
        end

        function Close(this)
            this.is_enable = false;
            %TODO - close figures and empty handles
        end

        function reset(this)
            this.spikes_history = zeros(2, this.recent_spike_count, 'single');
            this.raster_data = zeros(this.recent_event_count, ...
                this.raster_T, this.available_neurons, 'logical');
            this.update_plots();
            T = this.bin_edges(2:end);
            y = zeros(size(T));
            plot(this.axs_hndle_psth,T, y);
        end
    end
end

