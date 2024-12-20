% In the name of Allah


clear;
clc;

session_folder = 'D:\BirdsLab Tools\BlackRock-Tools\sessions\2024-08-01\19-38-48';
fs = 30000;
win_size_PSTH = 100; %ms
time_before_event = 1000; %ms
time_after_event = 2000; %ms
tVec = -time_before_event:1:time_after_event-1;

color_map = ['#ff60d0'; % pink 1
             '#0072BD'; % cyan 2
             '#EDB120'; % yellow 3
             '#7E2F8E'; % magenta 4
             '#77AC30']; % green 5 

einfo = load(fullfile(session_folder, 'events-info.mat'));
einfo = einfo.einfo;
num_stim = length(einfo.events); 
stim_IDs = [einfo.events.id];


response_fig = figure;
set(response_fig, 'Name', 'Response', 'WindowState', 'maximized');
for i = 1:3*num_stim % num events
    ax(i) = subplot(3,num_stim,i);
end

units = struct('ID', {}, 'times', {});
trials = struct('event_time', {}, 'event_ID', {}, 'start_time', {}, ...
    'end_time', {}, 'spike_times', {}, 'num_spikes', {});
response = struct('event_ID', {}, 'num_event_played', {}, 'raster', {}, ...
    'PSTH', {}, 'PSTH_smoothed', {});

while true
    E = readtable(fullfile(session_folder, 'trial-events.txt'), 'NumHeaderLines', 1);
    event_ts = E.Var3*1000; %s to ms
    event_ids = E.Var4;

    N = readtable(fullfile(session_folder, 'trial-neurons.txt'), 'NumHeaderLines', 1);
    spike_ts = N.Var1*1000; %s to ms
    spike_ids = N.Var2;

    % DATA EXTRACTION

    spike_ids_un = [1,2];
    num_units = length(spike_ids_un); % since there is 0 id
    

    for i = 1:length(event_ids)
        trials(i).event_time = event_ts(i);
        trials(i).event_ID = event_ids(i);
        trials(i).start_time = trials(i).event_time - time_before_event;
        trials(i).end_time = trials(i).event_time + time_after_event;
        for j = 1:num_units 
            tmpTimes = spike_ts(spike_ids == spike_ids_un(j));
            [trials(i).spike_times{j}] = tmpTimes(tmpTimes>trials(i).start_time&tmpTimes<trials(i).end_time) - trials(i).start_time;
            trials(i).num_spikes{j} = length(trials(i).spike_times{j});
        end
    end

    for i = 1:num_stim
        response(i).event_ID = stim_IDs(i);
        response(i).num_event_played = sum(event_ids == response(i).event_ID);
        
        tmpRaster = cell(1, num_units);
        for j = 1:num_units
            tmpRaster{j} = zeros(response(i).num_event_played, time_before_event+time_after_event);
        end
        tmpAllSpk = {trials([trials.event_ID] == response(i).event_ID).spike_times};
        for j = 1:response(i).num_event_played 
            for k = 1:num_units
                tmpSpk = tmpAllSpk{1,j}{1,k};
                for p = 1:length(tmpSpk)
                    tmpRaster{k}(j, ceil(tmpSpk(p))) = 1;
                end
            end
        end
        response(i).raster = tmpRaster;

        response(i).PSTH = cell(1, num_units);
        for j = 1:num_units
            response(i).PSTH{j} = movmean((sum(response(i).raster{j}/response(i).num_event_played)*1000), win_size_PSTH);
            response(i).PSTH_smoothed{j} = movmean((sum(response(i).raster{j}/response(i).num_event_played)*1000), 2*win_size_PSTH);

        end

    end

    % PLOTTING
    
    for i = 1:num_stim
        % Raster
        subplot(ax(i))
        cla(ax(i))
        title(['Raster of Stimlus = ', num2str(response(i).event_ID)])
        xlabel('Time [ms]')
        ylabel('Trial #')
        xline(0, '-','Onset', 'Color', '#A2142F', 'LineWidth',2)
        hold on
        xlim([-time_before_event time_after_event])
        ylim([0 11])
        tmp = response(i).raster;
        for j = 1:response(i).num_event_played
            for k = 1:num_units
                plot([tVec(tmp{k}(j,:)~=0)-0.5;tVec(tmp{k}(j,:)~=0)+0.5], ...
                     [(tmp{k}(j,tmp{k}(j,:)~=0)*j)-0.5;(tmp{k}(j,tmp{k}(j,:)~=0)*j)+0.5], ...
                     'Color', color_map(spike_ids_un(k),:))
            end
        end

        % PSTH
        subplot(ax(i+2*num_stim))
        cla(ax(i+2*num_stim))
%         grid minor %todo
        title(['PSTH of Stimlus = ', num2str(response(i).event_ID)])
        xlabel('Time [ms]')
        ylabel('Firing rate [Hz]')
        xline(0, '-','Onset', 'Color', '#A2142F', 'LineWidth',2)
        hold on
        xlim([-time_before_event time_after_event])
%         ylim([0 10])
        for k = 1:num_units %num units
            plot(tVec, response(i).PSTH_smoothed{k}, 'LineWidth', 1.5, 'Color', color_map(spike_ids_un(k),:))
        end

        % Audio Stimulus
        subplot(ax(i+num_stim))
        cla(ax(i+num_stim))
        grid on
        title(['Waveform of Stimlus = ', num2str(response(i).event_ID)])
        xlabel('Time [ms]')
        ylabel('a.u.')
        xline(0, '-','Onset', 'Color', '#A2142F', 'LineWidth',2)
        hold on
        xlim([-time_before_event time_after_event])
        ylim([-0.1 0.1])
        plot(linspace(0,einfo.events(i).duration*1000,length(einfo.events(i).detector_samples)),einfo.events(i).detector_samples)

        
    end




    disp(numel(spike_ids))
    pause(3);
end
















