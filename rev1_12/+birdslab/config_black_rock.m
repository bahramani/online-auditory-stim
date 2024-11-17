%  In the name of Allah

function config_black_rock()
    addpath('C:\Program Files (x86)\Blackrock Microsystems\Cerebus Windows Suite');
    
    cbmex('open');
%     cbmex('trialconfig', 1, 'double');
%     cbmex('trialconfig', 1, 'absolute');
    cbmex('trialconfig', 1);
end