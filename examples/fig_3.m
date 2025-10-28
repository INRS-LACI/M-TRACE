%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fig_3.m
% 
% Patrick Kilcullen (patrick.kilcullen@inrs.ca)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

close all;
clear all;

% Animation function (displacement of cavity mirror):
period = 40;            % Animation period
offset = 0.09*[0,1];    % Maximum displacement vector [x, y] (mm)
disp_func = @(x) cos(2*pi*x/period) * offset;

% Configuration of M-TRACE settings:
settings.scene_update_mode = 'from_original';
settings.pre_trace_callback_fcn = ...
    @(s, x) animation_callback(s, x, 'cavity_adjustment', disp_func);
settings.post_trace_callback_fcn = ...
    @(s, x) report_callback(s, x, 'output_lens', disp_func, period/2);

% Start simulation:
m_trace('fig_3.svg', settings);

%% Animation callback function for oscillating linear motion:
function cont = animation_callback(ax_h, frame_count, id_str, disp_func)
    offset = disp_func(frame_count);
    
    id = m_trace_get_paths_by_tag(ax_h.UserData.m_trace_data, id_str);
    for k=1:numel(id)
        path = m_trace_transform_path_translate(...
            ax_h.UserData.m_trace_data.path_data{id(k)}, offset);
        ax_h.UserData.m_trace_data.path_data{id(k)} = path;
    end
    cont = true;   
end

%% Callback function for the saving of ray intersection data:
function cont = report_callback(ax_h, frame_num, id_str, disp_func, frame_limit)
    cont = true;
    if frame_num==0
        ax_h.UserData.fig_3_report.XData = [];  % Initialization of UserData
        ax_h.UserData.fig_3_report.YData = [];  % struct for data saving
    elseif frame_num > frame_limit  % Halt data accumulation after frame limit
        return;
    end
    % Mirror movement displacement calculation:
    displ = disp_func(frame_num);
    % Ray intersection data collection:
    data = m_trace_get_trace_data_by_tag(ax_h.UserData.m_trace_data, id_str);
    xnew = displ(2) * ones(1, numel(data)); % Extract displacement y coordinate
    ynew = zeros(1, numel(data));
    for k=1:numel(data)
        ynew(k) = data{k}.launch(1);        % Extract intersection x coordinate
    end
    % Data accumulation (allows for saving with parent figure for later use):
    ax_h.UserData.fig_3_report.XData = [ax_h.UserData.fig_3_report.XData, xnew];
    ax_h.UserData.fig_3_report.YData = [ax_h.UserData.fig_3_report.YData, ynew];
end