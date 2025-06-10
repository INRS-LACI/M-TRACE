%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% m_trace_generate_system_svg.m
% 
% Function for the automatic generation of optical system SVGs from data
% resembling a design prescrption table.
% 
% Aside from writing to the specified SVG file, the function also returns the
% coordinates [vx, vy] of the front vertex point of the system's first element.
% 
% If an optional argument is passed (varargin), this is treated as a specified
% system front vertex point of the format [vx, vy].
% 
% Patrick Kilcullen (patrick.kilcullen@inrs.ca)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [vx_o, vy_o] = m_trace_generate_system_svg(svg_in_path, system, ...
    svg_out_path, varargin)
    dom = xmlread(svg_in_path);

    % Check for the existence of the m_trace namespace, and create it if
    % necessary:
    root = dom.getDocumentElement;
    if ~root.hasAttribute('xmlns:m_trace')
        root.setAttribute('xmlns:m_trace', 'm_trace');
    end

    % Get document viewbox:
    view_box = str2num(char(root.getAttribute('viewBox'))); %#ok<ST2NM>
        % view_box is of the format [x y w h];

    % Get total system width:
    system_w = 0;
    for k=1:numel(system)
        if strcmp(system(k).type, 'thick_lens') || strcmp(system(k).type, 'gap')
            system_w = system_w + system(k).t;
        end
    end

    % Check to see if an input vertex position was provided:
    if ~isempty(varargin)
        front_vertex_pos = varargin{1};
        vx = front_vertex_pos(1);
        vy = front_vertex_pos(2);
    else
        % Calculate initial front vertex position (chosen so as the entire
        % system is centered in the document):
        vx = view_box(1) + (view_box(3) - system_w)/2;
        vy = view_box(2) + view_box(4)/2;
    end

    % Save initial values to return:
    vx_o = vx;
    vy_o = vy;

    % Create new path elements:
    for k=1:numel(system)
        if strcmp(system(k).type, 'gap')
            vx = vx + system(k).t;
            continue;
        end
        
        % For the rest of these cases, we generate a new path element:
        if strcmp(system(k).type, 'thick_lens')
            d_str = generate_lens_path_str(system(k), [vx, vy]);
            if isfield(system(k), 'style_str')
                style_str = system(k).style_str;    % Use user-specified style?
            else
                style_str = gen_lens_style_str(k);
            end
            m_str = sprintf('refract(%.8f)', system(k).n);
            vx = vx + system(k).t;
        elseif strcmp(system(k).type, 'aperture')
            d_str = generate_aperture_path_str(system(k), [vx, vy]);
            if isfield(system(k), 'style_str')
                style_str = system(k).style_str;    % Use user-specified style?
            else
                style_str = 'fill: none;stroke-width: 1;stroke: #000000;';
            end
            m_str = 'absorber';
        elseif strcmp(system(k).type, 'screen')
            d_str = generate_screen_path_str(system(k), [vx, vy]);
            if isfield(system(k), 'style_str')
                style_str = system(k).style_str;    % Use user-specified style?
            else
                style_str = 'fill: none;stroke-width: 1;stroke: #999999;';
            end
            m_str = 'transparent';
        else
            error('Unknown element type "%s".', system(k).type);
        end

        new_path = dom.createElement('path');
        new_path.setAttribute('d', d_str);
        new_path.setAttribute('id', sprintf('path_m_trace_gen_%d', k));
        new_path.setAttribute('style', style_str);
        new_path.setAttribute('m_trace:bounce_type', m_str);
        dom.getDocumentElement.appendChild(new_path);
    end

    % Save the SVG document:
    xmlwrite(svg_out_path, dom);
end


%% Helper function for generating thick lens path data
% front_vertex_pos is of the form [x, y];
function d_str = generate_lens_path_str(lens_data, front_vertex_pos)
    R1 = lens_data.R1;  % Front surface curvature
    R2 = lens_data.R2;  % Back surface curvature
    r1 = lens_data.r1;  % Front surface clear radius
    r2 = lens_data.r2;  % Back surface clear radius
    t = lens_data.t;    % Lens vertex to vertex thickness

    edge_taper = @(R, r) R - (2*(R>0)-1)*sqrt(R^2 - r^2);

    % Detect planar surfaces (i.e., where R = inf
    if isinf(R1)
        front_taper = 0;
        s1 = sprintf('v %.4f', -2*r1);
    else
        front_taper = edge_taper(R1, r1);
        s1 = sprintf('a %.4f %.4f 0 0 %d 0 %.4f', abs(R1), abs(R1), R1>0, -2*r1);
    end

    if isinf(R2)
        back_taper = 0;
        s3 = sprintf('v %.4f', 2*r2);
    else
        back_taper = edge_taper(R2, r2);
        s3 = sprintf('a %.4f %.4f 0 0 %d 0 %.4f', abs(R2), abs(R2), R2<0, 2*r2);
    end

    % Edge thickness value:
    t_edge = t + back_taper - front_taper;

    % Path data string assembly:
    step = r1 - r2;
    if step > 0         % add back surface extensions
        s3 = sprintf('v %.8f %s v %.8f', step, s3, step);
    elseif step < 0     % add front surface extensions
        s1 = sprintf('v %.8f %s v %.8f', step, s1, step);
    end

    s0 = sprintf('m %.8f %.8f', front_taper + front_vertex_pos(1), ...
        max(r1, r2) + front_vertex_pos(2));
    s2 = sprintf('h %.8f', t_edge);

    d_str = sprintf('%s %s %s %s z', s0, s1, s2, s3);
end


%% Helper function for generating aperture path (two vertical lines)
% front_vertex_pos is of the form [x, y];
function d_str = generate_aperture_path_str(lens_data, front_vertex_pos)
    r1 = lens_data.r1;  % Interpreted as aperture inner radius
    r2 = lens_data.r2;  % Interpreted as aperture outer radius

    s0 = sprintf('m %.8f %.8f', front_vertex_pos(1), front_vertex_pos(2)-r2);
    s1 = sprintf('v %.8f', r2-r1);
    s2 = sprintf('m 0 %.8f', 2*r1);
    s3 = sprintf('v %.8f', r2-r1);
    d_str = sprintf('%s %s %s %s', s0, s1, s2, s3);
end


%% Helper function for generating screen path data (a vertical line)
% front_vertex_pos is of the form [x, y];
function d_str = generate_screen_path_str(lens_data, front_vertex_pos)
    r1 = lens_data.r1;  % Interpreted as screen outer radius

    s0 = sprintf('m %.8f %.8f', front_vertex_pos(1), front_vertex_pos(2)-r1);
    s1 = sprintf('v %.8f', 2*r1);
    d_str = sprintf('%s %s', s0, s1);
end


%% Helper function for generating element style strings based on sequence order
function style_str = gen_lens_style_str(n)
    cmap = [... % elements generated from prism(6)
            1.0000         0         0; ...
            1.0000    0.5000         0; ...
            1.0000    1.0000         0; ...
                 0    1.0000         0; ...
                 0         0    1.0000; ...
            0.6667         0    1.0000];
    chex = dec2hex( round( 255*cmap(mod(n, 6)+1, :) ), 2);
    color_str = sprintf('%s%s%s', chex(1,:), chex(2,:), chex(3,:));
    style_str = sprintf('fill: #%s;fill-opacity: 0.3;stroke: none', color_str);
end
