%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% m_trace_get_trace_data_by_tag.m
% 
% Utility function for extracting data from a solved raytrace consisting only of
% intersections found with objects containing the specified tag.
% 
% One optional argument is allowed which specifies the tag to be expected of the
% ray which is tested to intersect with a particular object. If no third
% argument is specified, then all intersected ray data is returned.
% 
% Note: this function will not return an error if a specific intersection with
% the tagged object is not found. In this case the returned cell array of data
% is empty.
% 
% Patrick Kilcullen
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function data = m_trace_get_trace_data_by_tag(m_trace_data, tag, varargin)
    % Check varargin to see if we filter by ray tag:
    if ~isempty(varargin)
        ray_tag = varargin{1};
    else
        ray_tag = [];
    end

    data = cell(0);
    data_acc = 0;
    for k=1:numel(m_trace_data.path_data)
        % Check for post-trace ray objects:
        if ~isfield(m_trace_data.path_data{k}, 'm_trace_computed_path')
            continue;
        end

        % Check the particular ray's tag (if specified)
        if ~isempty(ray_tag)
            if isfield(m_trace_data.path_data{k}, 'tags')
                rt = m_trace_data.path_data{k}.tags;
                % Separating elements (stripping whitespace, splitting):
                rt_split = regexp(rt, '[\w]*', 'match');
                match = false;
                for j=1:numel(rt_split)
                    if strcmp(rt_split{j}, ray_tag)
                        match = true;
                        break;
                    end
                end
                if ~match
                    continue;
                end
            else
                continue;
            end
        end

        rtp = m_trace_data.path_data{k}.m_trace_computed_path;
        datac = m_trace_get_trace_data_by_tag_h(rtp, tag);
            % Call recursive helper function (needed to handle child ray
            % branching).
        data_acc = data_acc + numel(datac);
        data = [data, datac]; %#ok<AGROW> 
    end
end


%% Helper function for handling recursive evaluation of child rays
function data = m_trace_get_trace_data_by_tag_h(rtp, tag)
    data = cell(0);
    data_acc = 0;

    for kk=1:numel(rtp)
        if isfield(rtp{kk}, 'tags')
            tags_k = rtp{kk}.tags;
            % Separating elements (stripping whitespace, splitting):
            tags_k_split = regexp(tags_k, '[\w]*', 'match');
            for j=1:numel(tags_k_split)
                if strcmp(tags_k_split{j}, tag)
                    data_acc = data_acc + 1;
                    data{data_acc} = rtp{kk};
                    break;
                end
            end
        end

        % Recursive call check:
        if isfield(rtp{kk}, 'rchild')
            datac = m_trace_get_trace_data_by_tag_h(rtp{kk}.rchild, tag);
            data_acc = data_acc + numel(datac);
            data = [data, datac]; %#ok<AGROW> 
        end
    end
end

