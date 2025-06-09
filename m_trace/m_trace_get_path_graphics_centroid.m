%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% m_trace_get_path_graphics_centroid.m
% 
% Calculates a centroid coordinate, based on the vertex data contained in the
% graphics handle object associated with a path structure, created by m_trace.
% 
% This is useful for user animation callbacks that wish to rotate an object
% around a center of another object point.
% 
% Patrick Kilcullen
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function c = m_trace_get_path_graphics_centroid(path)
    total_centroid = [0, 0];
    tc_count = 0;
    
    if ~isempty(path.graphics_handle_open_subpaths)
        g_h = path.graphics_handle_open_subpaths;
        verts = [g_h.XData(:), g_h.YData(:)];
        tc_count = tc_count + 1;
        total_centroid = total_centroid + mean(verts, 1, 'omitnan');
    end

    if ~isempty(path.graphics_handle_closed_subpaths)
        g_h = path.graphics_handle_closed_subpaths;
        verts = g_h.Shape.Vertices;
        tc_count = tc_count + 1;
        total_centroid = total_centroid + mean(verts, 1, 'omitnan');
    end

    c = total_centroid / tc_count;
end