function [lin_indices] = get_closed_shape_inner_pixels(border_image, polygon)
%GET_INNER_PIXELS Summary of this function goes here
%   Detailed explanation goes here, but only if I feel like it.
lin_indices = [];

%% create 1 pixel-wide border around the image to make the outside area contiguous
test_image = ones(size(border_image) + [2,2]);
test_image(2:end-1, 2:end-1) = border_image == 0; % invert the border image


CC = bwconncomp(test_image, 4);
if CC.NumObjects < 2
	%disp(['NUMBER OF OBJECTS IS LESS THAN 2! IT IS: ', num2str(CC.NumObjects)]);
else
	obj_list = CC.PixelIdxList;
	% remove the object representing the outside of the border (containing
	% index = 1)
	obj_list(cellfun(@(x) max(x(:) == 1), obj_list)) = [];
	% add points from all inner objects together
	inner_indices = zeros(sum(cellfun(@numel, obj_list)), 1); % pre-allocating memory saves time
	curr_i = 1;
	for i = 1 : length(obj_list)
		[row, col] = ind2sub(size(test_image), obj_list{i}(1));
		row = row - 1;
		col = col - 1;
		
		% finding the polygon sides that cross the line: [1,row] -> [row,col]
		%polygon_1 = polygon(polygon(:,1) ~= row,:);
		polygon_1 = polygon;
		temp_polygon = [polygon_1(end,:); polygon_1];
		points = sign(temp_polygon(:,1) - row);
		last_sign = points(1);
		num_intersections = 0;
		for j = 2 : length(points)
			point = points(j);
			if point ~= last_sign && point ~= 0
				last_sign = point;
				p1 = temp_polygon(j-1,:);
				p2 = temp_polygon(j,:);
				
				alpha = (row - p1(1))/(p2(1) - p1(1));
				if alpha <= 1
					int_col = p1(2) + (p2(2) - p1(2))*alpha;
					if int_col >= 1 && int_col < col
						num_intersections = num_intersections + 1;
					end
				end
			end
			
		end
		%points = points(points ~= 0); % remove zeros
% 		points = conv(points, [1; -1]);
% 		points = points(2:end-1);
% 		indices = find(points); % indices pointing to the second vertices of the polygon sides
% 		points_2 = polygon_1(indices, :);
% 		points_1 = temp_polygon(indices, :);
% 		
% 		alphas = (row - points_1(:,1))./(points_2(:,1) - points_1(:,1));
% 		points_1 = points_1(alphas <= 1, :);
% 		points_2 = points_2(alphas <= 1, :);
% 		
% 		
% 		
% 		alphas = alphas(alphas <= 1);
% 
% 		int_cols = points_1(:,2) + (points_2(:,2) - points_1(:,2)).*alphas;
% 		num_intersections = nnz((int_cols >= 1) & (int_cols < col));
		if mod(num_intersections, 2) == 1
			curr_size = numel(obj_list{i});
			inner_indices(curr_i : curr_i + curr_size - 1) = obj_list{i};
			curr_i = curr_i + curr_size;
		end
	end
	inner_indices = inner_indices(inner_indices > 0);
	if ~isempty(inner_indices)
		[inner_rows, inner_cols] = ind2sub(size(test_image), inner_indices);
		inner_subs = [inner_rows, inner_cols] - [1, 1];
		lin_indices = sub2ind(size(border_image), inner_subs(:,1), inner_subs(:,2));
	end
end

%% draw inner areas of the
%test_image = zeros(size(border_image));
%test_image(lin_indices) = 1;
%figure; imshow(test_image);

end

