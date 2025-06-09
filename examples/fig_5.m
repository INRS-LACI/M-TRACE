%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fig_5.m
% 
% Patrick Kilcullen (patrick.kilcullen@inrs.ca)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

close all;
clear all;

% Configuration of M-TRACE settings:
settings.user_bounce_types = {'dmd', @bounce_dmd};
    % Registration of 'dmd' bounce type for this simulation.
settings.scene_update_mode = 'cumulative';
spin_rate = 0.003;  % Radians per frame
settings.pre_trace_callback_fcn = @(x,y) ...
    spin_around_object(x, y, spin_rate, 'polygon_group', 'polygon_mirror');
settings.post_trace_callback_fcn = @(x,y) report(x, y, 'output_slit');

% Start simulation:
m_trace('fig_5.svg', settings);

%% Animation callback function for continuous rotation of an object group:
function cont = spin_around_object(ax_h, ~, spin_rate, group_id, center_id_str)
    c_id = m_trace_get_paths_by_tag(ax_h.UserData.m_trace_data, center_id_str);
    center = m_trace_get_path_centroid(...
        ax_h.UserData.m_trace_data.path_data{c_id(1)});

    dt = spin_rate;

    id = m_trace_get_paths_by_tag(ax_h.UserData.m_trace_data, group_id);
    for k=1:numel(id)
        path = m_trace_transform_path_rotate(...
            ax_h.UserData.m_trace_data.path_data{id(k)}, dt, center);
        ax_h.UserData.m_trace_data.path_data{id(k)} = path;
    end
    cont = true;
end

%% Callback function for updating reported data axes:
function cont = report(ax_h, frame_num, id_str)
    % On the initial frame, transfer the plot to share the same figure as the
    % raytracing simulator, discarding the original parent figure:
    if frame_num==0
        % Creation of data reporting figure:
        ax_h.Units = 'normalized';
        ax_h.OuterPosition = [0,0,0.5,1];
        title(ax_h, 'Simulation of SPI-ASAP');

        ax_h2 = axes(ax_h.Parent);
        ax_h2.Units = 'normalized';
        ax_h2.OuterPosition = [0.5,.1,0.5,.8];

        ax_p = plot(ax_h2, [1], [1], '*r');
        ax_p.XData = [];
        ax_p.YData = [];
        ax_p.Tag = 'output_slit_reported_data';
        xlabel('Animation frame number');
        ylabel('Ray intersection x-coordinate (mm)');
        title('Output slit ray intersection data', 'Interpreter', 'none');
    end

    % Obtain object relevant raytracing data from the scene:
    data = m_trace_get_trace_data_by_tag(ax_h.UserData.m_trace_data, id_str);

    % Update figure:
    xnew = frame_num * ones(1, numel(data));
    ynew = zeros(1, numel(data));
    for k=1:numel(data)
        ynew(k) = data{k}.launch(1);    % Extract intersection x coordinate.
    end
    l_h = findobj(ax_h.Parent, 'Tag', 'output_slit_reported_data');
    l_h.XData = [l_h.XData, xnew];    % Append new data
    l_h.YData = [l_h.YData, ynew];    % 
    l_h.Parent.XLim(2) = frame_num;    % X limit adjustment

    cont = true;
end

%% Callback function for implementing a user-defined raytracing bounce type:
function [normal, ch_normal, data_out, cont] = bounce_dmd(bounce_info, data_in)
    old_norm = bounce_info.incoming_normal;
    surf_norm = bounce_info.surface_normal;
    % Surface normal correction:
    if dot(surf_norm, old_norm) > 0
        surf_norm = -surf_norm;
    end

    % Validation: this facet type must have a single argument:
    obj = bounce_info.object;
    if ~isfield(obj, 'bounce_type_args') || numel(obj.bounce_type_args) ~= 1
        error('Bounce type ''dmd'' must have one argument.');
    end
    th = obj.bounce_type_args(1) * (pi/180); % DMD reflection angle (in radians)
    
    % DMD bounces: we reflect, then rotate by the argument amount
    reflection_normal = old_norm - 2*dot(old_norm,surf_norm)*surf_norm;
    normal = [cos(th), -sin(th); sin(th), cos(th)] * reflection_normal(:);
    ch_normal = [];
    data_out = data_in;
    cont = true;
end