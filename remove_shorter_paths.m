function [paths] = remove_shorter_paths(paths, number, max_cut)
%%
% max_cut - maximum difference in path lengths that can be cut out
% if the difference between path lengths is higher than max_cut, the longer
% path is preserved

path = paths{number};

paths_to_remove = [];
for i = 1 : length(paths)
	if i ~= number
		temp_path = paths{i};
		match_array = min(temp_path == path(end,:), [], 2);
		last_index = find(match_array, 1, 'last');
		if ~isempty(last_index)
			% if the difference in path length is above the threshold, do
			% not remove any paths. Not sure it will work...
			if abs(last_index - size(path, 1)) < max_cut
				if (last_index - size(path, 1)) > 0
					paths_to_remove = [paths_to_remove; i];
				else
					paths_to_remove = [paths_to_remove; number];
				end
			end
		end
	end
end

if ~isempty(paths_to_remove)
	fprintf('removing %i paths\n', length(paths_to_remove));
	paths(paths_to_remove) = [];
end

end

