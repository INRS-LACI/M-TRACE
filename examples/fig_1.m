%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fig_1.m
% 
% Patrick Kilcullen (patrick.kilcullen@inrs.ca)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

close all;
clear all;

% Configuration of M-TRACE settings:
settings.scene_update_mode = 'from_original';
settings.pre_trace_callback_fcn = ...
    @(s,x) animation_callback(s, x, 'galvo', 'galvo_pivot', 0.07, 50);

% Start simulation:
m_trace('fig_1.svg', settings);

%% Animation callback function for oscillating rotational motion:
function cont = animation_callback(ax_h, frame_count, id_str, id_pivot, ...
    amplitude, period)

    % Calculation of rotation angle:
    theta = amplitude*sin(2*pi*frame_count/period);
    
    % Obtain location of rotation pivot from object:
    id_pivot = m_trace_get_paths_by_tag(ax_h.UserData.m_trace_data, id_pivot);
    pivot_loc = m_trace_get_path_centroid(...
        ax_h.UserData.m_trace_data.path_data{id_pivot(1)});
    
    % Perform rotation:
    id = m_trace_get_paths_by_tag(ax_h.UserData.m_trace_data, id_str);
    path = m_trace_transform_path_rotate(...
        ax_h.UserData.m_trace_data.path_data{id(1)}, theta, pivot_loc);

    % Update simulation data:
    ax_h.UserData.m_trace_data.path_data{id(1)} = path;

    % Continue simulation?
    cont = true;
end