%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% m_trace.m
% 
% M-TRACE: MATLAB Toolkit for Raytracing Animations in a Canvas Environment.
% 
% Performs a non-sequential raytracing simulation using data from an SVG file.
% 
% The optional settings argument is a struct that may have any of the following
% fields set:
%   output_save_file            (SVG file for saved raytraced output)
%   pre_trace_callback_fcn      (function handle, accepting two arguments)
%   post_trace_callback_fcn     (function handle, accepting two arguments)
%   scene_update_mode           ('from_original' or 'cumulative' (default))
%   custom_bounce_surface       (cell array of named function handles)
%   animation_framerate         (number, specified in seconds)
%   max_tracing_depth           (maximum number of bounces to compute per ray)
%   max_child_ray_depth         (maximum number of child rays allowed per ray)
%   min_bounce_distance         (minimum distance required between ray bounces)
%   max_vertex_distance         (maximum distance between vertices drawn to 
%                               approximate SVG shapes with MATLAB graphics, 
%                               relative to the canvas size)
%   user_bounce_types           (cell array containing custom bounce types)
%       must be an n by 2 cell array of the form {'name', @handle; ...};
%   ambient_refractive_index    (ambient refractive index of the scene)
%
% Patrick Kilcullen
% patrick.kilcullen@inrs.ca
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function m_trace(filename, varargin)
    if ~isempty(varargin)
        user_settings = varargin{1};
    else
        user_settings = [];
    end
    m_trace_has_exited = false;
        % Loca variable used to help infer correct behaviour of user requests to
        % close the figure window.

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Data setup:
    % The m_trace_get_svg_data function returns a cell array of structs with
    % fields describing basic information about each drawing object (paths)
    % found in the svg file. If paths in the svg file have attributes with
    % names starting with 'm_trace:' these will also be present as fields in
    % the appropriate struct.
    % As an extra pre-step, we check if the file exists (this gives a nicer
    % error than that returned by xmlread).
    if ~isfile(filename)
        error('File "%s" not found.', filename);
    end
    svg_data = m_trace_get_svg_data(filename);
    num_obj = numel(svg_data.path_data);
    
    % Create boundary polygon to surround the raytracing area. This will be
    % a rectangle with absorbing facets the same size as the plot area. The
    % dimensions of this boundary are derived from the document size of the SVG
    % illustration.
    x_lims = [svg_data.view_box(1), svg_data.view_box(3)];
    y_lims = [svg_data.view_box(2), svg_data.view_box(4)];
    
    outer_box.id = 'm_trace_scene_boundary';
    outer_box.subpaths.is_closed = true;
    outer_box.subpaths.seg_data(1).type = 'B';
    outer_box.subpaths.seg_data(1).data = ...
        [x_lims(1), y_lims(1), x_lims(1), y_lims(2)];
    outer_box.subpaths.seg_data(2).type = 'B';
    outer_box.subpaths.seg_data(2).data = ...
        [x_lims(1), y_lims(2), x_lims(2), y_lims(2)];
    outer_box.subpaths.seg_data(3).type = 'B';
    outer_box.subpaths.seg_data(3).data = ...
        [x_lims(2), y_lims(2), x_lims(2), y_lims(1)];
    outer_box.subpaths.seg_data(4).type = 'B';
    outer_box.subpaths.seg_data(4).data = ...
        [x_lims(2), y_lims(1), x_lims(1), y_lims(1)];
    
    outer_box.style.fill           = [0 0 0];
    outer_box.style.fill_opacity   = 0.0;
    outer_box.style.stroke         = [0 0 0];
    outer_box.style.stroke_opacity = 1.0;
    outer_box.style.stroke_width   = 1.0;
    outer_box.bounce_type = 'absorber';
    
    num_obj = num_obj + 1;
    svg_data.path_data{num_obj} = outer_box;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Unpacking of data from user_settings (to modify behaviour):
    arg_valid = @(x,y) ~isempty(x) && isfield(x, y) && ~isempty(x.(y));

    % Default values:
    output_save_file        = [];
    pre_trace_callback_fcn  = [];
    post_trace_callback_fcn = [];
    pass_original_scene_to_pre_callbacks = false;
    animation_pause = 1/20.0;       % 20 fps
    max_tracing_depth = 50;
    max_child_ray_depth = 10;
    min_bounce_distance = 1e-4;
    max_vertex_dist = sqrt( sum(svg_data.view_box(3:4).^2) ) * 1e-3;
    ambient_refractive_index = 1.00;

    % Unpacking of optional output saving file path:
    if arg_valid(user_settings, 'output_save_file')
        output_save_file = user_settings.output_save_file;
    end

    % Unpacking of optional callback functions:
    if arg_valid(user_settings, 'pre_trace_callback_fcn')
        pre_trace_callback_fcn = user_settings.pre_trace_callback_fcn;
    end
    if arg_valid(user_settings, 'post_trace_callback_fcn')
        post_trace_callback_fcn = user_settings.post_trace_callback_fcn;
    end

    % Unpacking of scene update mode:
    if arg_valid(user_settings, 'scene_update_mode')
        % arg should be 'from_original' or 'cumulative'.
        arg = user_settings.scene_update_mode;
        if strcmp(arg, 'from_original')
            pass_original_scene_to_pre_callbacks = true;
        elseif strcmp(arg, 'cumulative')
            pass_original_scene_to_pre_callbacks = false;
        else
            error(['Setting ''scene_update_mode'' should be either ', ...
                '''from_original'' or ''cumulative''.']);
        end
    end

    % Unpacking of animation framerate:
    if arg_valid(user_settings, 'animation_framerate')
        animation_pause = 1.0/user_settings.animation_framerate;
    end

    % Unpacking of maximum tracing depth:
    if arg_valid(user_settings, 'max_tracing_depth')
        max_tracing_depth = user_settings.max_tracing_depth;
        if max_tracing_depth < 0
            error(['Setting ''max_tracing_depth'' should be a ', ...
                'positive integer.']);
        end
    end

    % Unpacking of maximum limit for child ray generation:
    if arg_valid(user_settings, 'max_child_ray_depth')
        max_child_ray_depth = user_settings.max_child_ray_depth;
        if max_child_ray_depth < 0
            error(['Setting ''max_child_ray_depth'' should be a ', ...
                'positive integer.']);
        end
    end

    % Unpacking of minimum bounce distance:
    if arg_valid(user_settings, 'min_bounce_distance')
        min_bounce_distance = user_settings.min_bounce_distance;
        if min_bounce_distance < 0
            error(['Setting ''min_bounce_distance'' should be a ', ...
                'positive number.']);
        end
    end

    % Unpacking of maximum vertex distance (determines graphics quality):
    if arg_valid(user_settings, 'max_vertex_distance')
        max_vertex_dist = sqrt( sum(svg_data.view_box(3:4).^2) ) * ...
            user_settings.max_vertex_distance;
        if max_vertex_dist < 0
            error(['Setting ''max_vertex_distance'' should be a ', ...
                'positive number.']);
        end
    end

    % Unpacking of user-specified ambient refractive index:
    if arg_valid(user_settings, 'ambient_refractive_index')
        ambient_refractive_index = user_settings.ambient_refractive_index;
    end

    % Unpacking of user-specified bounce functions:
    % List of the built-in default bounce type function associations:
    bounce_dispatches = { ...
        'absorber', @bounce_absorber; 
        'mirror', @bounce_mirror;
        'thin_lens', @bounce_thin_lens;
        'partial_mirror', @bounce_partial_mirror;
        'single_sided_mirror', @bounce_single_sided_mirror;
        'refract', @(x, y) bounce_refract(x, y, ambient_refractive_index, ...
            min_bounce_distance);
        'transparent', @bounce_transparent;
    };
    % Collect all bounce dispatch info and create the struct. This may overwrite
    % default bounce types if the user specifies the same names...
    if arg_valid(user_settings, 'user_bounce_types')
        bounce_dispatches = [bounce_dispatches; ...
            user_settings.user_bounce_types];
    end
    bounce_dispatch_struct = struct([]);
    for k=1:size(bounce_dispatches,1)
        fname = bounce_dispatches{k,1};
        fhandle = bounce_dispatches{k,2};
        bounce_dispatch_struct(1).(fname) = fhandle;
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Graphics object initialization:
    % We now group the objects into types: 
    %   'visible objects' are ones for which a secondary vertex set is
    %       computed for the purposes of plotting to screen.
    %   'ray origins' are the paths which specify ray origins in the scene.
    % Logical indexing for each object type:
    ind_vo = false(1, num_obj);     % visible objects
    ind_ro = false(1, num_obj);     % ray origins
    for i=1:num_obj
        s = svg_data.path_data{i};
        if isfield(s, 'ray_origin')
            ind_ro(i) = isfield(s, 'ray_origin');
        else
            ind_vo(i) = ~isfield(s, 'invisible');
        end
    end
    
    % Now we create a graphics object associated with each shape, storing
    % its raytracing property data in the UserData property. Depending on
    % if the path is closed, a polyshape or a line is plotted.
    h = figure('CloseRequestFcn', @figure_close_callback);
        % Callback is used to terminate MATLAB immediately when figure is
        % closed. This is added for graceful exit behaviour.
    ax_h = axes(h, 'NextPlot', 'add', 'ClippingStyle', 'rectangle');
    axis(ax_h, 'ij');
    
    ax_h.DataAspectRatio = [1, 1, 1];
    ax_h.DataAspectRatioMode = 'manual';
    
    % Set the figure limits to match the viewbox (i.e. page boundary)
    % property from the SVG file:
    ax_h.XLimMode = 'manual';
    ax_h.XLim = [svg_data.view_box(1), svg_data.view_box(3)];
    ax_h.YLimMode = 'manual';
    ax_h.YLim = [svg_data.view_box(2), svg_data.view_box(4)];
    grid on;
    box on;
    xlabel(ax_h, 'x (mm)');
    ylabel(ax_h, 'y (mm)');
    
    % Path and line graphics object initialization:
    % Since paths can be composed of multiple subpaths, it's possible that
    % a single SVG path will consist of a mix of both open and closed
    % subpaths. Two graphics handles are thus initialized with lines and pshapes
    % used for open and closed (combined) subpath data, respectively. 
    for i=1:num_obj
        if ~ind_vo(i)      % skip non-visible objects
            continue;
        end
        obj = svg_data.path_data{i};
        svg_data.path_data{i} = update_graphics_from_path_data(ax_h, obj, ...
            max_vertex_dist);
    end
    
    % Text plotting. First we determine axis size:
    font_size_factor = find_scaling_factor(ax_h);
    text_handles = cell(1, numel(svg_data.text_data));
    for i=1:numel(svg_data.text_data)
        txt = svg_data.text_data{i};
        pos = txt.position;
        T = text(ax_h, pos(1), pos(2), txt.text);
        
        T.Color = txt.style.fill;
        T.FontUnits = 'centimeters';
        T.FontName = txt.style.font_family;
        % Parsing of italicization options:
        if isfield(txt.style, 'font_style')
            if strcmp(txt.style.font_style, 'italic')
                T.FontAngle = 'italic';
            end
        end
        T.UserData.orig_font_size = 0.1 * txt.style.font_size;
        T.FontSize = 0.1 * txt.style.font_size * font_size_factor;
        if isfield(txt.style, 'font_weight') && ...
                strcmp(txt.style.font_weight, 'bold')
            T.FontWeight = 'bold';
        else
            T.FontWeight = 'normal';
        end
        T.Clipping = 'on';
        T.Interpreter = 'none';
        T.HorizontalAlignment = 'left';     % Defaults
        T.VerticalAlignment = 'baseline';   % 
        
        t_ext = T.Extent;       % Saved for use for right justification
        T.Rotation = -txt.rotation;
            % SVG and MATLAB text rotation are backwards...
        
        % Interpret text alignment:
        if isfield(txt.style, 'text_align')
            if strcmp(txt.style.text_align, 'start') || ...
               strcmp(txt.style.text_align, 'right')
                T.HorizontalAlignment = 'right';
            elseif strcmp(txt.style.text_align, 'center')
                T.HorizontalAlignment = 'center';
            elseif strcmp(txt.style.text_align, 'end') || ...
                   strcmp(txt.style.text_align, 'left')
                T.HorizontalAlignment = 'left';
            end
        end
        % Compensation for different text anchor positions:
        if isfield(txt.style, 'text_anchor')
            t_pos = T.Position;
            a = txt.rotation;
            if strcmp(txt.style.text_anchor, 'start')
                t_shift = [-t_ext(3) + (t_ext(1) - t_pos(1)); 0];
            elseif strcmp(txt.style.text_anchor, 'end')
                t_shift = [t_ext(3) + (t_ext(1) - t_pos(1)); 0];
            else
                t_shift = [0; 0];
            end
            % The shift takes place relative to the text rotation:
            R = [cosd(a), -sind(a); sind(a), cosd(a)];
            t_shift = R * t_shift;
            T.Position = T.Position - [t_shift(1), t_shift(2), 0];
        end

        text_handles{i} = T;
    end
    
    % Add listeners for text resizing:
    addlistener(h,'SizeChanged', ...
        @(o,e) text_resize_listener(o, e, ax_h, text_handles));
    addlistener(ax_h, {'XLim','YLim'}, 'PostSet', ...
    	@(o,e) text_resize_listener(o, e, ax_h, text_handles));
          
    % Ray origin initialization:
    % Create plot handles for the ray origin objects:
    if ~any(ind_ro)
        warning('Could''nt find a ray origin.');
        return;
    end
    for i=1:num_obj
        if ~ind_ro(i)
            continue;
        end
        
        % Ray origin should be a non-closed path with three vertices:
        ray = svg_data.path_data{i};
        ray.ray_origin_subpaths = ray.subpaths;
            % A copy of the initial ray origin subpaths is created in order for
            % later graphics update calls to be based on the subpaths field,
            % analagously to the drawing routines used for generic paths. The
            % subpaths field for rays is updated automatically after raytracing
            % by the function derive_ray_subpath_data().
        ro_v = derive_subpath_vertex_data(ray.ray_origin_subpaths(1), ...
            max_vertex_dist);
        if numel(ray.ray_origin_subpaths)==1 && ...
                size(ro_v,1)==3 && ~ray.ray_origin_subpaths(1).is_closed
            % The middle point in the path will be the ray's origin point
            r_orig = ro_v(2,:);

            ray_g_h = plot(ax_h, r_orig(1), r_orig(2));
            ray_g_h.Color     = ray.style.stroke;
            ray_g_h.LineWidth = (72/25.4)*ray.style.stroke_width;
                % Conversion of mm to points (1/72 of 1 inch).
            ray_g_h.LineStyle = '-';
            ray.graphics_handle_open_subpaths = ray_g_h;
            ray.graphics_handle_closed_subpaths = [];
            ray.redraw_needed = false;

            svg_data.path_data{i} = ray;
        else
            error('ray_origin is incorrectly formatted.');
        end
    end

    % Attach data to the axis handle:
    svg_data.input_file = filename;
    ax_h.UserData.m_trace_data = svg_data;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Animation loop:
    frame_count = 0;
    continue_loop = true;
    deleting_fig = false;   % Flag used to trigger user-initiated exiting.
    if pass_original_scene_to_pre_callbacks
        svg_data_o = svg_data;      % Save original scene data (copy).
    end

    while continue_loop && ~deleting_fig
        continue_loop1 = true;
        continue_loop2 = true;
        has_pre_trace_callback_fcn  = false;
        has_post_trace_callback_fcn = false;

        % User-defined pre-trace callback function is called first
        if ~isempty(pre_trace_callback_fcn)
            if pass_original_scene_to_pre_callbacks
                ax_h.UserData.m_trace_data = svg_data_o;
            end
            continue_loop1 = pre_trace_callback_fcn(ax_h, frame_count);
            has_pre_trace_callback_fcn = true;
        end
    
        % Update ray path data. Note: pre-computation of the ray origin data is
        % not done in order to allow user callbacks to animate the ray_origin
        % paths themselves.
        for i=1:num_obj
            if ~ind_ro(i)
                continue;
            end
            
            % Initialize data for iterative raytracing:
            % First step: extracting the initial launch point and direction
            ray = ax_h.UserData.m_trace_data.path_data{i};
            % p_1 and p_3 are endpoint node coords; p_2 is that of the midpoint.
            p_1 = [ray.ray_origin_subpaths(1).seg_data(1).data(1); ...
                   ray.ray_origin_subpaths(1).seg_data(1).data(2)];
            p_2 = [ray.ray_origin_subpaths(1).seg_data(1).data(3); ...
                   ray.ray_origin_subpaths(1).seg_data(1).data(4)];
            p_3 = [ray.ray_origin_subpaths(1).seg_data(2).data(3); ...
                   ray.ray_origin_subpaths(1).seg_data(2).data(4)];
            % r_norm will be chosen as the normal vector pointing away from the
            % middle point along the longest arm:
            d1 = p_1 - p_2;
            d2 = p_3 - p_2;
            L1 = norm(d1);  % Segment lengths
            L2 = norm(d2);  %
            if L1>=L2
                r_norm = d1/norm(d1);
            else
                r_norm = d2/norm(d2);
            end

            % Initialize the first computed bounce node structure:
            ray_path_o.launch = p_2;        % Coordinates of launch point
            ray_path_o.normal = r_norm;     % Propagation direction
            ray_path_o.bdepth = 0;          % Bounces encountered
            ray_path_o.cdepth = 0;          % Child rays generated
            
            % Solve for the ray paths in the scene:
            ray_path = solve_ray_path(ray, ray_path_o, ...
                ax_h.UserData.m_trace_data.path_data, ...
                max_tracing_depth, max_child_ray_depth, ...
                min_bounce_distance, bounce_dispatch_struct, ax_h);

            % Attach path data from the structure and update plots:
            ray.m_trace_computed_path = ray_path;
            ray.subpaths = derive_ray_subpath_data(ray_path);
            ray.redraw_needed = true;
            ax_h.UserData.m_trace_data.path_data{i} = ray;
        end
        
        % Refresh plot
        warning('off', 'MATLAB:handle_graphics:Text:LargeFontSizeWarning');
        path_graphics_update(ax_h, max_vertex_dist);
            % Custom graphics update function:
        warning('on', 'MATLAB:handle_graphics:Text:LargeFontSizeWarning');
            % Warnings disabled for cases in which close user zooms result
            % in text sizing beyond display device limits
        
        % User-defined post-trace callback function is called last
        if ~isempty(post_trace_callback_fcn)
            continue_loop2 = post_trace_callback_fcn(ax_h, frame_count);
            has_post_trace_callback_fcn = true;
        end

        % Loop variable updates:
        pause(animation_pause);
        frame_count = frame_count + 1;
        continue_loop = continue_loop1 && continue_loop2 ...
            && (has_post_trace_callback_fcn || has_pre_trace_callback_fcn);
            % We halt if either callback function indicates, or if neither has
            % been specified.

        % Optional saving to file:
        % This is considered incompatible with ongoing animation by default, in
        % order to not have non-terminating simulations produce a large number
        % of output files (this behaviour can still be achieved using callback
        % functions, however). If continue_loop is true at this point, we issue
        % a warning, save the file, but also stop early.
        if ~isempty(output_save_file)
            if continue_loop
                warning(['Continuous animation is disabled by default ', ...
                    'when an output save file is specified. Instead, ', ...
                    'm_trace_svg_export() should be used within a ', ...
                    'callback function to export multiple frames from ', ...
                    'continuous animations. Exiting.']);
                continue_loop = false;
            end
            m_trace_svg_export(ax_h, frame_count, output_save_file);
        end
    end

    if deleting_fig
        delete(h);
    end
    m_trace_has_exited = true;

    % Helper function for handling graceful exiting when the figure window is 
    % closed:
    function figure_close_callback(src, ~)
        % Check to see if MATLAB is currently running. This allows for the
        % correct behaviour of the figure even if MATLAB is paused or stopped
        % using debugging tools. The state of MATLAB is checked by testing if
        % the status text 'Busy' appears in the UI.
        % Code is excerpted from  CmdWinTool Version 1.3.0.0 (9.03 KB) by Jan:
        % https://www.mathworks.com/matlabcentral/fileexchange/32005-cmdwintool
        desktop   = com.mathworks.mde.desk.MLDesktop...
            .getInstance; %#ok<JAPIMATHWORKS> 
        mainFrame = desktop.getMainFrame;
        status_text = char(mainFrame.getMatlabStatusText());
        matlab_is_running = strcmp(status_text, 'Busy');

        if matlab_is_running && ~m_trace_has_exited
            deleting_fig = true;
        else
            delete(src);
        end
    end
end


%% Helper function for solving a ray path
% path_data is a cell array of structs that describe simulation objects.
% ray is a struct that provides information about the attributes of the original
% SVG path object (useful for later bounce calculations).
% ray_path_o is a struct that describes the ray's current conditions.
function ray_path = solve_ray_path(ray, ray_path_o, path_data, ...
    max_tracing_depth, max_child_ray_depth, min_bounce_distance, ...
    bounce_dispatch_struct, ax_h)
    num_obj = numel(path_data);
    
    % Each bounce continues until it is stopped by an absorber or hits maximum
    % tracing depth.
    tracing = true;
    curr_node = ray_path_o;
    ray_path = {curr_node};     % Paths are accumulated as a cell array of nodes
    ray_path_acc = 1;

    while tracing && ...
            ~(curr_node.bdepth > max_tracing_depth) && ...
            ~(curr_node.cdepth > max_child_ray_depth)
        % The intersect function returns the intersection information from
        % a given object (if applicable). We find the correct bounce as the
        % closest intersection
        bounce_distance	= Inf;  % Sentinel, will be minimized in loop
        bounce_info = [];
        bounce_index = [];
        for k=1:num_obj
            if ~isfield(path_data{k}, 'bounce_type')
                continue;   % Skip objects that can't affect the rays.
            end
            
            [b_info, b_dist] = bounce_test(curr_node, path_data{k}, ...
                min_bounce_distance);
            % bounce_test returns [[], Inf] if no bounce found
            if b_dist < bounce_distance
                bounce_distance	= b_dist;
                bounce_info    	= b_info;
                bounce_index    = k;
            end
        end

        if ~isempty(bounce_info)
            % If a bounce was found, complete the next node using the
            % appropriate function specified by bounce_type
            curr_node.ray_data = ray;
                % Append original ray SVG info for the bounce calculation
            [new_node, child_node, tracing] = bounce(curr_node, bounce_info, ...
                path_data{bounce_index}, bounce_dispatch_struct, ax_h);
        
            if ~isempty(child_node)   % Compute paths of possible child rays
                % Recursive call:
                ray_path_c = solve_ray_path(ray, child_node, path_data, ...
                    max_tracing_depth, max_child_ray_depth, ...
                    min_bounce_distance, bounce_dispatch_struct, ax_h);
                new_node.rchild = ray_path_c;
            end
            
            % Update the current node, and append to the ray_path array:
            ray_path_acc = ray_path_acc + 1;
            ray_path{ray_path_acc} = new_node;
            curr_node = new_node;
        else
            % If further ray tracing was not possible:
            tracing = false;
        end
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Helper functions for graphics computations:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Helper function for updating all path-associated graphics handles
% Also handles the drawing of computed ray paths.
function path_graphics_update(ax_h, max_vertex_dist)
    svg_data = ax_h.UserData.m_trace_data;
    num_obj = numel(svg_data.path_data);
    for i=1:num_obj
        obj = svg_data.path_data{i};
        if ~isfield(obj, 'subpaths') ...
                || ~isfield(obj, 'redraw_needed') ...
                || ~obj.redraw_needed
            continue;
        end
        ax_h.UserData.m_trace_data.path_data{i} = ...
            update_graphics_from_path_data(ax_h, obj, max_vertex_dist);
    end
    drawnow;
end


%% Helper function for updating graphics data from path/subpath data
% Will also generate needed grpahics objects from scratch if none exist.
function obj_out = update_graphics_from_path_data(ax_h, obj_in, max_vertex_dist)
    obj_out = obj_in;

    % First step: accumulate all open/closed path vertex data in the format
    % appropriate for multi-shape display with either polyshapes or lines:
    closed_subpath_data = [];
    open_subpath_data = [];
    for j=1:numel(obj_out.subpaths)
        obj_sub = obj_out.subpaths(j);
        v = derive_subpath_vertex_data(obj_sub, max_vertex_dist);
        if obj_sub.is_closed
            if isempty(closed_subpath_data)
                closed_subpath_data = v;
            else
                closed_subpath_data = ...
                    [closed_subpath_data; [NaN, NaN]; v];   %#ok<AGROW> 
            end
        else
            if isempty(open_subpath_data)
                open_subpath_data = v;
            else
                open_subpath_data = ...
                    [open_subpath_data; [NaN, NaN]; v];     %#ok<AGROW> 
            end
        end
    end
    
    % Update graphics objects (with possible deletion/creation):
    if isempty(open_subpath_data)
        if isfield(obj_out, 'graphics_handle_open_subpaths') ...
                && ~isempty(obj_out.graphics_handle_open_subpaths)
            delete(obj_out.graphics_handle_open_subpaths);
        end
        obj_out.graphics_handle_open_subpaths = [];
    else
        if ~isfield(obj_out, 'graphics_handle_open_subpaths') ...
                || isempty(obj_out.graphics_handle_open_subpaths)
            g_h = plot(ax_h, open_subpath_data(:,1), ...
                open_subpath_data(:,2));
        else
            g_h = obj_out.graphics_handle_open_subpaths;
        end
        g_h.XData = open_subpath_data(:,1);
        g_h.YData = open_subpath_data(:,2);
        g_h.Color     = obj_out.style.stroke;
        g_h.LineWidth = (72/25.4)*obj_out.style.stroke_width;
            % Conversion of mm to points (1/72 of 1 inch).
        obj_out.graphics_handle_open_subpaths = g_h;
    end
    if isempty(closed_subpath_data)
        if isfield(obj_out, 'graphics_handle_closed_subpaths') ...
                && ~isempty(obj_out.graphics_handle_closed_subpaths)
            delete(obj_out.graphics_handle_closed_subpaths);
        end
        obj_out.graphics_handle_closed_subpaths = [];
    else
        if ~isfield(obj_out, 'graphics_handle_closed_subpaths') || ...
                isempty(obj_out.graphics_handle_closed_subpaths)
            pshape = polyshape(closed_subpath_data, ...
                'Simplify', false, 'KeepCollinearPoints', true);
            g_h = plot(ax_h, pshape);
        else
            g_h = obj_out.graphics_handle_closed_subpaths;
            g_h.Shape.Vertices = closed_subpath_data;
        end
        g_h.FaceColor = obj_out.style.fill;
        g_h.FaceAlpha = obj_out.style.fill_opacity;
        g_h.EdgeColor = obj_out.style.stroke;
        g_h.EdgeAlpha = obj_out.style.stroke_opacity;
        g_h.LineWidth = (72/25.4)*obj_out.style.stroke_width;
            % Conversion of mm to points (1/72 of 1 inch).
        obj_out.graphics_handle_closed_subpaths = g_h;
    end
    obj_out.redraw_needed = false;
end


%% Helper function for deriving line vertex data from a ray path
% ray_path will consist of a cell array of structs, where each element contains
% information about the ray as it is traced throughout the simulation. One cell
% array element gives one struct representing one 'bounce' (i.e., an interaction
% with an object, or the ray starting point).
% This function takes this computed data and returns a structure that is
% compatible with the 'subpath' structure generated for each SVG object.
function ray_subpaths = derive_ray_subpath_data(ray_path)
    ray_subpaths = [];
    acc = 0;
    has_rchild = false(numel(ray_path), 1);
    
    if numel(ray_path) < 2
        return;
    end

    % Derive path data for 'main' path:
    xy_prev = [];
    for k=1:numel(ray_path)
        node = ray_path{k};
        xy = node.launch;
        if k>1
            acc = acc + 1;
            ray_subpaths(1).is_closed = false;
            ray_subpaths(1).seg_data(acc).type = 'B';
            ray_subpaths(1).seg_data(acc).data = ...
                [xy_prev(1), xy_prev(2), xy(1), xy(2)];
        end
        xy_prev = xy;
        has_rchild(k) = isfield(node, 'rchild') && ~isempty(node.rchild);
    end
    if ~any(has_rchild)
        return;
    end
    
    % Derive path data for child paths (recursive):
    rchild_idxs = find(has_rchild);
    subpath_acc = 1;
    for k=1:numel(rchild_idxs)
        k_ind = rchild_idxs(k);
        temp = derive_ray_subpath_data(ray_path{k_ind}.rchild);
        for kk=1:numel(temp)
            subpath_acc = subpath_acc + 1;
            ray_subpaths(subpath_acc) = temp(kk);       %#ok<AGROW> 
        end
    end
end


%% Helper function for finding the intersection of a line with a path
% Although several intersections arise from this, only one is returned
% corresponding to the 'first bounce'. That is, the one with the smallest
% non-negative value of alpha when the intersection point x is found as:
%   x = r1 + n1 * alpha
% where r1 and n1 are the ray origin points, and normal directions,
% respectively.
% 
% INPUTS:
%   start_node: struct with the following required fields:
%       origin = 2-element vector for ray origin
%       normal = 2-element vector for ray propagation direction
%   Various other fields may be subsequently added by this function, or by other
%   (possibly user specified) functions that compute subsequent bounces. Fields
%   introduced by other bounce functions are always 'inherited' as direct copies
%   to children nodes. Some build-in field values:
%       rindex = refractive index of current node
%       rdepth = tracing depth of current node
%       rchild = sub-struct array if the ray splits into other rays
%       rstack = stack data structure representing the refractive objects
%                the current ray is considered to have encountered so far.
%                This allows overlapping objects to determine correct
%                refraction according to z-order precedence.
%   obj:    struct representing path object against which intersection is 
%           tested.
%   min_bounce_distance: Minimum distance required between bounce intersections.
%               Prevents incorrect tracing behaviour due to floating point
%               errors.
% OUTPUTS:
%   b_info:     Computed node for the next intersection
%   b_dist:     Computed bounce distance
% 
% If no next bounce is found, the elements of b_node match start_node,
% b_dist is set to Inf, and b_continue is set to false. 
function [b_info, b_dist] = bounce_test(start_node, obj, min_bounce_distance)

    MIN_D = min_bounce_distance;
        % Minimum (positive) required bounce distance

    % Default values:
    b_info = [];
    b_dist = Inf;

    % Ray intersection testing:
    surface_norm = [];
    r_o1 = start_node.launch;
    r_n1 = start_node.normal;
    r_o2 = [];
    for i=1:numel(obj.subpaths)
        for j=1:numel(obj.subpaths(i).seg_data)
            path_type = obj.subpaths(i).seg_data(j).type;
            data = obj.subpaths(i).seg_data(j).data;
            
            switch path_type
                case 'B'
                    [pp, nn] = util_intersect_path_B(r_o1, r_n1, data, MIN_D);    
                case 'E'
                    [pp, nn] = util_intersect_path_E(r_o1, r_n1, data, MIN_D);
            end

            d = norm(pp - r_o1);
            if d<b_dist && d > MIN_D
                b_dist = d;
                r_o2   = pp;
                surface_norm = nn;
            end
        end
    end
    
    % Ray update step (depends on bounce_type of object)
    if ~isempty(surface_norm) % If an intersection was found
        % Store the derived info into the struct for the next bounce
        % computations:
        b_info.surface_intersection = r_o2;
        b_info.incoming_normal      = r_n1;
        b_info.bounce_type          = obj.bounce_type;
        if isfield(obj, 'bounce_type_args')
            b_info.bounce_type_args = obj.bounce_type_args;
        else
            b_info.bounce_type_args = [];
        end
        b_info.surface_normal = surface_norm;
    end
end


%% Helper function for computing details of the next bounce, once found
% Will also attach 'report' information to the struct, identifying the tags of
% any object encountered.
function [next_node, next_child, continue_flag] = bounce(prev_node, b_info, ...
    object, bounce_dispatch_struct, ax_h)

    % Initialization
    next_node.launch = b_info.surface_intersection;
    next_node.bdepth = prev_node.bdepth + 1;
    next_node.cdepth = prev_node.cdepth;
    if isfield(object, 'tags')
        next_node.tags = object.tags;
    end

    % The purpose of a bounce function is to determine next_node.normal, and
    % possibly modify next_node.data. Inputs are the previous node, and the
    % bounce info struct.
    user_info.surface_intersection = b_info.surface_intersection;
    user_info.incoming_normal = b_info.incoming_normal;
    user_info.incoming_launch = prev_node.launch;
    user_info.surface_normal = b_info.surface_normal;
    user_info.object = object;
    user_info.m_trace_axis_handle = ax_h;

    if ~isfield(bounce_dispatch_struct, b_info.bounce_type)
        error('Unknown bounce_type: "%s"', b_info.bounce_type);
    end
    if isfield(prev_node, 'data')
        data_in = prev_node.data;
    else
        data_in = [];
    end
    [norm, child_norm, data, cont] = ...
        bounce_dispatch_struct.(b_info.bounce_type)(user_info, data_in);
    
    next_node.normal = norm;
    if ~isempty(data)
        next_node.data = data;
    end
    if ~isempty(child_norm)
        next_child = next_node;
        next_child.normal = child_norm;
        next_child.cdepth = prev_node.cdepth + 1;
        next_node.cdepth  = prev_node.cdepth + 1;
    else
        next_child = [];
    end
    continue_flag = cont;
end


%% Helper function for determining font size scaling factor:
% Assumes equal data aspect ratios for the x and y axis
%   (i.e. DataAspectRatio =[1 1 1];
function f = find_scaling_factor(ax_h)
    init_unit = ax_h.Units;
    ax_h.Units = 'centimeters';
    ax_pos = 10.0 * ax_h.Position;   % Convert cm to mm
    ax_h.Units = init_unit;

    ax_width  = ax_pos(3);
    ax_height = ax_pos(4);
    
    dx = diff(ax_h.XLim);
    dy = diff(ax_h.YLim);

    xy_aspect = dx/dy;
    ax_aspect = ax_pos(3)/ax_pos(4);
    if xy_aspect > ax_aspect
        f = ax_width / dx;
    else
        f = ax_height / dy;
    end
end


%% Helper function for handling font scaling after figure window resizing:
function text_resize_listener(~, ~, ax_h, txt_h)
    factor = find_scaling_factor(ax_h);
    for i=1:numel(txt_h)
        T = txt_h{i};
        warning('off', 'MATLAB:handle_graphics:Text:LargeFontSizeWarning');
        T.FontSize = T.UserData.orig_font_size * factor;
        warning('on', 'MATLAB:handle_graphics:Text:LargeFontSizeWarning');
            % Warnings disabled for cases in which close user zooms result
            % in text sizing beyond display device limits
    end
end


%% Helper function for deriving vertex data from subpath:
% This serves the role of allowing graphics shapes defined by lines and
% polyshape objects to approximate the ideal parametric SVG paths via a finite
% set of verticies connected by straight line segments.
% Vertex data is derived from the given subpath and returned in the form of an
% N by 2 matrix.
% 'max_dist' is a maximum distance specified for the space between two
% generated vertices (for non-straight line segments).
function sub_vertices = derive_subpath_vertex_data(sub_in, max_dist)
    sub_vertices = [];
    for j=1:numel(sub_in.seg_data)
        seg = sub_in.seg_data(j);
        switch seg.type
            case 'B'    % Bezier curve types: can be linear, quadratic, or cubic
                switch numel(seg.data)
                    case 4  % Straight line (no interpolation needed)
                        p1 = [seg.data(1), seg.data(2)];
                        p2 = [seg.data(3), seg.data(4)];
                        seg_vertices = zeros(2, 2);
                        seg_vertices(1,:) = p1;
                        seg_vertices(2,:) = p2;

                    case 6  % Quadratic curve
                        p1 = [seg.data(1), seg.data(2)];
                        p2 = [seg.data(3), seg.data(4)];
                        p3 = [seg.data(5), seg.data(6)];
                        tot_dist = sqrt(sum((p1-p2).^2)) + ...
                                   sqrt(sum((p2-p3).^2));
                        nT = ceil( tot_dist/max_dist );
                        nT = max(nT, 2);
                        T = linspace(0, 1, nT)';

                        bX =   p1(1)*(1-T).^2 + ...
                             2*p2(1)*(1-T).*T + ...
                               p3(1)*T.^2;
                        bY =   p1(2)*(1-T).^2 + ...
                             2*p2(2)*(1-T).*T + ...
                               p3(2)*T.^2;
                        seg_vertices = [bX, bY];

                    case 8  % Cubic curve
                        p1 = [seg.data(1), seg.data(2)];
                        p2 = [seg.data(3), seg.data(4)];
                        p3 = [seg.data(5), seg.data(6)];
                        p4 = [seg.data(7), seg.data(8)];
                        tot_dist = sqrt(sum((p1-p2).^2)) + ...
                                   sqrt(sum((p2-p3).^2)) + ...
                                   sqrt(sum((p3-p4).^2));
                        nT = ceil( tot_dist/max_dist );
                        nT = max(nT, 2);
                        T = linspace(0, 1, nT)';

                        bX =   p1(1)*(1-T).^3 + ...
                             3*p2(1)*(1-T).^2.*T + ...
                             3*p3(1)*(1-T).*T.^2 + ...
                               p4(1)*T.^3;
                        bY =  p1(2)*(1-T).^3 + ...
                            3*p2(2)*(1-T).^2.*T + ...
                            3*p3(2)*(1-T).*T.^2 + ...
                              p4(2)*T.^3;
                        seg_vertices = [bX, bY];

                end
            case 'E'    % Ellipsoidal curve type
                rx = seg.data(1);
                ry = seg.data(2);
                cx = seg.data(3);
                cy = seg.data(4);
                ph = seg.data(5);
                t1 = seg.data(6);
                t2 = seg.data(7);

                nT = ceil( max(rx,ry)*abs(t1-t2)/max_dist );
                nT = max(nT, 2);
                T = linspace(t1, t2, nT);

                seg_vertices = zeros(nT, 2);
                M = [cos(ph), -sin(ph), cx; sin(ph), cos(ph) cy];
                for k=1:nT
                    xy = M * [rx*cos(T(k)); ry*sin(T(k)); 1];
                    seg_vertices(k, :) = [xy(1), xy(2)];
                end
        end

        if j>1  % Remove duplicate vertex (included at end of prev seg)
            seg_vertices = seg_vertices(2:end, :);
        end
        sub_vertices = [sub_vertices; seg_vertices];        %#ok<AGROW>
    end

    if sub_in.is_closed
        % We remove a duplicate vertex at the end (created by default
        % last 'close path' command in the path data:
        sub_vertices = sub_vertices(1:(end-1), :);
    end
end