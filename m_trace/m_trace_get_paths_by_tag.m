%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% m_trace_get_path_by_tag.m
% 
% Utility function for extracting relevant path data from a scene. Helpful for
% creating user callbacks that operate on specific paths identified with the
% 'm_trace:tags' attribute, which may be a comma-separated list of tags. The
% index of the path object is accumulated in path_idxs if the requested tag
% matches any of the tags in the list.
% 
% Returns a linear array of indices into the path_data field of m_trace_data,
% which can be used to manipulate the data using transform funcitons, etc.
% 
% Patrick Kilcullen
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function path_idxs = m_trace_get_paths_by_tag(m_trace_data, tag)
    path_idxs = [];
    for k=1:numel(m_trace_data.path_data)
        if ~isfield(m_trace_data.path_data{k}, 'tags')
            continue;
        end
        tags_k = m_trace_data.path_data{k}.tags;
        % separating elements (stripping whitespace, splitting):
        tags_k_split = regexp(tags_k, '[\w]*', 'match');
        for j=1:numel(tags_k_split)
            if strcmp(tags_k_split{j}, tag)
                path_idxs = [path_idxs; k]; %#ok<AGROW> 
                break;
            end
        end
    end
    
    if isempty(path_idxs)
        error('Requested tag ''%s'' not found.', tag);
    end
end