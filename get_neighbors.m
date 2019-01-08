function [neighbors, indices] = get_neighbors(point, avail_points, im_size, connectivity)
%GET_NEIGHBORS Summary of this function goes here
%   Detailed explanation goes here
deltas = [1, 0; -1, 0; 0, 1; 0, -1; 1, 1; 1, -1; -1, 1; -1, -1];

neighbors = [];
indices = [];

for i = 1 : connectivity
	curr_point = point + deltas(i, :);
	
	% check if the point is within the image boundaries. This is actually not necessary, but it will speed things up.
	if min(curr_point(:)) >= 1 && curr_point(1) <= im_size(1) && curr_point(2) <= im_size(2) 
		% contains info on whether each point matches the curr_point
		match_array = min(avail_points == curr_point, [], 2); 
		index = find(match_array);
		
		if ~isempty(index)
			if length(index) > 1
				disp('MORE THAN ONE POINT IN THE SET. FIX IT, IVAN!!!');
			end
			
			neighbors = [neighbors; curr_point];
			indices = [indices, index];
		end
	end
end
end

