%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fig_6.m
% 
% Patrick Kilcullen (patrick.kilcullen@inrs.ca)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

close all;
clear all;

% Configuration of M-TRACE settings (full demo animation):
settings.scene_update_mode = 'from_original';
settings.pre_trace_callback_fcn = ...
    @(s, x) animation_callback(s, x, 'input_ray', 1, 100, [0, -30.4]);
settings.post_trace_callback_fcn = ...
    @(s, x) report(s, x, 'screen_1', 'screen_2');

% Start simulation:
m_trace('fig_6.svg', settings);

%% Animation callback function for uniform linear motion:
function cont = animation_callback(ax_h, frame_count, id_str, amplitude, ...
    period, offset)
    dt = amplitude*(frame_count/(period-1));    % Linear interp.
    
    id = m_trace_get_paths_by_tag(ax_h.UserData.m_trace_data, id_str);
    for k=1:numel(id)
        ray_path = ax_h.UserData.m_trace_data.path_data{id(k)};
        new_path = m_trace_transform_path_translate(ray_path, dt*offset);
        ax_h.UserData.m_trace_data.path_data{id(k)} = new_path;
    end
    cont = frame_count < (period-1);   
end

%% Callback function for updating reported data axes:
function cont = report(ax_h, frame_num, id_str1, id_str2)
    % On the initial frame, transfer the plot to share the same figure as the
    % raytracing simulator, discarding the original parent figure:
    if frame_num==0
        % Maximize the figure window:
        ax_h.Parent.WindowState = 'maximized';

        % Creation of data reporting figure:
        ax_h.Units = 'normalized';
        ax_h.OuterPosition = [0,0,0.7,1];

        ax_h2 = axes(ax_h.Parent);
        ax_h2.Units = 'normalized';
        ax_h2.OuterPosition = [0.7,.2,0.3,.6];

        hold on;
        ax_p = plot(ax_h2, [1], [1], '*r');
        ax_p.XData = [];
        ax_p.YData = [];
        ax_p.Tag = 'reported_data';

        hold on;
        ax_p2 = plot(ax_h2, [1], [1], '-b');
        ax_p2.XData = [];
        ax_p2.YData = [];
        ax_p2.Tag = 'exact_data';

        xlabel('Screen 2 intersection x-coordinate (mm)');
        ylabel('Screen 1 intersection height above axis (mm)');
        legend('M-TRACE', 'Exact calculation', 'Location', 'east');
        title('LA^{\prime}');
        grid on;
        box on;
    end

    % Obtain object relevant raytracing data from the scene:
    data1 = m_trace_get_trace_data_by_tag(ax_h.UserData.m_trace_data, id_str1);
    data2 = m_trace_get_trace_data_by_tag(ax_h.UserData.m_trace_data, id_str2);

    % Update figure:
    num_new_pts = min(numel(data1), numel(data2));
    xnew = zeros(1, num_new_pts);
    ynew = zeros(1, num_new_pts);
    xnew_exact = zeros(1, num_new_pts);
    ynew_exact = zeros(1, num_new_pts);
    for k=1:num_new_pts
        % Raytraced data
        xnew(k) = data2{k}.launch(1) - 180.026;     % Copied from SVG V7
        ynew(k) = 39.7815 - data1{k}.launch(2);     % 

        % Do exact calculation using p_analytic_raytrace():
        ynew_exact(k) = ynew(k);
        y1 = ynew_exact(k);
        n_LAF3   = 1.716998;    % Index values for Helium d line taken from 
        n_SF5    = 1.672697;    % Zemax SCHOTT.AGF internal glass catalogue
        n_BAFN11 = 1.666721;    % (Ansys Zemax OpticStudio R1.00)
        P = [ 75.050,  9.000,   n_LAF3, 33.0;
             270.700,  0.100,   1.0000, 33.0;
              39.270, 16.510, n_BAFN11, 27.5;
                 inf,  2.000,    n_SF5, 27.5;
              25.650, 10.990,   1.0000, 19.5;
                 inf, 13.000,   1.0000, 18.6;
             -31.870,  7.030,    n_SF5, 18.5;
                 inf,  8.980,   n_LAF3, 21.0;
             -43.510,  0.100,   1.0000, 21.0;
             221.140,  7.980, n_BAFN11, 23.0;
             -88.790, 61.418,   1.0000, 23.0];
        [y2, t2] = analytic_raytrace(y1, 0, P);
        % System front lens vertex points (in SVG document coords) are:
        % [32.4210, 50.000], known from the generation function...
        xnew_exact(k) = -y2/tan(t2);
    end

    l_h = findobj(ax_h.Parent, 'Tag', 'reported_data');
    l_h.XData = [l_h.XData, xnew];
    l_h.YData = [l_h.YData, ynew];

    l_h = findobj(ax_h.Parent, 'Tag', 'exact_data');
    l_h.XData = [l_h.XData, xnew_exact];
    l_h.YData = [l_h.YData, ynew_exact];

    if ~isempty(l_h.XData)
        xlim(.5*[-1, 1] + l_h.XData(1));
    end
    cont = true;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% analytic_raytrace.m
% 
% Function for performing 'analytic raytracing' on an input perscription table.
% The table, P, is an array of elements where each row is of the format:
%   [R, d, n, r]
% where R is the radius of the spherical interface (use Inf for a planar
% surface), d is the thickness (distance) to the next surface, n is the index of
% refraction following the surface, and r is the element's semi-aperture (i.e.
% radius).
% 
% The input values y1 and th1 specify the input ray's altitude and orientation,
% that are used to compute the values y2 and t2 at the system's output.
% 
% Patrick Kilcullen (patrick.kilcullen@inrs.ca)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [y2, t2] = analytic_raytrace(y, t, P)
    y1 = y;
    t1 = t;
    n1 = 1.00;  % Assumed ambient index
    for k=1:size(P,1)
        R = P(k,1);
        d = P(k,2);
        n2 = P(k,3);
        r = P(k,4);

        if isinf(R)     % Do calculations for a flat plane
            h = 0;
            phi = 0;
        else
            ha = 1 + (tan(t1))^2;
            hb = 2*(y1*tan(t1) - R);
            hc = y1^2;
            h1 = (-hb + sqrt(hb*hb - 4*ha*hc)) / (2*ha);
            h2 = (-hb - sqrt(hb*hb - 4*ha*hc)) / (2*ha);
            if abs(h1) <= abs(h2)
                h = h1;
            else
                h = h2;
            end
            phi = asin((y1 + h*tan(t1))/R);
        end

        t2 = asin((n1/n2)*sin(t1 + phi)) - phi;
        y2 = y1 + h*tan(t1) + (d-h)*tan(t2);

        if y1 + h*tan(t1) > r
            y2 = NaN;
            t2 = NaN;
            return;     % Return with empty rays if an aperture is hit
        else
            y1 = y2;    % Update steps
            t1 = t2;
            n1 = n2;
        end
    end
end