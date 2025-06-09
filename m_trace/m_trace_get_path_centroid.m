%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% m_trace_get_path_centroid.m
% 
% Calculates a centroid coordinate, based on the endpoint coordinates contained
% in the segment data of a given path structure, created by m_trace. Unlike the
% function m_trace_get_path_graphics_centroid(), this function does not require
% the path object to have an associated graphics handle (i.e., it can work with
% objects that are marked with m_trace:invisible attribute).
% 
% This is useful for user animation callbacks that wish to rotate an object
% around a center of another path object with a given tag.
% 
% The specific calculation considers the chained endpoints of each subpath
% segment as a 'mass point' with unit weight. Joined endpoints are 'chaned' by
% taking their averaged position to ensure continuity.
% 
% Patrick Kilcullen
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function c = m_trace_get_path_centroid(path)
    total_centroid = [0, 0];
    tc_count = 0;
    
    for j=1:numel(path.subpaths)
        n_segs = numel(path.subpaths(j).seg_data);

        nodes = zeros(n_segs+1, 2); % [x, y], note fencepost counting!
        for k=1:n_segs
            [xy1, xy2] = get_endpoints(path.subpaths(j).seg_data(k));
            if k==1
                nodes(k, :) = xy1;
            else
                nodes(k, :) = 0.5*( nodes(k, :) + xy1 );
            end
            nodes(k+1, :) = xy2;
        end

        if path.subpaths(j).is_closed
            % If the path is closed, we compensate by removing the last node
            % And averaging it with the first node.
            xy_end = nodes(end, :);
            nodes(end, :) = [];
            nodes(1, :) = 0.5*( nodes(1, :) + xy_end );
        end

        tc_count = tc_count + 1;
        total_centroid = total_centroid + mean(nodes, 1, 'omitnan');
    end

    c = total_centroid / tc_count;
end


%% Helper function for extracting endpoint data from seg_data entries:
% For more information on the meaning of seg_data entries, see the description
% of the function parse_path_data(), contained in m_trace_get_svg_data.m.
function [xy1, xy2] = get_endpoints(seg)
    if seg.type == 'B'  % Bezier segments
        xy1 = [seg.data(1), seg.data(2)];
        xy2 = [seg.data(end-1), seg.data(end)];
    else % seg.type == 'E', for elliptical arc segments
        rx = seg.data(1);   % See derive_subpath_vertex_data() function in 
        ry = seg.data(2);   % m_trace.m for more details of these calculations.
        cx = seg.data(3);
        cy = seg.data(4);
        ph = seg.data(5);
        t1 = seg.data(6);
        t2 = seg.data(7);
        M = [cos(ph), -sin(ph), cx; sin(ph), cos(ph) cy];

        xy1 = M * [rx*cos(t1); ry*sin(t1); 1];
        xy2 = M * [rx*cos(t2); ry*sin(t2); 1];

        xy1 = [xy1(1), xy1(2)]; % Reshaping into explicit row format
        xy2 = [xy2(1), xy2(2)]; 
    end
end
