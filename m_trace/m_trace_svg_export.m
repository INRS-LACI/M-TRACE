%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% m_trace_svg_export.m
% 
% Animation callback function  for facilitating the export of computed raytraces
% as SVG paths, combining them with the original SVG elements in the file input 
% to M-TRACE.
% 
% The input filename is stored as an element of the UserData field of the input
% axis handle. If the input filename matches the output filename, a warning is
% issued and nothing is changed. This is done to avoid overwriting of the
% original file, which would corrupt it from the perspective of serving as input
% to further raytracing simulations (this is presumed to be undesirable
% behaviour).
% 
% Patrick Kilcullen (patrick.kilcullen@inrs.ca)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function cont = m_trace_svg_export(ax_h, ~, output_filename)
    input_filename = ax_h.UserData.m_trace_data.input_file;

    % Check for filename collision:
    % If found, we issue a warning, halt the simulation, and do nothing else.
    [ ~, v1] = fileattrib(input_filename);
    [s2, v2] = fileattrib(output_filename);
    normalized_input_filename  = v1.Name;
    if s2   % Handle case where output filename may not exist yet
        normalized_output_filename = v2.Name;
    else
        normalized_output_filename = '';
    end
    if strcmp(normalized_input_filename, normalized_output_filename)
        warning('Filename for SVG export should not overwrite input file.');
        cont = false;
        return;
    end

    % Open input SVG file to create the DOM:
    output_DOM = xmlread(input_filename);

    % Ensure a definition of the 'm_trace' XML namespace prefix exists in the
    % root DOM element (create one if necessary):
    if ~output_DOM.getElementsByTagName('svg').item(0)...
            .hasAttribute('xmlns:m_trace')
        output_DOM.getElementsByTagName('svg').item(0)...
            .setAttribute('xmlns:m_trace', 'm_trace');
    end

    % First pass: we remove all existing ray_origin paths from the document.
    % These will be recreated entirely from simulation data (including styling).
    DOM_paths = output_DOM.getElementsByTagName('path');
    k = 0;
    while k < DOM_paths.getLength()
            % A while loop is used since these deletions cause dynamic changes
            % to the DOM
        if DOM_paths.item(k).hasAttribute('m_trace:ray_origin')
            node_to_delete = DOM_paths.item(k);
            node_to_delete.getParentNode().removeChild(node_to_delete);
        else
            k = k + 1;
        end
    end

    % Loop over all computed paths for ray origin objects:
    m_trace_paths = ax_h.UserData.m_trace_data.path_data;
    svg_base = output_DOM.getElementsByTagName('svg').item(0);
    for k=1:numel(m_trace_paths)
        if ~isfield(m_trace_paths{k}, 'ray_origin')
            continue;
        end
        p = m_trace_paths{k};
        e = output_DOM.createElement('path');
        e.setAttribute('id', p.id);
        e.setAttribute('m_trace:ray_origin', p.ray_origin);
        e.setAttribute('style', p.style.style_unparsed);
        e.setAttribute('d', generate_path_d_string(p));
        svg_base.appendChild(e);
    end

    % Write the output SVG file:
    xmlwrite(output_filename, output_DOM);

    cont = true;
end


%% Helper function for generating new path strings based on input ray data
function d_str = generate_path_d_string(path)
    d_str = '';
    for i=1:numel(path.subpaths)
        x0 = path.subpaths(i).seg_data(1).data(1);
        y0 = path.subpaths(i).seg_data(1).data(2);
        d_str = [d_str, sprintf('M %.6d %.6d', x0, y0)];        %#ok<AGROW> 
        for j=1:numel(path.subpaths(i).seg_data)
            xj = path.subpaths(i).seg_data(j).data(3);
            yj = path.subpaths(i).seg_data(j).data(4);
            d_str = [d_str, sprintf(' %.6d %.6d', xj, yj)];     %#ok<AGROW> 
        end
        if i~=numel(path.subpaths)
            d_str = [d_str, ' '];       %#ok<AGROW> 
        end
    end
end
