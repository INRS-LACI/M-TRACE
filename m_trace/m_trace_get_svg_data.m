%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% m_trace_get_svg_data.m
% 
% A function that ingests data from SVG files into a structure/field format
% for use by later code.
% 
% Currently the following SVG objects are supported:
%   Paths:
%       Now fully supported!
%       May be either open or closed
% 
%   Text:
%       Position and scaling are preserved.
%       Color is represented, but not transparency (MATLAB limitation)
%       Font
% 
% 
% Returned output is a structure with the fields:
%   view_box:   [x, y, w, h] vector (document units) representing page
%   path_data:  Cell array of structs representing document paths.
%   text_data:  Cell array of structs representing document text.
% 
% Patrick Kilcullen
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function output = m_trace_get_svg_data(filename)

    doc_XML = xmlread(filename);

    % Get some information about the document itself. The inkscape document
    % boundary will determine the boundary of the simulation and plot:
    svg_XML = doc_XML.getElementsByTagName('svg');  % Tag of base node
    svg_obj = svg_XML.item(0);                  % Only one should exist
    view_box = str2num(char(svg_obj.getAttribute('viewBox'))); %#ok<ST2NM>
    output.view_box = view_box;
    
    % Now we get all the path objects at once (even across ALL layers):
    paths_XML = doc_XML.getElementsByTagName('path');
    num_paths = paths_XML.getLength;
    path_data = cell(1, num_paths);
    for i=1:num_paths
        obj = paths_XML.item(i-1);  % DOM object.item(#) accesses are 0-based
        pd = derive_path_data(obj);
        pd.z_order = i;
        path_data{i} = pd;
    end
    output.path_data = path_data;
    
    % Now get information on text objects:
    texts_XML = doc_XML.getElementsByTagName('text');
    num_texts = texts_XML.getLength;
    text_data = cell(1, num_texts);
    for i=1:num_texts
        obj = texts_XML.item(i-1);
        text_data{i} = derive_text_data(obj);
    end
    output.text_data = [text_data{:}];  % Concatenates to one cell array
end


%% Helper function for deriving vertex data from path elements:
% Path data is stored in attributes consisting of a data string 'd', and
% other affine transformation attributes which are applied to the data
% afterwards.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function data = derive_path_data(path)
    namespace_m_trace = 'm_trace';
    attribute_prefix = [namespace_m_trace, ':'];
    data = [];
    % Read the 'raw' path vertex data:
    if ~path.hasAttribute('d')
        return;
    end
    subpaths = parse_path_data(path);
    if isempty(subpaths)
        return;
    end

    % Read any transforms and apply them:
    % In order to do this correctly, we have to walk all the way to the top
    % of the document tree, applying any transforms that the path node (or
    % any of its parents) have as attributes.
    % The top element for which we have to search is the 'svg' node
    % containing all graphics information of the document.
    curr_node = path;
    total_mtx = eye(3);
    while ~strcmp(char(curr_node.getNodeName), 'svg')
        if curr_node.hasAttribute('transform')
            transform_str = char(curr_node.getAttribute('transform'));
            mtx = parse_path_transforms(transform_str);
            total_mtx = mtx * total_mtx;
        end
        curr_node = curr_node.getParentNode;
    end
    
    % Apply the overall transform:
    for i=1:numel(subpaths)
        sd = subpaths(i).seg_data;
        for j=1:numel(sd)
            sd(j).data = apply_transform_to_segment(...
                sd(j).type, sd(j).data, total_mtx);
        end
        subpaths(i).seg_data = sd;
    end
    
    % Read style attributes:
    style_struct = parse_style_attributes(path);
    
    % Read the id attribute (if present):
    if path.hasAttribute('id')
        data.id = char(path.getAttribute('id'));
    end

    % Collect tags attributes for the current path. It can inherit multiple tags
    % from parent objects (e.g. groups).
    % Read and accumulate the tags list for the object. It may
    %  possibly inhert tags information from a parent (i.e. group 
    % 'g' element given a custom 'tags' attribute).
    curr_node = path;
    tags_acc = [];
    attr_n = sprintf('%stags', attribute_prefix);
    while ~strcmp(char(curr_node.getNodeName), 'svg')
        if curr_node.hasAttribute(attr_n)
            tags_info = char(curr_node.getAttribute(attr_n));
            if isempty(tags_acc)
                tags_acc = tags_info;
            else
                tags_acc = [tags_acc, ', ', tags_info];   %#ok<AGROW>
            end
        end
        curr_node = curr_node.getParentNode;
    end

    % Read any other information:
    % We take any other attributes prefixed by the attribute_prefix and add
    % them as fields to the returned structures later. We first accumulate these
    % fields into a separate 'custom_attributes' struct. To allow m_trace code
    % the freedom to update items in this structure, fields that begin with the
    % attribute prefix are disallowed.
    custom_attributes = struct();
    num_attributes = path.getAttributes().getLength();
    for i=1:num_attributes
        attr = char(path.getAttributes().item(i-1));
        temp_1 = regexp(attr, '[^="]*', 'match');
        if numel(temp_1)>2
            warning('Bad formatting of custom SVG attribute.');
            continue;
        end

        [match, tail] = regexp(temp_1{1}, attribute_prefix, 'match', ...
            'split');
        is_custom_attribute = ~isempty(match);
        
        if is_custom_attribute
            attribute_name = tail{end};
            if strcmp(attribute_name, 'tags')
                continue;   % Skip because we've already checked the tags.
            end

            [match, split] = regexp(attribute_name, ...
                [namespace_m_trace, '_'], 'match', 'split');
            if ~isempty(match) && isempty(split{1})
                % Issue warning for custom attributes that have names starting
                % with 'm_trace_':
                warning('Custom path attributes cannot start with "%s".', ...
                    [namespace_m_trace, '_']);
                continue;
            end

            temp_2 = regexp(temp_1{end}, '[^()]*', 'match');
            attribute_value = temp_2{1};
            
            % Parse any optional arguments passed to attribute:
            if numel(temp_2)>1
                temp_3 = regexp(temp_2{end}, '[^, ]*', 'match');
                attribute_args = str2double(temp_3);
                if any(isnan(attribute_args))
                    warning('Non-numeric argument to SVG attribute.');
                    continue
                end
            else
                attribute_args = [];
            end
        
            % Uses dynamically assigned field names:
            custom_attributes.(attribute_name) = attribute_value;
            if ~isempty(attribute_args)
                arg_field_name = sprintf('%s_args', attribute_name);
                custom_attributes.(arg_field_name) = attribute_args;
            end
        end
    end
    
    % We now assemble all the information into a cell array of structures
    % with fields storing all of the values so far collected:
    
    % Add the path data fields:
    data.subpaths = subpaths;
    data.style    = style_struct;

    % Add tags:
    if ~isempty(tags_acc)
        data.tags = tags_acc;
    end

    % Add custom fields:
    f = fieldnames(custom_attributes);
    for k=1:numel(f)
        data.(f{k}) = custom_attributes.(f{k});
    end
end


%% Helper function for deriving position and style data from text elements:
function data = derive_text_data(text_elem)
    style_struct = parse_style_attributes(text_elem);
    
    % We will see only if this text element has a rotation transformation
    % and return that argmument as a field.
    rot = 0;
    if text_elem.hasAttribute('transform')
        t_str = char(text_elem.getAttribute('transform'));
        rot_command = regexp(t_str, 'rotate\([+-\d.]*\)', 'match');
        if ~isempty(rot_command)
            rot = str2double(regexp(t_str, '[+-\d.]*', 'match'));
        end
    end
    
    % Now we loop over each tspan, accumulating the resulting structures in
    % a cell array 'data':
    num_tspans = text_elem.getLength;
    data = cell(1, 0);
    acc = 0;
    for j=1:num_tspans
        tspan = text_elem.item(j-1);    % DOM elements are indexed from 0
        
        if isempty(tspan.item(0))
            continue;
        end
        
        tspan_text = char(tspan.item(0).getTextContent);
        
        x = str2double(char( tspan.getAttribute('x') ));
        y = str2double(char( tspan.getAttribute('y') ));

        % Read any transforms and apply them:
        % In order to do this correctly, we have to walk all the way to the top
        % of the document tree, applying any transforms that the path node (or
        % any of its parents) have as attributes.
        % The top element for which we have to search is the 'svg' node
        % containing all graphics information of the document.
        curr_node = text_elem;
        total_mtx = eye(3);
        while ~strcmp(char(curr_node.getNodeName), 'svg')
            if curr_node.hasAttribute('transform')
                transform_str = char(curr_node.getAttribute('transform'));
                mtx = parse_path_transforms(transform_str);
                total_mtx = mtx * total_mtx;
            end
            curr_node = curr_node.getParentNode;
        end

        % Apply the transform:
        vt = total_mtx * [x; y; 1];
        x = vt(1);
        y = vt(2);

        % Read any style for this tspan. If any style information is found,
        % these values either add to or overwrite those of the style of the
        % parent text object. An important extra step is the adjustment of font
        % size information to take into account any transforms applied to the
        % text.
        if text_elem.hasAttribute('style')
            tspan_style = parse_style_attributes(tspan);
            tsp_f = fieldnames(tspan_style);
            for k=1:numel(tsp_f)
                style_struct.(tsp_f{k}) = tspan_style.(tsp_f{k});
            end
        end

        s.text = tspan_text;
        s.position = [x, y];
        s.style = style_struct;
        s.rotation = rot;
        
        acc = acc + 1;
        data{acc} = s;
    end
end


%% Helper function for parsing path string data:
% Returns a structure array 'subpaths' with the fields:
%   seg_data: (another structure array, see below)...
%   is_closed:
% 
% seg_data is a struct array of segments representing data from individual 
% lineto commands. The fields of segments are:
%   type:   Either 'B' or 'E' for Bezier, elliptical types respectively.
%   data:   A 1-dimensional array of data, with size and packing depending
%           on the type:
%       B:  [x1, y1, x2, y2]           straight line, i.e. 1st order Bezier
%           [x1, y1, x2, y2, x3, y3]       quadratic, i.e. 2nd order Bezier
%           [x1, y1, x2, y2, x3, y3, x4, y4]   cubic, i.e. 3rd order Bezier
%           In each case, the initial point coords start the array, and the
%           endpoint coords end the array.
%       E:  [rx, ry, cx, cy, ph, t1, t2]
% 			Where, rx and ry are the radii of the two ellipse axes, cx and 
%           cy specify the coordinates of the ellipse center, ph specifies
%           a rotation of the ellipse axis between the rx axis and the
%           document x axis (in radians), and t1 and t2 respectively are
%           start and end angles (in radians) that trace the curve when
%           drawn.
% 
% The data string consists of several tokens separated by either a space or
% comma, preceeded by letters which indicate the meaning of the command.
% Those commands which can pretain to paths comprised of straight line
% segments consist of:
% 
%   'moveto' commands:
%       M (absolute), m (relative)
%           x y
% 
%   'lineto' commands:
%       L (absolute), l (relative) - lineto
%           x y
%       H (absolute), h (relative) - horizontal lineto
%           x
%       V (absolute), v (relative) - vertical lineto
%           y
%       C (absolute), c (relative) - curveto
%           x1 y1 x2 y2 x y
%       S (absolute), s (relative) - shorthand/smooth curveto
%           x2 y2 x y
%           Initial control point is assumed to be the reflection of last
%           one from prev. command if prev. command is C, c, S, or s.
%       Q (absolute), q (relative) - quadratic Bezier curveto
%           x1 y1 x y
%       T (absolute), t (relative) - shorthand/smooth quad. Bezier curveto
%           x y
%           control point assumed to be the reflection of last one of prev.
%           command if prev. command is Q, q, T, or t.
%       A (absolute), a (relative) - elliptical arc
%           rx ry x-axis-rotation large-arc-flag sweep-flag x y
%           
%   'close path' commands:
%       Z, z (both equivalent)
%       ends the current path by connecting it back to its initial point
% 
% Data following letters other than those above will cause this function to
% return an empty array.
% 
% It is also possible for commands to be repeated (that is, extra x,y can
% be included but with the command letter not repeated). We also parse this
% case. If no commands follow an 'M' or 'm' command, a follwing 'L' or 'l' 
% command is inferred respectively.
% 
% There are other possiblilties that technically count as 'valid SVG' but
% aren't covered by my function here. These may also produce invalid
% results.
% 
% See https://www.w3.org/TR/SVG/paths.html#DProperty for more info.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function subpaths = parse_path_data(path)

    data_str = char(path.getAttribute('d'));   % cast from java.lang.string
    
    % We first parse the string into tokens using a regular expression.
    % Spaces and commas are ignored
    expr = '[a-zA-Z]|[+-]?[+-\d.eE]+';
    tokens = regexp(data_str, expr, 'match');
    % Tokens will now consist of cell array elements which are character
    % arrays of either command letters, or decimal numbers.
    
    % We will build the vertex data stack by parsing the tokens one at a
    % time, updating the vertex data with each command.
    % Command letters are detected by checking if a token length is 1, and
    % the letter is alphabetical.
    
    read_pos = 1;
    n_tokens = numel(tokens);
    curr_pos = [0, 0];  % Current drawing position
    init_pos = [0, 0];  % Initial drawing position of a subpath
    curr_command = [];
    path_invalid = false;
    acc_sp = 0;     % Accumulator index for the number of subpaths
    acc_sd = 0;     % Accumulator index for segments in each subpath
    while read_pos<=n_tokens
        % Depending on if the current token is numeric, we will either
        % interpret it as a new command, or as the first numeric data for a
        % repeated command. If we have no curr_command, then our data
        % string has started without issuing a command and the path is
        % invalid.
        tk = tokens{read_pos};
        if numel(tk)==1 && ...
                (('A'<=tk(1) && tk(1)<='Z') || ('a'<=tk(1) && tk(1)<='z'))
            curr_command = tk(1);
            read_pos = read_pos + 1;
        else % If we are repeating a command
            if isempty(curr_command)
                path_invalid = true;
                break;
            end
            % If we are 'repeating' an 'M' or 'm' command, then we will
            % switch to a corresponding line drawing command implicitly
            if strcmp(curr_command, 'M')
                curr_command = 'L';
            elseif strcmp(curr_command, 'm')
                curr_command = 'l';
            end
        end
        
        % read_pos should now be placed ready to absorb numeric tokens
        % applying to the above command. We now switch over the different
        % command cases which may indicate absolute or relative movements,
        % and the writing of NaN values to the data stack. Some commands
        % like 'Z' or 'z' indicate the closure of a previous path and do
        % not affect anything. These are absorbed by setting 'writing' to
        % falses in the corresponding switch block. Finally if the command
        % doesn't match any of those for line segment drawing, the path is
        % invalid.
        % The state of how the command arguments will be interpreted will
        % be stored in a 1 by 2 logical array called 'arg_signature'. Check
        % the code after this loop to see how its meaning is interpreted.
        create_subpath = false;     % Accumulation behaviour defaults
        create_segment = false;     % 
        switch curr_command
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % moveto commands:
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case 'M'    % Absolute non-drawing move
                p = num_advance(2);
                curr_pos = [p(1), p(2)];
                create_subpath = true;

            case 'm'    % Relative non-drawing move
                p = num_advance(2);
                curr_pos = [curr_pos(1)+p(1), curr_pos(2)+p(2)];
                create_subpath = true;

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % lineto commands:
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case 'L'    % Absolute line drawing move 
                p = num_advance(2);
                seg_t = 'B';
                seg_d = [curr_pos(1), curr_pos(2), p(1), p(2)];
                create_segment = true;
                curr_pos = [p(1), p(2)];

            case 'l'    % Relative line drawing move
                p = num_advance(2);
                seg_t = 'B';
                seg_d = [curr_pos(1), curr_pos(2), ...
                         curr_pos(1)+p(1), curr_pos(2)+p(2)];
                create_segment = true;
                curr_pos = [curr_pos(1)+p(1), curr_pos(2)+p(2)];

            case 'H'    % Absolute horizontal lineto
                p = num_advance(1);
                seg_t = 'B';
                seg_d = [curr_pos(1), curr_pos(2), p(1), curr_pos(2)];
                create_segment = true;
                curr_pos = [p(1), curr_pos(2)];

            case 'h'    % Relative horizontal lineto
                p = num_advance(1);
                seg_t = 'B';
                seg_d = [curr_pos(1), curr_pos(2), ...
                         curr_pos(1)+p(1), curr_pos(2)];
                create_segment = true;
                curr_pos = [curr_pos(1)+p(1), curr_pos(2)];

            case 'V'    % Absolute vertical lineto
                p = num_advance(1);
                seg_t = 'B';
                seg_d = [curr_pos(1), curr_pos(2), curr_pos(1), p(1)];
                create_segment = true;
                curr_pos = [curr_pos(1), p(1)];

            case 'v'    % Relative vertical lineto
                p = num_advance(1);
                seg_t = 'B';
                seg_d = [curr_pos(1), curr_pos(2), ...
                         curr_pos(1), curr_pos(2)+p(1)];
                create_segment = true;
                curr_pos = [curr_pos(1), curr_pos(2)+p(1)];
             
            case 'C'    % Absolute curveto
                p = num_advance(6);
                seg_t = 'B';
                seg_d = [curr_pos(1), curr_pos(2), ...
                         p(1), p(2), p(3), p(4), p(5), p(6)];
                create_segment = true;
                curr_pos = [p(5), p(6)];
                
            case 'c'    % Relative curveto
                p = num_advance(6);
                seg_t = 'B';
                seg_d = [curr_pos(1), curr_pos(2), ...
                         curr_pos(1)+p(1), curr_pos(2)+p(2), ...
                         curr_pos(1)+p(3), curr_pos(2)+p(4), ...
                         curr_pos(1)+p(5), curr_pos(2)+p(6)];
                create_segment = true;
                curr_pos = [curr_pos(1)+p(5), curr_pos(2)+p(6)];
                
            case 'S'    % Absolute shorthand/smooth curveto
                p = num_advance(4);
                if acc_sd<0
                    ctrl_p = curr_pos;
                else
                    prev_d = subpaths(acc_sp).seg_data(acc_sd-1).data;
                    if numel(prev_d)==8     % requires prev cubic B command
                        ctrl_p = 2*curr_pos - [prev_d(5), prev_d(6)];
                    else
                        ctrl_p = curr_pos;
                    end
                end
                seg_t = 'B';
                seg_d = [curr_pos(1), curr_pos(2), ...
                         ctrl_p(1), ctrl_p(2), p(1), p(2), p(3), p(4)];
                create_segment = true;
                curr_pos = [p(3), p(4)];
                
            case 's'    % Relative shorthand/smooth curveto
                p = num_advance(4);
                if acc_sd<0
                    ctrl_p = curr_pos;
                else
                    prev_d = subpaths(acc_sp).seg_data(acc_sd-1).data;
                    if numel(prev_d)==8     % requires prev cubic B command
                        ctrl_p = 2*curr_pos - [prev_d(5), prev_d(6)];
                    else
                        ctrl_p = curr_pos;
                    end
                end
                seg_t = 'B';
                seg_d = [curr_pos(1), curr_pos(2), ...
                         ctrl_p(1), ctrl_p(2), ...
                         curr_pos(1)+p(1), curr_pos(2)+p(2), ...
                         curr_pos(1)+p(3), curr_pos(2)+p(4)];
                create_segment = true;
                curr_pos = [curr_pos(1)+p(3), curr_pos(2)+p(4)];
                
            case 'Q'    % Absolute quadratic Bezier curveto
                p = num_advance(4);
                seg_t = 'B';
                seg_d = [curr_pos(1), curr_pos(2), ...
                         p(1), p(2), p(3), p(4)];
                create_segment = true;
                curr_pos = [p(3), p(4)];
                
            case 'q'    % Relative quadratic Bezier curveto
                p = num_advance(4);
                seg_t = 'B';
                seg_d = [curr_pos(1), curr_pos(2), ...
                         curr_pos(1)+p(1), curr_pos(2)+p(2), ...
                         curr_pos(1)+p(3), curr_pos(2)+p(4)];
                create_segment = true;
                curr_pos = [curr_pos(1)+p(3), curr_pos(2)+p(4)];
                
            case 'T'    % Absolute shorthand/smooth quad. Bezier curveto
                p = num_advance(2);
                if acc_sd<0
                    ctrl_p = curr_pos;
                else
                    prev_d = subpaths(acc_sp).seg_data(acc_sd-1).data;
                    if numel(prev_d)==6     % requires prev quad. B command
                        ctrl_p = 2*curr_pos - [prev_d(3), prev_d(4)];
                    else
                        ctrl_p = curr_pos;
                    end
                end
                seg_t = 'B';
                seg_d = [curr_pos(1), curr_pos(2), ...
                         ctrl_p(1), ctrl_p(2), p(1), p(2)];
                create_segment = true;
                curr_pos = [p(3), p(4)];
                
            case 't'    % Relative shorthand/smooth quad. Bezier curveto
                p = num_advance(2);
                if acc_sd<0
                    ctrl_p = curr_pos;
                else
                    prev_d = subpaths(acc_sp).seg_data(acc_sd-1).data;
                    if numel(prev_d)==6     % requires prev quad. B command
                        ctrl_p = 2*curr_pos - [prev_d(3), prev_d(4)];
                    else
                        ctrl_p = curr_pos;
                    end
                end
                seg_t = 'B';
                seg_d = [curr_pos(1), curr_pos(2), ...
                         ctrl_p(1), ctrl_p(2), ...
                         curr_pos(1)+p(1), curr_pos(2)+p(2)];
                create_segment = true;
                curr_pos = [curr_pos(1)+p(1), curr_pos(2)+p(2)];
                
            case 'A'    % Absolute elliptical arc
                p = num_advance(7);
                p2 = [curr_pos(1), curr_pos(2), ...
                     p(1), p(2), p(3), p(4), p(5), p(6), p(7)];
                seg_t = 'E';
                seg_d = convert_parameterization(p2);
                create_segment = true;
                curr_pos = [p(6), p(7)];
                
            case 'a'    % Relative elliptical arc
                p = num_advance(7);
                p2 = [curr_pos(1), curr_pos(2), ...
                     p(1), p(2), p(3), p(4), p(5), ...
                     curr_pos(1)+p(6), curr_pos(2)+p(7)];
                seg_t = 'E';
                seg_d = convert_parameterization(p2);
                create_segment = true;
                curr_pos = [curr_pos(1)+p(6), curr_pos(2)+p(7)];
                

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % close path commands:
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case {'Z', 'z'}
                % We must draw an automatic straight line segment between
                % the current point and the path start point (similiar to
                % an L command). This is however omitted if the points are
                % exactly equal (floating point comparison).
                subpaths(acc_sp).is_closed = true;              %#ok<AGROW>
                if (curr_pos(1)==init_pos(1)) && (curr_pos(2)==init_pos(2))
                    continue;
                end
                seg_t = 'B';
                seg_d = [curr_pos(1), curr_pos(2), ...
                    init_pos(1), init_pos(2)];
                create_segment = true;
                curr_pos = [init_pos(1), init_pos(2)];
                

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % default (path parse failure):
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            otherwise
                path_invalid = true;
                break;
        end
        
        % Accumulate subpath and segment results:
        if create_subpath
            init_pos = curr_pos;
            acc_sp = acc_sp + 1;
            acc_sd = 0;
            subpaths(acc_sp).seg_data   = [];                   %#ok<AGROW>
            subpaths(acc_sp).is_closed = false;                 %#ok<AGROW>
        end
        if create_segment
            acc_sd = acc_sd + 1;
            subpaths(acc_sp).seg_data(acc_sd).type = seg_t;     %#ok<AGROW>
            subpaths(acc_sp).seg_data(acc_sd).data = seg_d;     %#ok<AGROW>
        end
        
        if path_invalid
            subpaths = [];
            return;
        end
        
    end     % End of parsing while loop
    
    
    % Helper function for reading input data stream:
    % Advances token stream by k, attempting to convert each string to a
    % double.
    function nums = num_advance(k)
        a = read_pos;
        b = read_pos + k - 1;
        output_warning = false;
        if b>n_tokens
            output_warning = true;
        else
            nums = str2double(tokens(a:b));
            read_pos = read_pos + k;
            if any(isnan(nums))
                output_warning = true;
            end
        end
        if output_warning
            warning('Bad path data (ignoring)...');
            path_invalid = true;
            nums = nan(1, k);
        end
    end
end


%% Helper function for parsing path transforms:
% Path data can also contain transform attributes which affect the
% representation of the data as vertices applicable to polyshape
% construction. These transforms are stored as strings attached to an
% attribute 'transform' to the path node in the DOM.
% 
% The syntax of these transforms is several arguments of the form
%   <string>(<args>) ...
% with repeated instances following delimited by commas/whitespace, and
% <args> consisting of numbers also delimited by commas/whitespace.
% 
% For more information, see
%   https://drafts.csswg.org/css-transforms/#svg-syntax
%   https://drafts.csswg.org/css-transforms/#two-d-transform-functions
% 
% See the path parsing function for detailed comments about the structure
% of this parsing code.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function mtx = parse_path_transforms(transform_str)
    % Form the cell array of input tokens
    expr = '[a-zA-Z]+|[+-]?\d+(\.\d*)?';
    tokens = regexp(transform_str, expr, 'match');
    
    mtx = eye(3);
    read_pos = 1;
    while read_pos <= numel(tokens)    
        command = tokens{read_pos};
        read_pos = read_pos + 1;
        
        mtx_update = eye(3);
        switch command
            case 'scale'
                if read_pos+1>numel(tokens) || ...
                        isnan(str2double(tokens{read_pos+1}))
                    args = str2double(tokens(read_pos));
                    read_pos = read_pos + 1;
                    mtx_update(1,1) = args(1);
                    mtx_update(2,2) = args(1);
                else
                    args = str2double(tokens(read_pos+(0:1)));
                    read_pos = read_pos + 2;
                    mtx_update(1,1) = args(1);
                    mtx_update(2,2) = args(2);
                end
                  
            case 'rotate'
                args = str2double(tokens(read_pos));
                read_pos = read_pos + 1;
                mtx_update(1,1) = cosd(args(1));
                mtx_update(1,2) = -sind(args(1));
                mtx_update(2,1) = sind(args(1));
                mtx_update(2,2) = cosd(args(1));
                
            case 'scaleX'
                args = str2double(tokens(read_pos));
                read_pos = read_pos + 1;
                mtx_update(1,1) = args(1);
                
            case 'scaleY'
                args = str2double(tokens(read_pos));
                read_pos = read_pos + 1;
                mtx_update(2,2) = args(1);
                
            case 'translate'
                if read_pos+1>numel(tokens) || ...
                        isnan(str2double(tokens{read_pos+1}))
                    args = str2double(tokens(read_pos));
                    read_pos = read_pos + 1;
                    mtx_update(1,3) = args(1);
                    mtx_update(2,3) = 0;
                else
                    args = str2double(tokens(read_pos + (0:1)));
                    read_pos = read_pos + 2;
                    mtx_update(1,3) = args(1);
                    mtx_update(2,3) = args(2);
                end
                
            case 'translateX'
                args = str2double(tokens(read_pos));
                read_pos = read_pos + 1;
                mtx_update(1,3) = args(1);
                
            case 'translateY'
                args = str2double(tokens(read_pos));
                read_pos = read_pos + 1;
                mtx_update(2,3) = args(1);
            
            case 'skew'
                args = str2double(tokens(read_pos + (0:1)));
                read_pos = read_pos + 2;
                mtx_update(1,2) = tand(args(1));
                mtx_update(2,1) = tand(args(2));
                
            case 'skewX'
                args = str2double(tokens(read_pos));
                read_pos = read_pos + 1;
                mtx_update(1,2) = tand(args(1));
                
            case 'skewY'
                args = str2double(tokens(read_pos));
                read_pos = read_pos + 1;
                mtx_update(2,1) = tand(args(1));
             
            case 'matrix'
                args = str2double(tokens(read_pos + (0:5)));
                read_pos = read_pos + 6;
                mtx_update(1,1) = args(1);
                mtx_update(2,1) = args(2);
                mtx_update(1,2) = args(3);
                mtx_update(2,2) = args(4);
                mtx_update(1,3) = args(5);
                mtx_update(2,3) = args(6);
        end
        
        mtx = mtx_update * mtx;
    end     % End of parsing for loop
end


%% Helper function for parsing path style attributes:
% This returns a structure populated with fields derived from the 'style'
% attribute of the passed object.
function style_struct = parse_style_attributes(obj)

    % Default sytle values:
    style_struct.fill = [0, 0, 0];       % Default fill color (black)
    style_struct.fill_opacity = 0.5;     % Default opacity (50%)
    style_struct.stroke = [0, 0, 0];     % Default stroke color (black)
    style_struct.stroke_opacity = 1.0;
    style_struct.stroke_width = 0.5*(72/96);  % (px) Matches MATLAB default
    
    % We attempt to find other potential field names:
    if ~obj.hasAttribute('style')
        if obj.hasAttribute('fill')
            att = char(obj.getAttribute('fill'));
            style_struct.fill = interp_style_arg(att);
        end
        if obj.hasAttribute('fill-opacity')
            att = char(obj.getAttribute('fill-opacity'));
            style_struct.fill_opacity = interp_style_arg(att);
        end
        if obj.hasAttribute('stroke')
            att = char(obj.getAttribute('stroke'));
            style_struct.stroke = interp_style_arg(att);
        end
        if obj.hasAttribute('stroke-opacity')
            att = char(obj.getAttribute('stroke-opacity'));
            style_struct.stroke_opacity = interp_style_arg(att);
        end
        if obj.hasAttribute('stroke-width')
            att = char(obj.getAttribute('stroke-width'));
            style_struct.stroke_width = interp_style_arg(att);
        end
        return;
    end
    
    % Read the 'raw' data (empty arrays indicate invalid data):
    style_str = char(obj.getAttribute('style'));   % cast from java.lang.string
    style_struct.style_unparsed = style_str;
        % We save the original style string in the unparsed format to allow for
        % easier later export by m_trace_svg_export.
    
    % We use a regex to parse it into style tags (separated by a ;)
    expr = '[a-zA-Z_-]+:[^;]*';
    tokens = regexp(style_str, expr, 'match');

    % Accumulate settings:
    % Values preceeded by # are treated as hex
    
    for i=1:numel(tokens)
        vals = strsplit(tokens{i}, {':'}, 'CollapseDelimiters', true);
        field_name = regexprep(vals{1}, '[^a-zA-Z_0-9]', '_');   % replace non-alphanumeric characters
        if field_name(1)~='_' % Invalid field names are skipped
            style_struct.(field_name) = interp_style_arg(vals{2});
        end
    end 
    
    % Now we reinterperet any used values that are missing or set to 'none'
    if ischar(style_struct.fill) && strcmp(style_struct.fill, 'none')
        style_struct.fill = [0, 0, 0];
        style_struct.fill_opacity = 0.0;
    end
    if ischar(style_struct.stroke) && strcmp(style_struct.stroke, 'none')
        style_struct.stroke = [0, 0, 0];
        style_struct.stroke_opacity = 0.0;
    end
    
    % Conversion from px to pt (used by MATLAB LineWidth property):
    style_struct.stroke_width = style_struct.stroke_width * (96/72);
    
    function x = interp_style_arg(str)
        % First try numeric conversion
        x_c = str2double(str);
        if ~isnan(x_c)
            x = x_c;
            return;
        end
        
        if str(1)=='#'  % treat as hex RGB value
            str = str(2:end);
            R = hex2dec(str(1:2));
            G = hex2dec(str(3:4));
            B = hex2dec(str(5:6));
            x = [R, G, B]/255;
            return;
        end
        
        % Special case: 'px' suffix for numeric argument:
        if strcmp(str((end-1):end), 'px')
            x = str2double(str(1:(end-2)));
            return;
        end
        
        % Final case: no conversion, just return string.
        x = str;
    end
end


%% Helper function for converting the parameterization of elliptical arcs:
% Converts from 'endpoint parameterization' to 'center parameterization'
% according to the advice found at:
%   https://www.w3.org/TR/SVG2/implnote.html#ArcImplementationNotes
% Format of the d_e argument (9-elements) is:
%     [srart_x, start_y, ...
%     rx, ry, ...
%     x-axis-rotation, ... 
%     large-arc-flag, sweep-flag, ...
%     end_x, end_y]
% Format of the d_c result (7-elements) is:
%     [rx, ry, cx, cy, phi, theta_start, theta_end]
% phi, theta_start, and theta_end will then be in units of radians
function d_c = convert_parameterization(d_e)
    % Unpacking:
    x_1 = d_e(1);
    y_1 = d_e(2);
    r_x = d_e(3);
    r_y = d_e(4);
    phi = d_e(5);   % degrees
    f_A = d_e(6);
    f_S = d_e(7);
    x_2 = d_e(8);
    y_2 = d_e(9);
    
    % Radii corrections (part 1):
    if r_x*r_y==0
        error('zero radii specified');
    end
    r_x = abs(r_x);
    r_y = abs(r_y);
    
    % Step 1:
    rot_M = @(d) [cosd(d), -sind(d); sind(d), cosd(d)];
    t1 = rot_M(-phi) * ([x_1; y_1] - [x_2; y_2])/2;
    x_t = t1(1);
    y_t = t1(2);
    
    % Step 2:
    if f_A ~= f_S
        f1 = +1.0;
    else
        f1 = -1.0;
    end
    
    % Radii corrections (part 2):
    G = (x_t/r_x)^2 + (y_t/r_y)^2;
    if G > 1
        r_x = r_x * sqrt(G);
        r_y = r_y * sqrt(G);
        t2 = [0.0; 0.0];
    else
        f2 = (r_x*r_y)^2;
        f3 = (r_x*y_t)^2 + (r_y*x_t)^2;
        t2 = f1 * sqrt((f2-f3)/f3) * [(r_x*y_t/r_y); (-r_y*x_t/r_x)];
    end
    
    % Step 3:
    t3 = (rot_M(phi) * t2) + ([x_1; y_1] + [x_2; y_2])/2;
    c_x = t3(1);
    c_y = t3(2);
    
    % Step 4:
    t4 = +(t1 - t2) ./ [r_x; r_y];
    t5 = -(t1 + t2) ./ [r_x; r_y];
    theta_1 = get_angle([1; 0], t4);
    theta_D = get_angle(t4, t5);
    
    if (~f_S) && (theta_D > 0)
        theta_D = theta_D - 2*pi;
    elseif f_S && (theta_D < 0)
        theta_D = theta_D + 2*pi;
    end
    
    
    % Packing of output:
    d_c = zeros(1, 7);
    d_c(1) = r_x;
    d_c(2) = r_y;
    d_c(3) = c_x;
    d_c(4) = c_y;
    d_c(5) = phi * (pi/180);   % Convert to radians
    d_c(6) = theta_1;
    d_c(7) = theta_1 + theta_D;
    
    
    % Helper function for computing vector angles:
    % th will be an angle (in radians) between 2-vectors u and v, s.t. 
    % th will be signed according to the right-hand rule.
    function th = get_angle(u, v)
        a = u(1)*v(2) - u(2)*v(1);
        b = u(1)*v(1) + u(2)*v(2);
        c = u(1)^2 + u(2)^2;
        d = v(1)^2 + v(2)^2;

        if a>=0
            s = +1.0;
        else
            s = -1.0;
        end

        th = s * acos( b/sqrt(c*d) );

        if th<0
            th = th + 2*pi;
        end
    end
end



%% Helper function for applying a matrix transform to segment data
% M is a 4x4 matrix representing the transformation of point (x1, y1) to
% (x2, y2) via the homogenous coordinate relationship:
%   [x2; y2; 1] = M * [x1; y1; 1];      (M is 3 by 3)
% See parse_path_data() function for more info.
function data_t = apply_transform_to_segment(type, data, M)
    data_t = zeros(size(data));
    switch type
        case 'B'    % Bezier segment type (apply transform to each coord):
            for i=1:round(numel(data)/2)
                a = 1 + 2*(i-1);
                b = 2*i;
                dd = M * [data(a); data(b); 1];
                data_t(a) = dd(1);
                data_t(b) = dd(2);
            end
            
        case 'E'    % Elliptical arc segment type
            % Compute new center coordinates:
            cc = M * [data(3); data(4); 1];
            data_t(3) = cc(1);  % new cx
            data_t(4) = cc(2);  % new cy
            
            % Compute new rx and ry:
            rx = data(1);
            ry = data(2);
            ph = data(5);
            G = M(1:2, 1:2) * [cos(ph), -sin(ph); sin(ph), cos(ph)] ...
                            * [rx, 0; 0, ry];
            rx_t = sqrt( G(1,1)^2 + G(2,1)^2 );
            ry_t = sqrt( G(1,2)^2 + G(2,2)^2 );
            if rx_t>0
                ph_t = atan2(G(2,1), G(1,1));
            else
                ph_t = atan2(G(2,2), G(1,2));
            end
            data_t(1) = rx_t;
            data_t(2) = ry_t;
            data_t(5) = ph_t;
            
            % Angle ranges are preserved:
            data_t(6) = data(6);
            data_t(7) = data(7);  
    end
end
