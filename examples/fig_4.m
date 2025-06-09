%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fig_4.m
% 
% Patrick Kilcullen (patrick.kilcullen@inrs.ca)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

close all;
clear all;

% Configuration of M-TRACE settings:
settings.scene_update_mode = 'from_original';
settings.pre_trace_callback_fcn = ...
    @(s, x) animation_callback(s, x, 'cavity_adjustment', 1, 40, 0.09*[0,1]);

% Start simulation:
m_trace('fig_4.svg', settings);

%% Animation callback function for oscillating linear motion:
function cont = animation_callback(ax_h, frame_count, id_str, amplitude, ...
    period, offset)

    dt = amplitude*cos(2*pi*frame_count/period);
    
    id = m_trace_get_paths_by_tag(ax_h.UserData.m_trace_data, id_str);
    for k=1:numel(id)
        path = m_trace_transform_path_translate(...
            ax_h.UserData.m_trace_data.path_data{id(k)}, dt*offset);
        ax_h.UserData.m_trace_data.path_data{id(k)} = path;
    end
    cont = true;   
end