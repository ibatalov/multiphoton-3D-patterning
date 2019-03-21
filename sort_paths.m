function [sorted_borders, path_colors, borders_inner_points] = sort_paths(borders, binary_image)
%SORT_PATHS Summary of this function goes here
%   Detailed explanation goes here

inner_area_sizes = zeros(length(borders), 1);
borders_inner_points = cell(length(borders), 1);
path_colors = zeros(length(borders), 1);

for path_num = 1 : length(borders)
	border = borders{path_num};
	max_row = max(border(:, 1));
	max_col = max(border(:, 2));
	
	min_row = min(border(:, 1));
	min_col = min(border(:, 2));
	
	test_image = ones(max_row - min_row + 3, max_col - min_col + 3);
	border = border - [min_row - 2, min_col - 2];
	
	lin_indices = sub2ind(size(test_image), border(:,1), border(:,2));
	test_image(lin_indices) = 0;

	CC = bwconncomp(test_image, 4);
	if CC.NumObjects < 2
		%disp(['NUMBER OF OBJECTS IS LESS THAN 2! IT IS: ', num2str(CC.NumObjects)]);
		%if path_colors(path_num) == 0
		%	figure;
		%	imshow(test_image)
		%end
	else
		obj_list = CC.PixelIdxList;
		% remove the object representing the outside of the border
		obj_list(cellfun(@(x) max(x(:) == 1), CC.PixelIdxList)) = [];
		% add points from all inner objects together
		inner_indices = zeros(sum(cellfun(@numel, obj_list)), 1); % pre-allocating memory saves time
		curr_i = 1;
		for i = 1 : length(obj_list)
			curr_size = numel(obj_list{i});
			inner_indices(curr_i : curr_i + curr_size - 1) = obj_list{i};
			curr_i = curr_i + curr_size;
		end
		
		inner_area_sizes(path_num) = numel(inner_indices);
		[inner_rows, inner_cols] = ind2sub(size(test_image), inner_indices);
		inner_subs = [inner_rows, inner_cols] + [min_row - 2, min_col - 2];
		borders_inner_points{path_num} = inner_subs;
		
		test_point_num = 1;
		[in, on] = inpolygon(inner_subs(test_point_num,1),inner_subs(test_point_num,2),border(:,1),border(:,2));
		while test_point_num < size(inner_subs, 1) && (in && ~on)
			test_point_num = test_point_num + 1;
			[in, on] = inpolygon(inner_subs(test_point_num,1),inner_subs(test_point_num,2),border(:,1),border(:,2));
		end
		
		path_colors(path_num) = binary_image(inner_subs(test_point_num,1), inner_subs(test_point_num,2));
	end
end

order_array = (1 : length(borders)).';
order_array = [order_array, inner_area_sizes];
order_array = sortrows(order_array, -2); % sort by the 2nd column in a descending order

sorted_borders = borders(order_array(:,1));
path_colors = path_colors(order_array(:,1));
borders_inner_points = borders_inner_points(order_array(:,1));

%disp('sorted path order:');
%order_array(:,1)

%% draw inner areas of the 
%  for i = 1 : length(borders_inner_points)
%  	test_image = zeros(size(binary_image));
%  	lin_ind = sub2ind(size(binary_image), borders_inner_points{i}(:,1), borders_inner_points{i}(:,2));
%  	test_image(lin_ind) = 1;
%  	figure; imshow(test_image);
%  end

end

